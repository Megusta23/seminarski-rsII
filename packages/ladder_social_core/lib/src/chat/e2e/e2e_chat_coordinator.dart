import 'dart:typed_data';

import 'package:ladder_social_core/src/chat/chat_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_chat_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_chat_transport.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_service.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_key_trust_store.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_image_validation.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_voice_validation.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';

typedef E2EDelay = Future<void> Function(Duration duration);

class E2EChatSetupException implements Exception {
  const E2EChatSetupException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class E2EConversationKeyMismatchException extends E2EChatSetupException {
  const E2EConversationKeyMismatchException()
      : super(
          'Security check failed: the locally stored conversation key does '
          'not match this device envelope. Messaging was stopped.',
        );
}

final class E2EChatCoordinator {
  E2EChatCoordinator({
    required E2EChatTransport transport,
    required E2ECryptoService cryptoService,
    required E2EPeerKeyTrustStore keyTrustStore,
    E2EDelay? delay,
    int bootstrapPollAttempts = 8,
    Duration bootstrapPollDelay = const Duration(milliseconds: 180),
  })  : _transport = transport,
        _cryptoService = cryptoService,
        _keyTrustStore = keyTrustStore,
        _delay =
            delay ?? ((Duration duration) => Future<void>.delayed(duration)),
        _bootstrapPollAttempts = bootstrapPollAttempts,
        _bootstrapPollDelay = bootstrapPollDelay {
    if (bootstrapPollAttempts < 1) {
      throw ArgumentError.value(
        bootstrapPollAttempts,
        'bootstrapPollAttempts',
        'At least one bootstrap poll attempt is required.',
      );
    }
  }

  static const int currentKeyVersion = 1;

  final E2EChatTransport _transport;
  final E2ECryptoService _cryptoService;
  final E2EPeerKeyTrustStore _keyTrustStore;
  final E2EDelay _delay;
  final int _bootstrapPollAttempts;
  final Duration _bootstrapPollDelay;

  final Map<String, E2EDeviceKeyRecord> _registeredDevices =
      <String, E2EDeviceKeyRecord>{};
  final Map<String, Future<E2EDeviceKeyRecord>> _registrationLoads =
      <String, Future<E2EDeviceKeyRecord>>{};
  final Map<String, _ConversationContext> _contexts =
      <String, _ConversationContext>{};
  final Map<String, Future<_ConversationContext>> _contextLoads =
      <String, Future<_ConversationContext>>{};
  final Map<String, E2EConversationKey> _conversationKeys =
      <String, E2EConversationKey>{};
  final Map<String, Future<E2EConversationKey>> _conversationKeyLoads =
      <String, Future<E2EConversationKey>>{};

  Future<E2EDeviceKeyRecord> ensureDeviceRegistered({
    required String userId,
    bool forceRefresh = false,
  }) {
    final String normalizedUserId = _identifier(userId, 'userId');
    if (!forceRefresh) {
      final E2EDeviceKeyRecord? cached = _registeredDevices[normalizedUserId];
      if (cached != null) {
        return Future<E2EDeviceKeyRecord>.value(cached);
      }
    }

    final Future<E2EDeviceKeyRecord>? current =
        _registrationLoads[normalizedUserId];
    if (current != null) {
      return current;
    }

    late final Future<E2EDeviceKeyRecord> load;
    load = _registerDevice(normalizedUserId).then((E2EDeviceKeyRecord value) {
      _registeredDevices[normalizedUserId] = value;
      return value;
    }).whenComplete(() {
      if (identical(_registrationLoads[normalizedUserId], load)) {
        _registrationLoads.remove(normalizedUserId);
      }
    });
    _registrationLoads[normalizedUserId] = load;
    return load;
  }

  Future<E2EConversationReadyState> ensureConversationReady({
    required String userId,
    required ConversationItem conversation,
    int keyVersion = currentKeyVersion,
    bool forceRefresh = false,
  }) async {
    final _ConversationContext context = await _loadConversationContext(
      userId: userId,
      conversation: conversation,
      keyVersion: keyVersion,
      forceRefresh: forceRefresh,
    );
    return E2EConversationReadyState(
      conversationId: context.conversationId,
      currentDeviceKeyId: context.currentDevice.id,
      keyVersion: context.keyVersion,
      activeDeviceCount: context.deviceKeys.length,
    );
  }

  Future<ChatMessage> sendEncryptedText({
    required String userId,
    required ConversationItem conversation,
    required String plainText,
  }) async {
    if (!conversation.canSendMessages) {
      throw const E2EChatSetupException(
        'New messages are disabled for this conversation. Message history '
        'remains available.',
      );
    }

    final String normalizedText = plainText.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(
        plainText,
        'plainText',
        'Text message may not be empty.',
      );
    }

    final _ConversationContext context = await _loadConversationContext(
      userId: userId,
      conversation: conversation,
      keyVersion: currentKeyVersion,
      forceRefresh: true,
    );
    final E2EEncryptedPayload encrypted = await _cryptoService.encryptText(
      conversationId: context.conversationId,
      keyVersion: context.keyVersion,
      conversationKey: context.conversationKey,
      plainText: normalizedText,
    );
    final ChatMessage response = await _transport.sendEncryptedText(
      conversationId: context.conversationId,
      senderDeviceKeyId: context.currentDevice.id,
      keyVersion: context.keyVersion,
      payload: encrypted,
    );

    _validateEncryptedTextResponse(
      response: response,
      context: context,
      requestPayload: encrypted,
    );
    return response.withDecryptedContent(normalizedText);
  }

  Future<ChatMessage> sendEncryptedImage({
    required String userId,
    required ConversationItem conversation,
    required List<int> clearImageBytes,
  }) async {
    if (!conversation.canSendMessages) {
      throw const E2EChatSetupException(
        'New messages are disabled for this conversation. Message history '
        'remains available.',
      );
    }

    final Uint8List localImageBytes = Uint8List.fromList(clearImageBytes);
    E2EImageValidator.validate(localImageBytes);

    final _ConversationContext context = await _loadConversationContext(
      userId: userId,
      conversation: conversation,
      keyVersion: currentKeyVersion,
      forceRefresh: true,
    );
    final E2EEncryptedPayload encrypted = await _cryptoService.encryptMedia(
      conversationId: context.conversationId,
      keyVersion: context.keyVersion,
      type: E2EPrivateMessageType.image,
      conversationKey: context.conversationKey,
      clearBytes: localImageBytes,
    );
    final ChatMessage response = await _transport.sendEncryptedMedia(
      conversationId: context.conversationId,
      senderDeviceKeyId: context.currentDevice.id,
      keyVersion: context.keyVersion,
      type: E2EPrivateMessageType.image,
      payload: encrypted,
    );

    _validateEncryptedMediaResponse(
      response: response,
      context: context,
      type: E2EPrivateMessageType.image,
      requestPayload: encrypted,
    );
    return response;
  }

  Future<ChatMessage> sendEncryptedVoice({
    required String userId,
    required ConversationItem conversation,
    required List<int> clearVoiceBytes,
    required int durationMilliseconds,
    E2ETransferProgress? onUploadProgress,
  }) async {
    if (!conversation.canSendMessages) {
      throw const E2EChatSetupException(
        'New messages are disabled for this conversation. Message history '
        'remains available.',
      );
    }

    final Uint8List localVoiceBytes = Uint8List.fromList(clearVoiceBytes);
    E2EVoiceValidator.validate(
      bytes: localVoiceBytes,
      durationMilliseconds: durationMilliseconds,
    );

    final _ConversationContext context = await _loadConversationContext(
      userId: userId,
      conversation: conversation,
      keyVersion: currentKeyVersion,
      forceRefresh: true,
    );
    final E2EEncryptedPayload encrypted = await _cryptoService.encryptMedia(
      conversationId: context.conversationId,
      keyVersion: context.keyVersion,
      type: E2EPrivateMessageType.voice,
      conversationKey: context.conversationKey,
      clearBytes: localVoiceBytes,
      durationMilliseconds: durationMilliseconds,
    );
    final ChatMessage response = await _transport.sendEncryptedMedia(
      conversationId: context.conversationId,
      senderDeviceKeyId: context.currentDevice.id,
      keyVersion: context.keyVersion,
      type: E2EPrivateMessageType.voice,
      payload: encrypted,
      durationMilliseconds: durationMilliseconds,
      onUploadProgress: onUploadProgress,
    );

    _validateEncryptedMediaResponse(
      response: response,
      context: context,
      type: E2EPrivateMessageType.voice,
      requestPayload: encrypted,
      durationMilliseconds: durationMilliseconds,
    );
    return response;
  }

  Future<Uint8List> downloadAndDecryptImage({
    required String userId,
    required ChatMessage message,
  }) async {
    final _EncryptedMediaDescriptor media =
        _validateEncryptedImageMessage(message);
    final E2EConversationKey conversationKey =
        await _readOrRecoverConversationKey(
      userId: userId,
      conversationId: message.conversationId,
      keyVersion: media.keyVersion,
    );
    final Uint8List cipherText =
        await _transport.downloadEncryptedAttachment(media.attachmentUrl);
    if (cipherText.length != media.encryptedSizeBytes) {
      throw const E2EChatSetupException(
        'The downloaded encrypted image size does not match the server '
        'message metadata.',
      );
    }
    if (cipherText.length <= E2ECryptoConstants.authenticationTagBytes ||
        cipherText.length > E2ECryptoConstants.maximumEncryptedMediaBytes) {
      throw const E2EChatSetupException(
        'The downloaded encrypted image has an invalid ciphertext size.',
      );
    }

    final Uint8List clearImage = await _cryptoService.decryptMedia(
      conversationId: message.conversationId,
      keyVersion: media.keyVersion,
      type: E2EPrivateMessageType.image,
      conversationKey: conversationKey,
      payload: E2EEncryptedPayload(
        cipherTextWithMac: cipherText,
        nonce: media.nonce,
      ),
    );
    E2EImageValidator.validate(clearImage);
    return clearImage;
  }

  Future<Uint8List> downloadAndDecryptVoice({
    required String userId,
    required ChatMessage message,
  }) async {
    final _EncryptedMediaDescriptor media =
        _validateEncryptedVoiceMessage(message);
    final E2EConversationKey conversationKey =
        await _readOrRecoverConversationKey(
      userId: userId,
      conversationId: message.conversationId,
      keyVersion: media.keyVersion,
    );
    final Uint8List cipherText =
        await _transport.downloadEncryptedAttachment(media.attachmentUrl);
    if (cipherText.length != media.encryptedSizeBytes) {
      throw const E2EChatSetupException(
        'The downloaded encrypted voice size does not match the server '
        'message metadata.',
      );
    }
    if (cipherText.length <= E2ECryptoConstants.authenticationTagBytes ||
        cipherText.length > E2ECryptoConstants.maximumEncryptedMediaBytes) {
      throw const E2EChatSetupException(
        'The downloaded encrypted voice message has an invalid ciphertext '
        'size.',
      );
    }

    final int durationMilliseconds = media.durationMilliseconds!;
    final Uint8List clearVoice = await _cryptoService.decryptMedia(
      conversationId: message.conversationId,
      keyVersion: media.keyVersion,
      type: E2EPrivateMessageType.voice,
      conversationKey: conversationKey,
      payload: E2EEncryptedPayload(
        cipherTextWithMac: cipherText,
        nonce: media.nonce,
      ),
      durationMilliseconds: durationMilliseconds,
    );
    E2EVoiceValidator.validate(
      bytes: clearVoice,
      durationMilliseconds: durationMilliseconds,
    );
    return clearVoice;
  }

  Future<List<ChatMessage>> decryptMessages({
    required String userId,
    required Iterable<ChatMessage> messages,
  }) =>
      Future.wait<ChatMessage>(
        messages.map(
          (ChatMessage message) => decryptTextMessage(
            userId: userId,
            message: message,
          ),
        ),
      );

  Future<ChatMessage> decryptTextMessage({
    required String userId,
    required ChatMessage message,
  }) async {
    if (message.isLegacy) {
      return message;
    }
    if (message.encryptionVersion != ChatEncryptionVersion.clientE2E) {
      return message.withDecryptionError(
        'This message uses an unsupported encryption version.',
      );
    }
    if (message.type == MessageType.system) {
      return message.withDecryptionError(
        'System messages may not use private E2E payloads.',
      );
    }
    if (message.type != MessageType.text) {
      return message;
    }
    if (message.content != null || _hasAttachmentMetadata(message)) {
      return message.withDecryptionError(
        'The encrypted text message contains invalid plaintext or attachment '
        'metadata.',
      );
    }

    final int? keyVersion = message.keyVersion;
    final List<int>? encryptedContent = message.encryptedContent;
    final List<int>? contentNonce = message.contentNonce;
    if (keyVersion == null ||
        keyVersion < 1 ||
        encryptedContent == null ||
        contentNonce == null) {
      return message.withDecryptionError(
        'The encrypted message is missing required metadata.',
      );
    }

    try {
      final E2EConversationKey conversationKey =
          await _readOrRecoverConversationKey(
        userId: userId,
        conversationId: message.conversationId,
        keyVersion: keyVersion,
      );
      final String clearText = await _cryptoService.decryptText(
        conversationId: message.conversationId,
        keyVersion: keyVersion,
        conversationKey: conversationKey,
        payload: E2EEncryptedPayload(
          cipherTextWithMac: encryptedContent,
          nonce: contentNonce,
        ),
      );
      return message.withDecryptedContent(clearText);
    } on E2EAuthenticationException {
      return message.withDecryptionError(
        'Message authentication failed. The ciphertext or nonce may have '
        'been changed.',
      );
    } on E2EKeyTrustException catch (error) {
      return message.withDecryptionError(error.message);
    } on E2EChatSetupException catch (error) {
      return message.withDecryptionError(error.message);
    } catch (_) {
      return message.withDecryptionError(
        'The encrypted message could not be decrypted on this device.',
      );
    }
  }

  Future<E2EDeviceKeyRecord> _registerDevice(String normalizedUserId) async {
    final E2EDevicePublicIdentity identity =
        await _cryptoService.loadOrCreateDeviceIdentity(
      userId: normalizedUserId,
    );
    final E2EDeviceKeyRecord registered =
        await _transport.registerDeviceKey(identity);

    if (_identifier(registered.userId, 'registered.userId') !=
            normalizedUserId ||
        !registered.matchesIdentity(identity)) {
      throw const E2EChatSetupException(
        'The server returned a device key that does not match this local '
        'E2E identity.',
      );
    }
    return registered;
  }

  Future<_ConversationContext> _loadConversationContext({
    required String userId,
    required ConversationItem conversation,
    required int keyVersion,
    required bool forceRefresh,
  }) {
    final String normalizedUserId = _identifier(userId, 'userId');
    final String normalizedConversationId =
        _identifier(conversation.id, 'conversation.id');
    if (keyVersion < 1) {
      throw ArgumentError.value(
        keyVersion,
        'keyVersion',
        'Key version must be greater than zero.',
      );
    }

    final String cacheKey =
        '$normalizedUserId|$normalizedConversationId|$keyVersion';
    if (!forceRefresh) {
      final _ConversationContext? cached = _contexts[cacheKey];
      if (cached != null) {
        return Future<_ConversationContext>.value(cached);
      }
    }

    final Future<_ConversationContext>? current = _contextLoads[cacheKey];
    if (current != null) {
      return current;
    }

    late final Future<_ConversationContext> load;
    load = _prepareConversationContext(
      userId: normalizedUserId,
      conversation: conversation,
      keyVersion: keyVersion,
    ).then((_ConversationContext value) {
      _contexts[cacheKey] = value;
      _conversationKeys[cacheKey] = value.conversationKey;
      return value;
    }).whenComplete(() {
      if (identical(_contextLoads[cacheKey], load)) {
        _contextLoads.remove(cacheKey);
      }
    });
    _contextLoads[cacheKey] = load;
    return load;
  }

  Future<_ConversationContext> _prepareConversationContext({
    required String userId,
    required ConversationItem conversation,
    required int keyVersion,
  }) async {
    final E2EDeviceKeyRecord registered =
        await ensureDeviceRegistered(userId: userId);
    final List<E2EDeviceKeyRecord> deviceKeys =
        await _transport.getAllConversationDeviceKeys(conversation.id);
    _validateDeviceRoster(
      currentUserId: userId,
      conversation: conversation,
      deviceKeys: deviceKeys,
    );
    final E2EDeviceKeyRecord currentDevice = _findCurrentDevice(
      registered: registered,
      deviceKeys: deviceKeys,
    );

    await _verifyPeerKeys(
      currentUserId: userId,
      currentDeviceKeyId: currentDevice.id,
      deviceKeys: deviceKeys,
    );

    final E2EConversationKey? stored = await _cryptoService.readConversationKey(
      userId: userId,
      conversationId: conversation.id,
      keyVersion: keyVersion,
    );
    final E2EConversationKeyEnvelopeRecord? ownEnvelope =
        await _transport.tryGetConversationKeyEnvelope(
      conversationId: conversation.id,
      recipientDeviceKeyId: currentDevice.id,
      keyVersion: keyVersion,
    );

    if (ownEnvelope != null) {
      final E2EConversationKey opened = await _openOwnEnvelope(
        userId: userId,
        conversationId: conversation.id,
        keyVersion: keyVersion,
        currentDevice: currentDevice,
        deviceKeys: deviceKeys,
        envelope: ownEnvelope,
      );
      final E2EConversationKey conversationKey =
          _validatedStoredOrOpenedKey(stored: stored, opened: opened);
      if (stored == null) {
        await _cryptoService.storeConversationKey(
          userId: userId,
          conversationId: conversation.id,
          keyVersion: keyVersion,
          conversationKey: conversationKey,
        );
      }
      await _ensureAdditionalEnvelopes(
        userId: userId,
        conversationId: conversation.id,
        currentDevice: currentDevice,
        deviceKeys: deviceKeys,
        conversationKey: conversationKey,
        keyVersion: keyVersion,
      );
      return _ConversationContext(
        userId: userId,
        conversationId: conversation.id,
        currentDevice: currentDevice,
        deviceKeys: deviceKeys,
        keyVersion: keyVersion,
        conversationKey: conversationKey,
      );
    }

    return _bootstrapConversationKey(
      userId: userId,
      conversationId: conversation.id,
      currentDevice: currentDevice,
      deviceKeys: deviceKeys,
      keyVersion: keyVersion,
      storedConversationKey: stored,
    );
  }

  Future<_ConversationContext> _bootstrapConversationKey({
    required String userId,
    required String conversationId,
    required E2EDeviceKeyRecord currentDevice,
    required List<E2EDeviceKeyRecord> deviceKeys,
    required int keyVersion,
    required E2EConversationKey? storedConversationKey,
  }) async {
    final E2EConversationKey candidate =
        storedConversationKey ?? await _cryptoService.generateConversationKey();
    final List<E2EDeviceKeyRecord> orderedDevices =
        List<E2EDeviceKeyRecord>.of(deviceKeys)
          ..sort(
            (E2EDeviceKeyRecord left, E2EDeviceKeyRecord right) =>
                _identifier(left.id, 'deviceKey.id').compareTo(
              _identifier(right.id, 'deviceKey.id'),
            ),
          );
    final E2EDeviceKeyRecord claimDevice = orderedDevices.first;

    try {
      await _putEnvelopeForDevice(
        userId: userId,
        conversationId: conversationId,
        currentDevice: currentDevice,
        recipientDevice: claimDevice,
        conversationKey: candidate,
        keyVersion: keyVersion,
      );
    } catch (error) {
      if (!_isConflict(error)) {
        rethrow;
      }

      return _recoverAfterBootstrapConflict(
        userId: userId,
        conversationId: conversationId,
        currentDevice: currentDevice,
        deviceKeys: deviceKeys,
        keyVersion: keyVersion,
        storedConversationKey: storedConversationKey,
      );
    }

    if (currentDevice.id != claimDevice.id) {
      try {
        await _putEnvelopeForDevice(
          userId: userId,
          conversationId: conversationId,
          currentDevice: currentDevice,
          recipientDevice: currentDevice,
          conversationKey: candidate,
          keyVersion: keyVersion,
        );
      } catch (error) {
        if (!_isConflict(error)) {
          rethrow;
        }
        await _verifyExistingOwnEnvelopeMatches(
          userId: userId,
          conversationId: conversationId,
          currentDevice: currentDevice,
          deviceKeys: deviceKeys,
          keyVersion: keyVersion,
          expectedConversationKey: candidate,
        );
      }
    }

    await _cryptoService.storeConversationKey(
      userId: userId,
      conversationId: conversationId,
      keyVersion: keyVersion,
      conversationKey: candidate,
    );
    await _ensureAdditionalEnvelopes(
      userId: userId,
      conversationId: conversationId,
      currentDevice: currentDevice,
      deviceKeys: orderedDevices,
      conversationKey: candidate,
      keyVersion: keyVersion,
    );
    return _ConversationContext(
      userId: userId,
      conversationId: conversationId,
      currentDevice: currentDevice,
      deviceKeys: deviceKeys,
      keyVersion: keyVersion,
      conversationKey: candidate,
    );
  }

  Future<void> _verifyExistingOwnEnvelopeMatches({
    required String userId,
    required String conversationId,
    required E2EDeviceKeyRecord currentDevice,
    required List<E2EDeviceKeyRecord> deviceKeys,
    required int keyVersion,
    required E2EConversationKey expectedConversationKey,
  }) async {
    final E2EConversationKeyEnvelopeRecord? ownEnvelope =
        await _transport.tryGetConversationKeyEnvelope(
      conversationId: conversationId,
      recipientDeviceKeyId: currentDevice.id,
      keyVersion: keyVersion,
    );
    if (ownEnvelope == null) {
      throw const E2EChatSetupException(
        'The server reported a conversation-key conflict but did not return '
        'this device envelope.',
      );
    }

    final E2EConversationKey opened = await _openOwnEnvelope(
      userId: userId,
      conversationId: conversationId,
      keyVersion: keyVersion,
      currentDevice: currentDevice,
      deviceKeys: deviceKeys,
      envelope: ownEnvelope,
    );
    _validatedStoredOrOpenedKey(
      stored: expectedConversationKey,
      opened: opened,
    );
  }

  Future<_ConversationContext> _recoverAfterBootstrapConflict({
    required String userId,
    required String conversationId,
    required E2EDeviceKeyRecord currentDevice,
    required List<E2EDeviceKeyRecord> deviceKeys,
    required int keyVersion,
    required E2EConversationKey? storedConversationKey,
  }) async {
    for (var attempt = 0; attempt < _bootstrapPollAttempts; attempt++) {
      final E2EConversationKeyEnvelopeRecord? envelope =
          await _transport.tryGetConversationKeyEnvelope(
        conversationId: conversationId,
        recipientDeviceKeyId: currentDevice.id,
        keyVersion: keyVersion,
      );
      if (envelope != null) {
        final E2EConversationKey opened = await _openOwnEnvelope(
          userId: userId,
          conversationId: conversationId,
          keyVersion: keyVersion,
          currentDevice: currentDevice,
          deviceKeys: deviceKeys,
          envelope: envelope,
        );
        final E2EConversationKey conversationKey = _validatedStoredOrOpenedKey(
          stored: storedConversationKey,
          opened: opened,
        );
        if (storedConversationKey == null) {
          await _cryptoService.storeConversationKey(
            userId: userId,
            conversationId: conversationId,
            keyVersion: keyVersion,
            conversationKey: conversationKey,
          );
        }
        await _ensureAdditionalEnvelopes(
          userId: userId,
          conversationId: conversationId,
          currentDevice: currentDevice,
          deviceKeys: deviceKeys,
          conversationKey: conversationKey,
          keyVersion: keyVersion,
        );
        return _ConversationContext(
          userId: userId,
          conversationId: conversationId,
          currentDevice: currentDevice,
          deviceKeys: deviceKeys,
          keyVersion: keyVersion,
          conversationKey: conversationKey,
        );
      }

      if (attempt + 1 < _bootstrapPollAttempts) {
        await _delay(_bootstrapPollDelay);
      }
    }

    throw const E2EChatSetupException(
      'Another device is preparing this secure conversation. Retry in a '
      'moment. No plaintext message was sent.',
    );
  }

  Future<void> _ensureAdditionalEnvelopes({
    required String userId,
    required String conversationId,
    required E2EDeviceKeyRecord currentDevice,
    required List<E2EDeviceKeyRecord> deviceKeys,
    required E2EConversationKey conversationKey,
    required int keyVersion,
  }) async {
    await Future.wait<void>(
      deviceKeys.map((E2EDeviceKeyRecord recipient) async {
        if (recipient.id == currentDevice.id) {
          return;
        }
        try {
          await _putEnvelopeForDevice(
            userId: userId,
            conversationId: conversationId,
            currentDevice: currentDevice,
            recipientDevice: recipient,
            conversationKey: conversationKey,
            keyVersion: keyVersion,
          );
        } catch (error) {
          if (!_isConflict(error)) {
            rethrow;
          }
        }
      }),
    );
  }

  Future<void> _putEnvelopeForDevice({
    required String userId,
    required String conversationId,
    required E2EDeviceKeyRecord currentDevice,
    required E2EDeviceKeyRecord recipientDevice,
    required E2EConversationKey conversationKey,
    required int keyVersion,
  }) async {
    final E2EConversationKeyEnvelope envelope =
        await _cryptoService.wrapConversationKey(
      userId: userId,
      conversationKey: conversationKey,
      recipientPublicKey: recipientDevice.publicKey,
      context: E2EEnvelopeContext(
        conversationId: conversationId,
        senderDeviceKeyId: currentDevice.id,
        recipientDeviceKeyId: recipientDevice.id,
        keyVersion: keyVersion,
      ),
    );
    final E2EConversationKeyEnvelopeRecord response =
        await _transport.putConversationKeyEnvelope(
      conversationId: conversationId,
      envelope: envelope,
    );
    _validateEnvelopeResponse(response: response, request: envelope);
  }

  Future<E2EConversationKey> _readOrRecoverConversationKey({
    required String userId,
    required String conversationId,
    required int keyVersion,
  }) {
    final String normalizedUserId = _identifier(userId, 'userId');
    final String normalizedConversationId =
        _identifier(conversationId, 'conversationId');
    if (keyVersion < 1) {
      throw ArgumentError.value(
        keyVersion,
        'keyVersion',
        'Key version must be greater than zero.',
      );
    }

    final String cacheKey =
        '$normalizedUserId|$normalizedConversationId|$keyVersion';
    final E2EConversationKey? cachedKey = _conversationKeys[cacheKey];
    if (cachedKey != null) {
      return Future<E2EConversationKey>.value(cachedKey);
    }
    final _ConversationContext? context = _contexts[cacheKey];
    if (context != null) {
      _conversationKeys[cacheKey] = context.conversationKey;
      return Future<E2EConversationKey>.value(context.conversationKey);
    }
    final Future<_ConversationContext>? contextLoad = _contextLoads[cacheKey];
    if (contextLoad != null) {
      return contextLoad.then(
        (_ConversationContext value) => value.conversationKey,
      );
    }

    final Future<E2EConversationKey>? current = _conversationKeyLoads[cacheKey];
    if (current != null) {
      return current;
    }

    late final Future<E2EConversationKey> load;
    load = _readOrRecoverConversationKeyCore(
      userId: normalizedUserId,
      conversationId: normalizedConversationId,
      keyVersion: keyVersion,
    ).then((E2EConversationKey value) {
      _conversationKeys[cacheKey] = value;
      return value;
    }).whenComplete(() {
      if (identical(_conversationKeyLoads[cacheKey], load)) {
        _conversationKeyLoads.remove(cacheKey);
      }
    });
    _conversationKeyLoads[cacheKey] = load;
    return load;
  }

  Future<E2EConversationKey> _readOrRecoverConversationKeyCore({
    required String userId,
    required String conversationId,
    required int keyVersion,
  }) async {
    final E2EConversationKey? stored = await _cryptoService.readConversationKey(
      userId: userId,
      conversationId: conversationId,
      keyVersion: keyVersion,
    );
    if (stored != null) {
      return stored;
    }

    final E2EDeviceKeyRecord registered =
        await ensureDeviceRegistered(userId: userId);
    final List<E2EDeviceKeyRecord> deviceKeys =
        await _transport.getAllConversationDeviceKeys(conversationId);
    final E2EDeviceKeyRecord currentDevice = _findCurrentDevice(
      registered: registered,
      deviceKeys: deviceKeys,
    );
    await _verifyPeerKeys(
      currentUserId: userId,
      currentDeviceKeyId: currentDevice.id,
      deviceKeys: deviceKeys,
    );
    final E2EConversationKeyEnvelopeRecord? envelope =
        await _transport.tryGetConversationKeyEnvelope(
      conversationId: conversationId,
      recipientDeviceKeyId: currentDevice.id,
      keyVersion: keyVersion,
    );
    if (envelope == null) {
      throw const E2EChatSetupException(
        'This device does not have a conversation-key envelope for the '
        'encrypted message.',
      );
    }

    final E2EConversationKey opened = await _openOwnEnvelope(
      userId: userId,
      conversationId: conversationId,
      keyVersion: keyVersion,
      currentDevice: currentDevice,
      deviceKeys: deviceKeys,
      envelope: envelope,
    );
    await _cryptoService.storeConversationKey(
      userId: userId,
      conversationId: conversationId,
      keyVersion: keyVersion,
      conversationKey: opened,
    );
    return opened;
  }

  Future<E2EConversationKey> _openOwnEnvelope({
    required String userId,
    required String conversationId,
    required int keyVersion,
    required E2EDeviceKeyRecord currentDevice,
    required List<E2EDeviceKeyRecord> deviceKeys,
    required E2EConversationKeyEnvelopeRecord envelope,
  }) async {
    if (_identifier(envelope.conversationId, 'envelope.conversationId') !=
            _identifier(conversationId, 'conversationId') ||
        envelope.keyVersion != keyVersion) {
      throw const E2EChatSetupException(
        'The server returned a conversation-key envelope for the wrong '
        'conversation or key version.',
      );
    }
    if (_identifier(envelope.recipientDeviceKeyId, 'recipientDeviceKeyId') !=
        _identifier(currentDevice.id, 'currentDevice.id')) {
      throw const E2EChatSetupException(
        'The server returned a conversation-key envelope for another device.',
      );
    }

    final E2EDeviceKeyRecord senderDevice = deviceKeys.firstWhere(
      (E2EDeviceKeyRecord item) =>
          _identifier(item.id, 'deviceKey.id') ==
          _identifier(envelope.senderDeviceKeyId, 'senderDeviceKeyId'),
      orElse: () => throw const E2EChatSetupException(
        'The public key that created this conversation-key envelope is no '
        'longer available.',
      ),
    );
    return _cryptoService.openConversationKeyEnvelope(
      userId: userId,
      envelope: envelope.toCryptoEnvelope(),
      senderPublicKey: senderDevice.publicKey,
    );
  }

  E2EConversationKey _validatedStoredOrOpenedKey({
    required E2EConversationKey? stored,
    required E2EConversationKey opened,
  }) {
    if (stored != null && !_bytesEqual(stored.bytes, opened.bytes)) {
      throw const E2EConversationKeyMismatchException();
    }
    return stored ?? opened;
  }

  E2EDeviceKeyRecord _findCurrentDevice({
    required E2EDeviceKeyRecord registered,
    required List<E2EDeviceKeyRecord> deviceKeys,
  }) =>
      deviceKeys.firstWhere(
        (E2EDeviceKeyRecord item) =>
            _identifier(item.userId, 'deviceKey.userId') ==
                _identifier(registered.userId, 'registered.userId') &&
            _identifier(item.id, 'deviceKey.id') ==
                _identifier(registered.id, 'registered.id') &&
            item.deviceId == registered.deviceId &&
            _bytesEqual(item.publicKey, registered.publicKey),
        orElse: () => throw const E2EChatSetupException(
          'This registered device key is not available in the conversation.',
        ),
      );

  void _validateDeviceRoster({
    required String currentUserId,
    required ConversationItem conversation,
    required List<E2EDeviceKeyRecord> deviceKeys,
  }) {
    final Set<String> participantIds = conversation.participants
        .map(
          (ConversationParticipant participant) =>
              _identifier(participant.userId, 'participant.userId'),
        )
        .toSet();
    if (participantIds.length != conversation.participants.length) {
      throw const E2EChatSetupException(
        'The conversation contains duplicate participant identities.',
      );
    }
    final List<ConversationParticipant> currentParticipants = conversation
        .participants
        .where(
            (ConversationParticipant participant) => participant.isCurrentUser)
        .toList(growable: false);
    if (currentParticipants.length != 1 ||
        _identifier(
              currentParticipants.single.userId,
              'currentParticipant.userId',
            ) !=
            _identifier(currentUserId, 'currentUserId')) {
      throw const E2EChatSetupException(
        'The conversation participant identity does not match the '
        'authenticated user.',
      );
    }

    final Set<String> deviceIds = <String>{};
    final Set<String> stableDeviceIds = <String>{};
    final Set<String> usersWithDevices = <String>{};
    for (final E2EDeviceKeyRecord device in deviceKeys) {
      final String normalizedUserId =
          _identifier(device.userId, 'deviceKey.userId');
      final String normalizedDeviceKeyId =
          _identifier(device.id, 'deviceKey.id');
      final String normalizedStableId =
          _identifier(device.deviceId, 'deviceKey.deviceId');
      if (!participantIds.contains(normalizedUserId)) {
        throw const E2EChatSetupException(
          'The server returned a device key for a non-participant. Secure '
          'messaging was stopped.',
        );
      }
      if (!deviceIds.add(normalizedDeviceKeyId) ||
          !stableDeviceIds.add('$normalizedUserId|$normalizedStableId')) {
        throw const E2EChatSetupException(
          'The server returned duplicate device-key identities.',
        );
      }
      if (device.publicKey.length != E2ECryptoConstants.x25519KeyBytes ||
          device.publicKey.every((int byte) => byte == 0)) {
        throw const E2EChatSetupException(
          'The server returned an invalid X25519 public device key.',
        );
      }
      usersWithDevices.add(normalizedUserId);
    }

    final List<String> missingNames = conversation.participants
        .where(
          (ConversationParticipant participant) => !usersWithDevices.contains(
            _identifier(participant.userId, 'participant.userId'),
          ),
        )
        .map((ConversationParticipant participant) => participant.displayName)
        .toList(growable: false);
    if (missingNames.isNotEmpty) {
      throw E2EChatSetupException(
        '${missingNames.join(', ')} must open the updated mobile app once '
        'before end-to-end encrypted messages can be sent.',
      );
    }
  }

  Future<void> _verifyPeerKeys({
    required String currentUserId,
    required String currentDeviceKeyId,
    required List<E2EDeviceKeyRecord> deviceKeys,
  }) async {
    await Future.wait<void>(
      deviceKeys
          .where(
            (E2EDeviceKeyRecord item) => item.id != currentDeviceKeyId,
          )
          .map(
            (E2EDeviceKeyRecord item) => _keyTrustStore.verifyOrTrust(
              currentUserId: currentUserId,
              peerDevice: item,
            ),
          ),
    );
  }

  void _validateEnvelopeResponse({
    required E2EConversationKeyEnvelopeRecord response,
    required E2EConversationKeyEnvelope request,
  }) {
    final E2EEnvelopeContext context = request.context;
    final E2EEncryptedPayload payload = request.payload;
    if (_identifier(response.conversationId, 'envelope.conversationId') !=
            _identifier(context.conversationId, 'conversationId') ||
        _identifier(
              response.senderDeviceKeyId,
              'envelope.senderDeviceKeyId',
            ) !=
            _identifier(context.senderDeviceKeyId, 'senderDeviceKeyId') ||
        _identifier(
              response.recipientDeviceKeyId,
              'envelope.recipientDeviceKeyId',
            ) !=
            _identifier(
              context.recipientDeviceKeyId,
              'recipientDeviceKeyId',
            ) ||
        response.keyVersion != context.keyVersion ||
        !_bytesEqual(
          response.encryptedConversationKey,
          payload.cipherTextWithMac,
        ) ||
        !_bytesEqual(response.nonce, payload.nonce)) {
      throw const E2EChatSetupException(
        'The server returned an invalid conversation-key envelope response.',
      );
    }
  }

  void _validateEncryptedTextResponse({
    required ChatMessage response,
    required _ConversationContext context,
    required E2EEncryptedPayload requestPayload,
  }) {
    final List<int>? encryptedContent = response.encryptedContent;
    final List<int>? contentNonce = response.contentNonce;
    if (_identifier(response.conversationId, 'message.conversationId') !=
            context.conversationId ||
        _identifier(response.senderUserId, 'message.senderUserId') !=
            context.userId ||
        response.type != MessageType.text ||
        response.encryptionVersion != ChatEncryptionVersion.clientE2E ||
        response.keyVersion != context.keyVersion ||
        response.content != null ||
        _hasAttachmentMetadata(response) ||
        encryptedContent == null ||
        contentNonce == null ||
        !_bytesEqual(
          encryptedContent,
          requestPayload.cipherTextWithMac,
        ) ||
        !_bytesEqual(contentNonce, requestPayload.nonce)) {
      throw const E2EChatSetupException(
        'The server returned an invalid response for the encrypted text '
        'message.',
      );
    }
  }

  void _validateEncryptedMediaResponse({
    required ChatMessage response,
    required _ConversationContext context,
    required E2EPrivateMessageType type,
    required E2EEncryptedPayload requestPayload,
    int? durationMilliseconds,
  }) {
    final String? attachmentId = response.attachmentId;
    final String? attachmentUrl = response.attachmentUrl;
    final List<int>? attachmentNonce = response.attachmentNonce;
    final int? attachmentSizeBytes = response.attachmentSizeBytes;
    if (_identifier(response.conversationId, 'message.conversationId') !=
            context.conversationId ||
        _identifier(response.senderUserId, 'message.senderUserId') !=
            context.userId ||
        response.type != type.wireValue ||
        response.encryptionVersion != ChatEncryptionVersion.clientE2E ||
        response.keyVersion != context.keyVersion ||
        response.content != null ||
        response.encryptedContent != null ||
        response.contentNonce != null ||
        attachmentId == null ||
        attachmentUrl == null ||
        response.attachmentMimeType?.toLowerCase() !=
            E2ECryptoConstants.encryptedMediaContentType ||
        attachmentNonce == null ||
        response.attachmentEncryptionVersion !=
            ChatEncryptionVersion.clientE2E ||
        response.attachmentKeyVersion != context.keyVersion ||
        attachmentSizeBytes != requestPayload.cipherTextWithMac.length ||
        response.attachmentDurationMilliseconds != durationMilliseconds ||
        !_bytesEqual(attachmentNonce, requestPayload.nonce) ||
        !_isExpectedAttachmentUrl(attachmentUrl, attachmentId)) {
      throw E2EChatSetupException(
        'The server returned an invalid response for the encrypted '
        '${type.name} message.',
      );
    }
  }

  _EncryptedMediaDescriptor _validateEncryptedImageMessage(
    ChatMessage message,
  ) {
    if (message.encryptionVersion != ChatEncryptionVersion.clientE2E ||
        message.type != MessageType.image ||
        message.content != null ||
        message.encryptedContent != null ||
        message.contentNonce != null) {
      throw const E2EChatSetupException(
        'The encrypted image message contains invalid plaintext or message '
        'payload metadata.',
      );
    }

    final int? keyVersion = message.keyVersion;
    final String? attachmentId = message.attachmentId;
    final String? attachmentUrl = message.attachmentUrl;
    final List<int>? attachmentNonce = message.attachmentNonce;
    final int? attachmentSizeBytes = message.attachmentSizeBytes;
    if (keyVersion == null ||
        keyVersion < 1 ||
        attachmentId == null ||
        attachmentUrl == null ||
        message.attachmentMimeType?.toLowerCase() !=
            E2ECryptoConstants.encryptedMediaContentType ||
        attachmentNonce == null ||
        attachmentNonce.length != E2ECryptoConstants.nonceBytes ||
        message.attachmentEncryptionVersion !=
            ChatEncryptionVersion.clientE2E ||
        message.attachmentKeyVersion != keyVersion ||
        attachmentSizeBytes == null ||
        attachmentSizeBytes <= E2ECryptoConstants.authenticationTagBytes ||
        attachmentSizeBytes > E2ECryptoConstants.maximumEncryptedMediaBytes ||
        message.attachmentDurationMilliseconds != null ||
        !_isExpectedAttachmentUrl(attachmentUrl, attachmentId)) {
      throw const E2EChatSetupException(
        'The encrypted image message is missing valid attachment metadata.',
      );
    }

    return _EncryptedMediaDescriptor(
      attachmentUrl: attachmentUrl,
      nonce: attachmentNonce,
      encryptedSizeBytes: attachmentSizeBytes,
      keyVersion: keyVersion,
    );
  }

  _EncryptedMediaDescriptor _validateEncryptedVoiceMessage(
    ChatMessage message,
  ) {
    if (message.encryptionVersion != ChatEncryptionVersion.clientE2E ||
        message.type != MessageType.voice ||
        message.content != null ||
        message.encryptedContent != null ||
        message.contentNonce != null) {
      throw const E2EChatSetupException(
        'The encrypted voice message contains invalid plaintext or message '
        'payload metadata.',
      );
    }

    final int? keyVersion = message.keyVersion;
    final String? attachmentId = message.attachmentId;
    final String? attachmentUrl = message.attachmentUrl;
    final List<int>? attachmentNonce = message.attachmentNonce;
    final int? attachmentSizeBytes = message.attachmentSizeBytes;
    final int? durationMilliseconds = message.attachmentDurationMilliseconds;
    if (keyVersion == null ||
        keyVersion < 1 ||
        attachmentId == null ||
        attachmentUrl == null ||
        message.attachmentMimeType?.toLowerCase() !=
            E2ECryptoConstants.encryptedMediaContentType ||
        attachmentNonce == null ||
        attachmentNonce.length != E2ECryptoConstants.nonceBytes ||
        message.attachmentEncryptionVersion !=
            ChatEncryptionVersion.clientE2E ||
        message.attachmentKeyVersion != keyVersion ||
        attachmentSizeBytes == null ||
        attachmentSizeBytes <= E2ECryptoConstants.authenticationTagBytes ||
        attachmentSizeBytes > E2ECryptoConstants.maximumEncryptedMediaBytes ||
        durationMilliseconds == null ||
        durationMilliseconds < E2EVoiceValidator.minimumDurationMilliseconds ||
        durationMilliseconds > E2EVoiceValidator.maximumDurationMilliseconds ||
        !_isExpectedAttachmentUrl(attachmentUrl, attachmentId)) {
      throw const E2EChatSetupException(
        'The encrypted voice message is missing valid attachment metadata.',
      );
    }

    return _EncryptedMediaDescriptor(
      attachmentUrl: attachmentUrl,
      nonce: attachmentNonce,
      encryptedSizeBytes: attachmentSizeBytes,
      keyVersion: keyVersion,
      durationMilliseconds: durationMilliseconds,
    );
  }

  bool _isExpectedAttachmentUrl(String attachmentUrl, String attachmentId) {
    final Uri? uri = Uri.tryParse(attachmentUrl.trim());
    if (uri == null ||
        uri.isAbsolute ||
        uri.host.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    final String expectedPath =
        '/api/media/message-attachments/${attachmentId.trim().toLowerCase()}';
    return uri.path.toLowerCase() == expectedPath;
  }

  bool _hasAttachmentMetadata(ChatMessage message) =>
      message.attachmentId != null ||
      message.attachmentUrl != null ||
      message.attachmentMimeType != null ||
      message.attachmentNonce != null ||
      message.attachmentEncryptionVersion != null ||
      message.attachmentKeyVersion != null ||
      message.attachmentSizeBytes != null ||
      message.attachmentDurationMilliseconds != null;

  bool _isConflict(Object error) => ApiException.from(error).statusCode == 409;

  String _identifier(String value, String fieldName) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required.');
    }
    return normalized;
  }

  bool _bytesEqual(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}

final class _ConversationContext {
  _ConversationContext({
    required this.userId,
    required this.conversationId,
    required this.currentDevice,
    required List<E2EDeviceKeyRecord> deviceKeys,
    required this.keyVersion,
    required this.conversationKey,
  }) : deviceKeys = List<E2EDeviceKeyRecord>.unmodifiable(deviceKeys);

  final String userId;
  final String conversationId;
  final E2EDeviceKeyRecord currentDevice;
  final List<E2EDeviceKeyRecord> deviceKeys;
  final int keyVersion;
  final E2EConversationKey conversationKey;
}

final class _EncryptedMediaDescriptor {
  _EncryptedMediaDescriptor({
    required this.attachmentUrl,
    required List<int> nonce,
    required this.encryptedSizeBytes,
    required this.keyVersion,
    this.durationMilliseconds,
  }) : nonce = Uint8List.fromList(nonce);

  final String attachmentUrl;
  final Uint8List nonce;
  final int encryptedSizeBytes;
  final int keyVersion;
  final int? durationMilliseconds;
}
