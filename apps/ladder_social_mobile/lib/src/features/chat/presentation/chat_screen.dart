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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  List<ChatMessage> _messages = const <ChatMessage>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  ImageUpload? _attachment;
  Uint8List? _attachmentPreview;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final PagedResult<ChatMessage> result =
          await ref.read(chatRepositoryProvider).getMessages(widget.conversation.id);
      if (!mounted) return;
      final List<ChatMessage> ordered = result.items.reversed.toList(growable: false);
      setState(() {
        _messages = ordered;
        _error = null;
        _loading = false;
      });
      if (ordered.isNotEmpty) {
        await ref.read(chatRepositoryProvider).markRead(
              widget.conversation.id,
              throughMessageId: ordered.last.id,
            );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = ApiException.from(error).message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAttachment() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1920,
    );
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
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
    final String text = _messageController.text.trim();
    if (text.isEmpty && _attachment == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            conversationId: widget.conversation.id,
            content: text,
            attachment: _attachment,
          );
      _messageController.clear();
      if (mounted) {
        setState(() {
          _attachment = null;
          _attachmentPreview = null;
        });
      }
      await _loadMessages(silent: true);
    } catch (error) {
      if (mounted) showMessage(context, ApiException.from(error).message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
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
                    ? AppErrorView(error: ApiException(message: _error!), onRetry: _loadMessages)
                    : _messages.isEmpty
                        ? const EmptyState(
                            icon: Icons.waving_hand_outlined,
                            title: 'Start the conversation',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (BuildContext context, int index) {
                              final ChatMessage message = _messages[index];
                              final bool mine = message.senderUserId == currentUserId;
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
                            },
                          ),
          ),
          if (_attachmentPreview != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_attachmentPreview!, width: 90, height: 90, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      onPressed: () => setState(() {
                        _attachment = null;
                        _attachmentPreview = null;
                      }),
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
                    onPressed: _sending ? null : _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      maxLines: 5,
                      minLines: 1,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
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
