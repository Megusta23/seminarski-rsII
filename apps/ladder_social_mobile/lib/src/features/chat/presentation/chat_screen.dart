import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversation, super.key});
  final ConversationItem conversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

final class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const int _pageSize = 40;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _timer;
  List<ChatMessage> _messages = const <ChatMessage>[];
  bool _didInitialize = false;
  bool _loading = true;
  bool _sending = false;
  bool _refreshingLatest = false;
  bool _loadingOlder = false;
  int _oldestLoadedPage = 0;
  int _totalPages = 1;
  late bool _canSendMessages;
  Object? _error;
  Object? _olderError;
  ImageUpload? _attachment;
  Uint8List? _attachmentPreview;

  bool get _hasOlderMessages => _oldestLoadedPage < _totalPages;

  @override
  void initState() {
    super.initState();
    _canSendMessages = widget.conversation.canSendMessages;
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    unawaited(_refreshLatest(initial: true));
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_refreshLatest()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 140) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _refreshLatest({bool initial = false}) async {
    if (_refreshingLatest) {
      return;
    }

    _refreshingLatest = true;
    final bool wasNearBottom = !_scrollController.hasClients ||
        _scrollController.position.extentAfter < 120;
    if (initial && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final ChatRepository repository = ref.read(chatRepositoryProvider);
      final PagedResult<ChatMessage> result = await repository.getMessages(
        widget.conversation.id,
        page: 1,
        pageSize: _pageSize,
      );
      final ConversationItem conversation =
          await repository.getConversation(widget.conversation.id);
      if (!mounted) {
        return;
      }

      final List<ChatMessage> latest = result.items.reversed.toList(
        growable: false,
      );
      final List<ChatMessage> merged = initial
          ? List<ChatMessage>.unmodifiable(latest)
          : _mergeMessages(_messages, latest);
      setState(() {
        _messages = merged;
        _oldestLoadedPage = initial ? result.page : _oldestLoadedPage;
        if (_oldestLoadedPage == 0) {
          _oldestLoadedPage = result.page;
        }
        _totalPages = result.totalPages;
        _canSendMessages = conversation.canSendMessages;
        if (!_canSendMessages) {
          _attachment = null;
          _attachmentPreview = null;
        }
        _error = null;
        _loading = false;
      });

      if (_messages.isNotEmpty) {
        try {
          await repository.markRead(
            widget.conversation.id,
            throughMessageId: _messages.last.id,
          );
        } catch (_) {
          // Message loading should remain successful even if read-state sync
          // is temporarily unavailable. The next poll retries it.
        }
      }
      if (initial || wasNearBottom) {
        _scrollToBottom(animate: !initial);
      }
    } catch (error) {
      if (mounted && initial) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    } finally {
      _refreshingLatest = false;
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loading || _loadingOlder || !_hasOlderMessages) {
      return;
    }

    final double oldMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0;
    final double oldPixels =
        _scrollController.hasClients ? _scrollController.position.pixels : 0;
    setState(() {
      _loadingOlder = true;
      _olderError = null;
    });

    try {
      final PagedResult<ChatMessage> result = await ref
          .read(chatRepositoryProvider)
          .getMessages(
            widget.conversation.id,
            page: _oldestLoadedPage + 1,
            pageSize: _pageSize,
          );
      if (!mounted) {
        return;
      }
      final List<ChatMessage> older = result.items.reversed.toList(
        growable: false,
      );
      setState(() {
        _messages = _mergeMessages(_messages, older);
        _oldestLoadedPage = result.page;
        _totalPages = result.totalPages;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }
        final double addedExtent =
            _scrollController.position.maxScrollExtent - oldMaxExtent;
        final double target = (oldPixels + addedExtent)
            .clamp(
              _scrollController.position.minScrollExtent,
              _scrollController.position.maxScrollExtent,
            )
            .toDouble();
        _scrollController.jumpTo(target);
      });
    } catch (error) {
      if (mounted) {
        setState(() => _olderError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  List<ChatMessage> _mergeMessages(
    Iterable<ChatMessage> current,
    Iterable<ChatMessage> updates,
  ) =>
      mergeUniqueItems<ChatMessage>(
        current: current,
        updates: updates,
        keyOf: (ChatMessage message) => message.id,
        compare: (ChatMessage left, ChatMessage right) {
          final int time = left.sentAtUtc.compareTo(right.sentAtUtc);
          return time != 0 ? time : left.id.compareTo(right.id);
        },
      );

  void _scrollToBottom({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final double target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _pickAttachment() async {
    if (!_canSendMessages) {
      return;
    }

    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1920,
    );
    if (file == null) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _attachmentPreview = bytes;
      _attachment = ImageUpload(
        bytes: bytes,
        fileName: file.name,
        contentType: imageContentType(file.name, file.mimeType),
      );
    });
  }

  Future<void> _send() async {
    if (!_canSendMessages) {
      return;
    }

    final String text = _messageController.text.trim();
    if (text.isEmpty && _attachment == null) {
      return;
    }
    setState(() => _sending = true);
    try {
      final ChatMessage sent =
          await ref.read(chatRepositoryProvider).sendMessage(
                conversationId: widget.conversation.id,
                content: text,
                attachment: _attachment,
              );
      _messageController.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = _mergeMessages(_messages, <ChatMessage>[sent]);
        _attachment = null;
        _attachmentPreview = null;
      });
      _scrollToBottom(animate: true);
      unawaited(_refreshLatest());
    } catch (error) {
      final ApiException apiError = ApiException.from(error);
      if (mounted) {
        if (apiError.statusCode == 403) {
          setState(() {
            _canSendMessages = false;
            _attachment = null;
            _attachmentPreview = null;
          });
        }
        showMessage(context, apiError.message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId =
        ref.watch(mobileAuthControllerProvider).session?.userId;
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversation.displayTitle)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AppErrorView(
                        error: _error!,
                        onRetry: () => unawaited(
                          _refreshLatest(initial: true),
                        ),
                      )
                    : _messages.isEmpty
                        ? const EmptyState(
                            icon: Icons.waving_hand_outlined,
                            title: 'Start the conversation',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length + 1,
                            itemBuilder: (BuildContext context, int index) {
                              if (index == 0) {
                                return _OlderMessagesFooter(
                                  hasMore: _hasOlderMessages,
                                  isLoading: _loadingOlder,
                                  error: _olderError,
                                  onRetry: () =>
                                      unawaited(_loadOlderMessages()),
                                );
                              }
                              final ChatMessage message = _messages[index - 1];
                              return _MessageBubble(
                                message: message,
                                mine: message.senderUserId == currentUserId,
                              );
                            },
                          ),
          ),
          if (!_canSendMessages)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.person_off_outlined,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You are no longer friends. Message history remains '
                      'available, but new messages are disabled.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_attachmentPreview != null && _canSendMessages)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _attachmentPreview!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      onPressed: () {
                        setState(() {
                          _attachment = null;
                          _attachmentPreview = null;
                        });
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Attach image',
                    onPressed:
                        _sending || !_canSendMessages ? null : _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: _canSendMessages && !_sending,
                      maxLines: 5,
                      minLines: 1,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        hintText: _canSendMessages
                            ? 'Message'
                            : 'Messaging is unavailable',
                        counterText: '',
                      ),
                      onSubmitted: _canSendMessages
                          ? (_) => unawaited(_send())
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending || !_canSendMessages
                        ? null
                        : () => unawaited(_send()),
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _OlderMessagesFooter extends StatelessWidget {
  const _OlderMessagesFooter({
    required this.hasMore,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final bool hasMore;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry older messages'),
          ),
        ),
      );
    }
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.history),
            label: const Text('Load older messages'),
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!mine)
              Text(
                message.senderDisplayName,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            if (message.attachmentUrl != null) ...<Widget>[
              ProtectedImage(
                path: message.attachmentUrl!,
                width: 280,
                height: 210,
                borderRadius: BorderRadius.circular(12),
              ),
              if (message.content != null) const SizedBox(height: 8),
            ],
            if (message.content != null) Text(message.content!),
            const SizedBox(height: 4),
            Text(
              formatDateTime(message.sentAtUtc),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
