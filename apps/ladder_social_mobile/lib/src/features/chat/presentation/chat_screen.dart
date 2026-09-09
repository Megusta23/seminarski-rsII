import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/encrypted_image_payload.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/encrypted_voice_payload.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/voice_recording_service.dart';

final class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.conversation, super.key});
  final ConversationItem conversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

final class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const int _voiceAutoStopSafetyMarginMilliseconds = 500;

  static const int _pageSize = 40;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final VoiceRecordingService _voiceRecordingService;

  Timer? _timer;
  Timer? _recordingTimer;
  Stopwatch? _recordingStopwatch;
  List<ChatMessage> _messages = const <ChatMessage>[];
  bool _didInitialize = false;
  bool _loading = true;
  bool _sending = false;
  bool _refreshingLatest = false;
  bool _loadingOlder = false;
  bool _e2ePreparing = false;
  bool _e2eReady = false;
  bool _recordingVoice = false;
  bool _stoppingVoiceRecording = false;
  Future<bool>? _e2ePreparation;
  int _oldestLoadedPage = 0;
  int _totalPages = 1;
  late ConversationItem _conversation;
  late bool _canSendMessages;
  Object? _error;
  Object? _olderError;
  String? _e2eErrorMessage;
  Uint8List? _selectedImageBytes;
  Duration _recordingDuration = Duration.zero;
  VoiceRecordingDraft? _voiceDraft;
  double? _voiceUploadProgress;
  final Map<String, Future<Uint8List>> _encryptedImageLoads =
      <String, Future<Uint8List>>{};
  final Map<String, Future<Uint8List>> _encryptedVoiceLoads =
      <String, Future<Uint8List>>{};

  bool get _hasOlderMessages => _oldestLoadedPage < _totalPages;

  @override
  void initState() {
    super.initState();
    _voiceRecordingService = VoiceRecordingService();
    _conversation = widget.conversation;
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
    unawaited(_prepareE2E(initial: true));
    unawaited(_refreshLatest(initial: true));
    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        unawaited(_refreshLatest());
        if (!_e2eReady) {
          unawaited(_prepareE2E());
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordingTimer?.cancel();
    final VoiceRecordingDraft? draft = _voiceDraft;
    if (draft != null) {
      unawaited(draft.delete());
    }
    unawaited(_voiceRecordingService.dispose());
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

  Future<bool> _prepareE2E({
    bool initial = false,
    bool forceRefresh = false,
  }) {
    final Future<bool>? current = _e2ePreparation;
    if (current != null) {
      return current;
    }

    late final Future<bool> preparation;
    preparation = _prepareE2ECore(
      initial: initial,
      forceRefresh: forceRefresh,
    ).whenComplete(() {
      if (identical(_e2ePreparation, preparation)) {
        _e2ePreparation = null;
      }
    });
    _e2ePreparation = preparation;
    return preparation;
  }

  Future<bool> _prepareE2ECore({
    required bool initial,
    required bool forceRefresh,
  }) async {
    final String? userId =
        ref.read(mobileAuthControllerProvider).session?.userId;
    if (userId == null) {
      return false;
    }
    if (mounted) {
      setState(() {
        _e2ePreparing = true;
        if (initial) {
          _e2eErrorMessage = null;
        }
      });
    }

    try {
      await ref.read(e2eChatCoordinatorProvider).ensureConversationReady(
            userId: userId,
            conversation: _conversation,
            forceRefresh: forceRefresh,
          );
      if (!mounted) {
        return true;
      }
      setState(() {
        _e2eReady = true;
        _e2eErrorMessage = null;
      });
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _e2eReady = false;
        _e2eErrorMessage = _readableError(error);
      });
      return false;
    } finally {
      if (mounted) {
        setState(() => _e2ePreparing = false);
      }
    }
  }

  Future<List<ChatMessage>> _decryptMessages(
    Iterable<ChatMessage> messages,
  ) async {
    final String? userId =
        ref.read(mobileAuthControllerProvider).session?.userId;
    if (userId == null) {
      return List<ChatMessage>.unmodifiable(messages);
    }
    return ref.read(e2eChatCoordinatorProvider).decryptMessages(
          userId: userId,
          messages: messages,
        );
  }

  String _readableError(
    Object error, {
    String fallback = 'Secure chat setup failed. Retry in a moment.',
  }) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is E2EChatSetupException ||
        error is E2ECryptoException ||
        error is E2EKeyTrustException ||
        error is E2EImageValidationException ||
        error is E2EVoiceValidationException) {
      return error.toString();
    }
    return fallback;
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
        _conversation.id,
        page: 1,
        pageSize: _pageSize,
      );
      final ConversationItem conversation =
          await repository.getConversation(_conversation.id);
      if (!mounted) {
        return;
      }

      final List<ChatMessage> latest = await _decryptMessages(
        result.items.reversed,
      );
      if (!mounted) {
        return;
      }
      final List<ChatMessage> merged = initial
          ? List<ChatMessage>.unmodifiable(latest)
          : _mergeMessages(_messages, latest);
      final bool shouldClearVoiceComposer = !conversation.canSendMessages &&
          (_recordingVoice || _stoppingVoiceRecording || _voiceDraft != null);
      setState(() {
        _conversation = conversation;
        _messages = merged;
        _oldestLoadedPage = initial ? result.page : _oldestLoadedPage;
        if (_oldestLoadedPage == 0) {
          _oldestLoadedPage = result.page;
        }
        _totalPages = result.totalPages;
        _canSendMessages = conversation.canSendMessages;
        if (!_canSendMessages) {
          _selectedImageBytes = null;
        }
        _error = null;
        _loading = false;
      });
      if (shouldClearVoiceComposer) {
        unawaited(_discardVoiceComposer());
      }

      if (_messages.isNotEmpty) {
        try {
          await repository.markRead(
            _conversation.id,
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
      final PagedResult<ChatMessage> result =
          await ref.read(chatRepositoryProvider).getMessages(
                _conversation.id,
                page: _oldestLoadedPage + 1,
                pageSize: _pageSize,
              );
      if (!mounted) {
        return;
      }
      final List<ChatMessage> older = await _decryptMessages(
        result.items.reversed,
      );
      if (!mounted) {
        return;
      }
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
    if (!_canSendMessages || _sending) {
      return;
    }
    if (_recordingVoice || _stoppingVoiceRecording || _voiceDraft != null) {
      showMessage(
        context,
        'Cancel or remove the voice message before attaching an image.',
        error: true,
      );
      return;
    }

    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1920,
      );
      if (file == null) {
        return;
      }

      final int fileLength = await file.length();
      if (fileLength > E2ECryptoConstants.maximumPlainMediaBytes) {
        throw E2EImageValidationException(
          'The selected image is too large. The encrypted upload limit is '
          '${E2ECryptoConstants.maximumEncryptedMediaBytes ~/ (1024 * 1024)} MiB.',
        );
      }
      final Uint8List bytes = await file.readAsBytes();
      E2EImageValidator.validate(bytes);
      await _verifyImageCanDecode(bytes);
      if (!mounted) {
        return;
      }
      setState(() => _selectedImageBytes = bytes);
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          _readableError(
            error,
            fallback: 'The selected image could not be prepared.',
          ),
          error: true,
        );
      }
    }
  }

  Future<void> _startVoiceRecording() async {
    if (!_canSendMessages ||
        _sending ||
        _recordingVoice ||
        _stoppingVoiceRecording) {
      return;
    }
    if (_selectedImageBytes != null) {
      showMessage(
        context,
        'Remove the selected image before recording a voice message.',
        error: true,
      );
      return;
    }
    if (_voiceDraft != null) {
      showMessage(
        context,
        'Remove the current voice preview before recording another one.',
        error: true,
      );
      return;
    }

    try {
      final bool permitted = await _voiceRecordingService.requestPermission();
      if (!permitted) {
        throw const E2EVoiceValidationException(
          'Microphone permission is required to record a voice message.',
        );
      }
      await _voiceRecordingService.start();
      if (!mounted || !_canSendMessages) {
        await _voiceRecordingService.cancel();
        return;
      }

      _recordingStopwatch = Stopwatch()..start();
      setState(() {
        _recordingVoice = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) {
          if (!mounted || !_recordingVoice) {
            return;
          }
          final Duration elapsed = _currentRecordingDuration();
          setState(() => _recordingDuration = elapsed);
          if (elapsed.inMilliseconds >=
              E2EVoiceValidator.maximumDurationMilliseconds -
                  _voiceAutoStopSafetyMarginMilliseconds) {
            _recordingTimer?.cancel();
            unawaited(_stopVoiceRecording());
          }
        },
      );
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          _readableError(
            error,
            fallback: 'Voice recording could not be started.',
          ),
          error: true,
        );
      }
    }
  }

  Duration _currentRecordingDuration() {
    final Duration elapsed = _recordingStopwatch?.elapsed ?? _recordingDuration;
    final Duration maximum = Duration(
      milliseconds: E2EVoiceValidator.maximumDurationMilliseconds,
    );
    return elapsed > maximum ? maximum : elapsed;
  }

  Future<void> _stopVoiceRecording() async {
    if (!_recordingVoice || _stoppingVoiceRecording) {
      return;
    }

    _recordingTimer?.cancel();
    _recordingStopwatch?.stop();
    final Duration elapsed = _currentRecordingDuration();
    setState(() {
      _recordingVoice = false;
      _stoppingVoiceRecording = true;
      _recordingDuration = elapsed;
    });

    try {
      final VoiceRecordingDraft draft =
          await _voiceRecordingService.stop(elapsed: elapsed);
      if (!mounted || !_canSendMessages) {
        await draft.delete();
        return;
      }

      final VoiceRecordingDraft? previous = _voiceDraft;
      setState(() {
        _voiceDraft = draft;
        _recordingStopwatch = null;
        _recordingDuration = Duration.zero;
      });
      if (previous != null) {
        await previous.delete();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recordingStopwatch = null;
          _recordingDuration = Duration.zero;
        });
        showMessage(
          context,
          _readableError(
            error,
            fallback: 'Voice recording could not be finalized.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _stoppingVoiceRecording = false);
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_recordingVoice || _stoppingVoiceRecording) {
      return;
    }
    _recordingTimer?.cancel();
    setState(() {
      _recordingVoice = false;
      _recordingStopwatch = null;
      _recordingDuration = Duration.zero;
    });
    try {
      await _voiceRecordingService.cancel();
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          _readableError(
            error,
            fallback: 'Voice recording could not be cancelled cleanly.',
          ),
          error: true,
        );
      }
    }
  }

  Future<void> _removeVoiceDraft() async {
    final VoiceRecordingDraft? draft = _voiceDraft;
    if (draft == null || _sending) {
      return;
    }
    setState(() => _voiceDraft = null);
    await draft.delete();
  }

  Future<void> _discardVoiceComposer() async {
    _recordingTimer?.cancel();
    final bool shouldCancelRecorder = _recordingVoice;
    final VoiceRecordingDraft? draft = _voiceDraft;
    if (mounted) {
      setState(() {
        _recordingVoice = false;
        _recordingStopwatch = null;
        _recordingDuration = Duration.zero;
        _voiceDraft = null;
        _voiceUploadProgress = null;
      });
    }
    if (shouldCancelRecorder) {
      try {
        await _voiceRecordingService.cancel();
      } catch (_) {
        // The composer is already disabled. Dispose retries recorder cleanup.
      }
    }
    if (draft != null) {
      await draft.delete();
    }
  }

  Future<void> _verifyImageCanDecode(Uint8List bytes) async {
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      frame = await codec.getNextFrame();
    } catch (error) {
      throw E2EImageValidationException(
        'The selected file is not a decodable image.',
        error,
      );
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
  }

  Future<Uint8List> _loadEncryptedImage(
    ChatMessage message, {
    bool forceReload = false,
  }) {
    final String? userId =
        ref.read(mobileAuthControllerProvider).session?.userId;
    if (userId == null) {
      return Future<Uint8List>.error(
        const ApiException(message: 'Authentication is required.'),
      );
    }

    final String cacheKey = _encryptedImageCacheKey(message);
    if (forceReload) {
      _encryptedImageLoads.remove(cacheKey);
    }
    return _encryptedImageLoads.putIfAbsent(
      cacheKey,
      () => ref.read(e2eChatCoordinatorProvider).downloadAndDecryptImage(
            userId: userId,
            message: message,
          ),
    );
  }

  String _encryptedImageCacheKey(ChatMessage message) => <Object?>[
        message.id,
        message.attachmentId,
        message.attachmentUrl,
        message.attachmentKeyVersion,
        message.attachmentSizeBytes,
        message.attachmentNonce?.join(','),
      ].join('|');

  Future<Uint8List> _loadEncryptedVoice(
    ChatMessage message, {
    bool forceReload = false,
  }) {
    final String? userId =
        ref.read(mobileAuthControllerProvider).session?.userId;
    if (userId == null) {
      return Future<Uint8List>.error(
        const ApiException(message: 'Authentication is required.'),
      );
    }

    final String cacheKey = _encryptedVoiceCacheKey(message);
    if (forceReload) {
      _encryptedVoiceLoads.remove(cacheKey);
    }
    return _encryptedVoiceLoads.putIfAbsent(
      cacheKey,
      () => ref.read(e2eChatCoordinatorProvider).downloadAndDecryptVoice(
            userId: userId,
            message: message,
          ),
    );
  }

  String _encryptedVoiceCacheKey(ChatMessage message) => <Object?>[
        message.id,
        message.attachmentId,
        message.attachmentUrl,
        message.attachmentKeyVersion,
        message.attachmentSizeBytes,
        message.attachmentDurationMilliseconds,
        message.attachmentNonce?.join(','),
      ].join('|');

  void _updateVoiceUploadProgress(int transferredBytes, int totalBytes) {
    if (!mounted || !_sending) {
      return;
    }
    final double? progress = totalBytes <= 0
        ? null
        : (transferredBytes / totalBytes).clamp(0.0, 1.0).toDouble();
    setState(() => _voiceUploadProgress = progress);
  }

  Future<void> _send() async {
    if (!_canSendMessages ||
        _sending ||
        _recordingVoice ||
        _stoppingVoiceRecording) {
      return;
    }

    final String text = _messageController.text.trim();
    final Uint8List? selectedImage = _selectedImageBytes;
    final VoiceRecordingDraft? selectedVoice = _voiceDraft;
    if (text.isEmpty && selectedImage == null && selectedVoice == null) {
      return;
    }

    setState(() {
      _sending = true;
      _voiceUploadProgress = selectedVoice == null ? null : 0;
    });
    final List<ChatMessage> sentMessages = <ChatMessage>[];
    var textSent = false;
    var imageSent = false;
    var voiceSent = false;
    try {
      final String? userId =
          ref.read(mobileAuthControllerProvider).session?.userId;
      if (userId == null) {
        throw const ApiException(message: 'Authentication is required.');
      }

      final bool ready = _e2eReady ||
          await _prepareE2E(
            forceRefresh: true,
          );
      if (!ready) {
        throw E2EChatSetupException(
          _e2eErrorMessage ??
              'End-to-end encryption is not ready for this conversation.',
        );
      }

      if (text.isNotEmpty) {
        final ChatMessage encryptedText =
            await ref.read(e2eChatCoordinatorProvider).sendEncryptedText(
                  userId: userId,
                  conversation: _conversation,
                  plainText: text,
                );
        sentMessages.add(encryptedText);
        textSent = true;
      }

      if (selectedImage != null) {
        final Uint8List localImageCopy = Uint8List.fromList(selectedImage);
        final ChatMessage encryptedImage =
            await ref.read(e2eChatCoordinatorProvider).sendEncryptedImage(
                  userId: userId,
                  conversation: _conversation,
                  clearImageBytes: localImageCopy,
                );
        _encryptedImageLoads[_encryptedImageCacheKey(encryptedImage)] =
            Future<Uint8List>.value(localImageCopy);
        sentMessages.add(encryptedImage);
        imageSent = true;
      }

      if (selectedVoice != null) {
        final Uint8List localVoiceCopy = selectedVoice.bytes;
        final ChatMessage encryptedVoice =
            await ref.read(e2eChatCoordinatorProvider).sendEncryptedVoice(
                  userId: userId,
                  conversation: _conversation,
                  clearVoiceBytes: localVoiceCopy,
                  durationMilliseconds: selectedVoice.durationMilliseconds,
                  onUploadProgress: _updateVoiceUploadProgress,
                );
        _encryptedVoiceLoads[_encryptedVoiceCacheKey(encryptedVoice)] =
            Future<Uint8List>.value(localVoiceCopy);
        sentMessages.add(encryptedVoice);
        voiceSent = true;
      }

      if (!mounted) {
        if (voiceSent) {
          await selectedVoice?.delete();
        }
        return;
      }
      setState(() {
        _messages = _mergeMessages(_messages, sentMessages);
        if (textSent) {
          _messageController.clear();
        }
        if (imageSent) {
          _selectedImageBytes = null;
        }
        if (voiceSent && identical(_voiceDraft, selectedVoice)) {
          _voiceDraft = null;
        }
      });
      if (voiceSent) {
        await selectedVoice?.delete();
      }
      _scrollToBottom(animate: true);
      unawaited(_refreshLatest());
    } catch (error) {
      final ApiException apiError = ApiException.from(error);
      if (mounted) {
        setState(() {
          if (sentMessages.isNotEmpty) {
            _messages = _mergeMessages(_messages, sentMessages);
          }
          if (textSent) {
            _messageController.clear();
          }
          if (imageSent) {
            _selectedImageBytes = null;
          }
          if (voiceSent && identical(_voiceDraft, selectedVoice)) {
            _voiceDraft = null;
          }
          if (error is E2EChatSetupException ||
              error is E2ECryptoException ||
              error is E2EKeyTrustException) {
            _e2eReady = false;
            _e2eErrorMessage = _readableError(error);
          }
        });
        if (voiceSent) {
          await selectedVoice?.delete();
        }
        if (!mounted) {
          return;
        }
        if (apiError.statusCode == 403) {
          setState(() {
            _canSendMessages = false;
            _selectedImageBytes = null;
          });
          unawaited(_discardVoiceComposer());
        }
        showMessage(context, apiError.message, error: true);
        if (sentMessages.isNotEmpty) {
          unawaited(_refreshLatest());
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _voiceUploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId =
        ref.watch(mobileAuthControllerProvider).session?.userId;
    return Scaffold(
      appBar: AppBar(
        title: Text(_conversation.displayTitle),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: _e2eReady
                  ? 'End-to-end encrypted text, images, and voice are ready'
                  : 'Secure text, image, and voice setup is not ready',
              child: Icon(
                _e2eReady ? Icons.lock_outline : Icons.lock_clock_outlined,
              ),
            ),
          ),
        ],
      ),
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
                                key: ValueKey<String>(message.id),
                                message: message,
                                mine: message.senderUserId == currentUserId,
                                loadEncryptedImage: _loadEncryptedImage,
                                encryptedImageErrorText: (Object error) =>
                                    _readableError(
                                  error,
                                  fallback:
                                      'The encrypted image could not be loaded.',
                                ),
                                loadEncryptedVoice: _loadEncryptedVoice,
                                encryptedVoiceErrorText: (Object error) =>
                                    _readableError(
                                  error,
                                  fallback:
                                      'The encrypted voice message could not be loaded.',
                                ),
                              );
                            },
                          ),
          ),
          if (_canSendMessages)
            _E2EStatusBanner(
              isReady: _e2eReady,
              isPreparing: _e2ePreparing,
              errorMessage: _e2eErrorMessage,
              onRetry: _e2ePreparing
                  ? null
                  : () => unawaited(
                        _prepareE2E(forceRefresh: true),
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
          if (_selectedImageBytes != null && _canSendMessages)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      onPressed: _sending
                          ? null
                          : () {
                              setState(() {
                                _selectedImageBytes = null;
                              });
                            },
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          if ((_recordingVoice || _stoppingVoiceRecording) && _canSendMessages)
            _VoiceRecordingComposer(
              duration: _recordingDuration,
              finalizing: _stoppingVoiceRecording,
              onStop: _stoppingVoiceRecording
                  ? null
                  : () => unawaited(_stopVoiceRecording()),
              onCancel: _stoppingVoiceRecording
                  ? null
                  : () => unawaited(_cancelVoiceRecording()),
            ),
          if (_voiceDraft != null && _canSendMessages)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: <Widget>[
                  VoiceDraftPreview(
                    path: _voiceDraft!.filePath,
                    durationMilliseconds: _voiceDraft!.durationMilliseconds,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      tooltip: 'Remove voice message',
                      onPressed: _sending
                          ? null
                          : () => unawaited(_removeVoiceDraft()),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          if (_voiceUploadProgress != null && _canSendMessages)
            _VoiceUploadProgress(progress: _voiceUploadProgress!),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Attach image',
                    onPressed: _sending ||
                            !_canSendMessages ||
                            _recordingVoice ||
                            _stoppingVoiceRecording ||
                            _voiceDraft != null
                        ? null
                        : _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: _canSendMessages &&
                          !_sending &&
                          !_recordingVoice &&
                          !_stoppingVoiceRecording,
                      maxLines: 5,
                      minLines: 1,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        hintText: _canSendMessages
                            ? 'Message'
                            : 'Messaging is unavailable',
                        counterText: '',
                      ),
                      onSubmitted: _canSendMessages &&
                              !_recordingVoice &&
                              !_stoppingVoiceRecording
                          ? (_) => unawaited(_send())
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Record voice message',
                    onPressed: _sending ||
                            !_canSendMessages ||
                            _recordingVoice ||
                            _stoppingVoiceRecording ||
                            _selectedImageBytes != null ||
                            _voiceDraft != null
                        ? null
                        : () => unawaited(_startVoiceRecording()),
                    icon: const Icon(Icons.mic_none_outlined),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: _sending ||
                            !_canSendMessages ||
                            _recordingVoice ||
                            _stoppingVoiceRecording
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

final class _VoiceRecordingComposer extends StatelessWidget {
  const _VoiceRecordingComposer({
    required this.duration,
    required this.finalizing,
    required this.onStop,
    required this.onCancel,
  });

  final Duration duration;
  final bool finalizing;
  final VoidCallback? onStop;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          if (finalizing)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Icon(
              Icons.fiber_manual_record,
              color: colors.error,
              size: 20,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              finalizing
                  ? 'Finalizing encrypted voice preview...'
                  : 'Recording ${formatVoiceDuration(duration)} / 5:00',
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          IconButton(
            tooltip: 'Cancel voice recording',
            onPressed: onCancel,
            color: colors.onErrorContainer,
            icon: const Icon(Icons.close),
          ),
          IconButton.filled(
            tooltip: 'Stop voice recording',
            onPressed: onStop,
            icon: const Icon(Icons.stop),
          ),
        ],
      ),
    );
  }
}

final class _VoiceUploadProgress extends StatelessWidget {
  const _VoiceUploadProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final double normalized = progress.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Encrypting and uploading voice message '
            '${(normalized * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: normalized),
        ],
      ),
    );
  }
}

final class _E2EStatusBanner extends StatelessWidget {
  const _E2EStatusBanner({
    required this.isReady,
    required this.isPreparing,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool isReady;
  final bool isPreparing;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool hasError = !isReady && !isPreparing && errorMessage != null;
    final Color background = hasError
        ? colors.errorContainer
        : colors.secondaryContainer.withValues(alpha: 0.55);
    final Color foreground =
        hasError ? colors.onErrorContainer : colors.onSecondaryContainer;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          if (isPreparing)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Icon(
              isReady ? Icons.lock_outline : Icons.lock_clock_outlined,
              color: foreground,
              size: 20,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPreparing
                  ? 'Preparing end-to-end encrypted text, images, and voice...'
                  : isReady
                      ? 'Text, image, and voice messages are end-to-end encrypted.'
                      : errorMessage ??
                          'Secure text, image, and voice setup is waiting for all devices.',
              style: TextStyle(color: foreground),
            ),
          ),
          if (onRetry != null && !isReady)
            IconButton(
              tooltip: 'Retry secure setup',
              onPressed: onRetry,
              color: foreground,
              icon: const Icon(Icons.refresh),
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
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.loadEncryptedImage,
    required this.encryptedImageErrorText,
    required this.loadEncryptedVoice,
    required this.encryptedVoiceErrorText,
    super.key,
  });

  final ChatMessage message;
  final bool mine;
  final EncryptedImageLoader loadEncryptedImage;
  final EncryptedImageErrorText encryptedImageErrorText;
  final EncryptedVoiceLoader loadEncryptedVoice;
  final EncryptedVoiceErrorText encryptedVoiceErrorText;

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
            _MessagePayload(
              message: message,
              loadEncryptedImage: loadEncryptedImage,
              encryptedImageErrorText: encryptedImageErrorText,
              loadEncryptedVoice: loadEncryptedVoice,
              encryptedVoiceErrorText: encryptedVoiceErrorText,
            ),
            const SizedBox(height: 6),
            _EncryptionLabel(message: message),
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

final class _MessagePayload extends StatelessWidget {
  const _MessagePayload({
    required this.message,
    required this.loadEncryptedImage,
    required this.encryptedImageErrorText,
    required this.loadEncryptedVoice,
    required this.encryptedVoiceErrorText,
  });

  final ChatMessage message;
  final EncryptedImageLoader loadEncryptedImage;
  final EncryptedImageErrorText encryptedImageErrorText;
  final EncryptedVoiceLoader loadEncryptedVoice;
  final EncryptedVoiceErrorText encryptedVoiceErrorText;

  @override
  Widget build(BuildContext context) {
    if (message.encryptionVersion == ChatEncryptionVersion.clientE2E) {
      return _buildEncryptedPayload(context);
    }
    if (!message.isLegacy) {
      return const _MessageWarning(
        text: 'This message uses an unsupported encryption version.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
      ],
    );
  }

  Widget _buildEncryptedPayload(BuildContext context) {
    if (message.type == MessageType.text) {
      final String? error = message.decryptionError;
      if (error != null) {
        return _MessageWarning(text: error);
      }
      final String? clearText = message.decryptedContent;
      return Text(clearText ?? 'Decrypting encrypted message...');
    }
    if (message.type == MessageType.image) {
      return EncryptedImagePayload(
        message: message,
        load: loadEncryptedImage,
        errorText: encryptedImageErrorText,
      );
    }
    if (message.type == MessageType.voice) {
      return EncryptedVoicePayload(
        message: message,
        load: loadEncryptedVoice,
        errorText: encryptedVoiceErrorText,
      );
    }

    final ({IconData icon, String label}) presentation = switch (message.type) {
      MessageType.video => (
          icon: Icons.videocam_outlined,
          label: 'Encrypted video',
        ),
      _ => (
          icon: Icons.lock_outline,
          label: 'Encrypted message',
        ),
    };
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(presentation.icon),
          const SizedBox(width: 10),
          Expanded(child: Text(presentation.label)),
        ],
      ),
    );
  }
}

final class _MessageWarning extends StatelessWidget {
  const _MessageWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.gpp_bad_outlined,
            size: 18,
            color: colors.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

final class _EncryptionLabel extends StatelessWidget {
  const _EncryptionLabel({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isSystem = message.type == MessageType.system;
    final bool encrypted =
        message.encryptionVersion == ChatEncryptionVersion.clientE2E;
    if (isSystem && message.isLegacy) {
      return const SizedBox.shrink();
    }

    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          encrypted ? Icons.lock_outline : Icons.history_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          encrypted ? 'End-to-end encrypted' : 'Legacy message',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
