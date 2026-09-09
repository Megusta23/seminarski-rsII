import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_secure_storage.dart';

class E2ECryptoException implements Exception {
  const E2ECryptoException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

final class E2EAuthenticationException extends E2ECryptoException {
  const E2EAuthenticationException([
    super.message = 'Encrypted content could not be authenticated.',
    super.cause,
  ]);
}

final class E2EKeyStorageException extends E2ECryptoException {
  const E2EKeyStorageException(super.message, [super.cause]);
}

final class E2ECryptoService {
  E2ECryptoService({
    E2ESecureStorage? secureStorage,
    Random? random,
    X25519? keyAgreement,
    Hkdf? keyDerivation,
    AesGcm? cipher,
  })  : _secureStorage = secureStorage ?? FlutterE2ESecureStorage(),
        _random = random ?? SecureRandom.system,
        _keyAgreement = keyAgreement ?? X25519(),
        _keyDerivation = keyDerivation ??
            Hkdf(
              hmac: Hmac.sha256(),
              outputLength: E2ECryptoConstants.conversationKeyBytes,
            ),
        _cipher = cipher ?? AesGcm.with256bits() {
    if (_cipher.secretKeyLength != E2ECryptoConstants.conversationKeyBytes ||
        _cipher.nonceLength != E2ECryptoConstants.nonceBytes ||
        _cipher.macAlgorithm.macLength !=
            E2ECryptoConstants.authenticationTagBytes) {
      throw ArgumentError(
        'E2E cipher must use a 32-byte key, 12-byte nonce, and 16-byte tag.',
      );
    }
  }

  static const String _installationDeviceIdKey =
      'ladder_social.e2e.installation_device_id.v1';
  static const String _identityPrefix = 'ladder_social.e2e.identity.v1';
  static const String _conversationKeyPrefix =
      'ladder_social.e2e.conversation_key.v1';
  static final Uint8List _wrapKdfInfo = Uint8List.fromList(
    utf8.encode('ladder-social/e2e/v1/wrap-key'),
  );

  final E2ESecureStorage _secureStorage;
  final Random _random;
  final X25519 _keyAgreement;
  final Hkdf _keyDerivation;
  final AesGcm _cipher;
  final Map<String, Future<_StoredDeviceIdentity>> _identityLoads =
      <String, Future<_StoredDeviceIdentity>>{};

  Future<E2EDevicePublicIdentity> loadOrCreateDeviceIdentity({
    required String userId,
  }) async {
    final _StoredDeviceIdentity identity =
        await _loadOrCreateDeviceIdentity(userId);
    return E2EDevicePublicIdentity(
      deviceId: identity.deviceId,
      publicKey: identity.publicKey,
    );
  }

  Future<E2EConversationKey> generateConversationKey() async =>
      E2EConversationKey(
        _randomBytes(E2ECryptoConstants.conversationKeyBytes),
      );

  Future<void> storeConversationKey({
    required String userId,
    required String conversationId,
    required int keyVersion,
    required E2EConversationKey conversationKey,
  }) async {
    final String storageKey = _conversationStorageKey(
      userId: userId,
      conversationId: conversationId,
      keyVersion: keyVersion,
    );
    try {
      await _secureStorage.write(
        storageKey,
        base64Encode(conversationKey.bytes),
      );
    } catch (error) {
      throw E2EKeyStorageException(
        'The conversation key could not be saved in secure storage.',
        error,
      );
    }
  }

  Future<E2EConversationKey?> readConversationKey({
    required String userId,
    required String conversationId,
    required int keyVersion,
  }) async {
    final String storageKey = _conversationStorageKey(
      userId: userId,
      conversationId: conversationId,
      keyVersion: keyVersion,
    );
    final String? encoded;
    try {
      encoded = await _secureStorage.read(storageKey);
    } catch (error) {
      throw E2EKeyStorageException(
        'The conversation key could not be read from secure storage.',
        error,
      );
    }

    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      return E2EConversationKey(base64Decode(encoded));
    } on FormatException catch (error) {
      throw E2EKeyStorageException(
        'The stored conversation key is corrupted.',
        error,
      );
    } on ArgumentError catch (error) {
      throw E2EKeyStorageException(
        'The stored conversation key has an invalid length.',
        error,
      );
    }
  }

  Future<void> deleteConversationKey({
    required String userId,
    required String conversationId,
    required int keyVersion,
  }) async {
    try {
      await _secureStorage.delete(
        _conversationStorageKey(
          userId: userId,
          conversationId: conversationId,
          keyVersion: keyVersion,
        ),
      );
    } catch (error) {
      throw E2EKeyStorageException(
        'The conversation key could not be removed from secure storage.',
        error,
      );
    }
  }

  Future<E2EConversationKeyEnvelope> wrapConversationKey({
    required String userId,
    required E2EConversationKey conversationKey,
    required List<int> recipientPublicKey,
    required E2EEnvelopeContext context,
  }) async {
    final _StoredDeviceIdentity identity =
        await _loadOrCreateDeviceIdentity(userId);
    final SecretKey wrappingKey = await _deriveWrappingKey(
      privateSeed: identity.privateSeed,
      remotePublicKey: recipientPublicKey,
      context: context,
    );

    try {
      final SecretBox secretBox = await _cipher.encrypt(
        conversationKey.bytes,
        secretKey: wrappingKey,
        nonce: _randomBytes(E2ECryptoConstants.nonceBytes),
        aad: _envelopeAssociatedData(context),
      );
      return E2EConversationKeyEnvelope(
        context: context,
        payload: _payloadFromSecretBox(secretBox),
      );
    } catch (error) {
      throw E2ECryptoException(
        'The conversation key could not be wrapped.',
        error,
      );
    } finally {
      _destroySecretKey(wrappingKey);
    }
  }

  Future<E2EConversationKey> openConversationKeyEnvelope({
    required String userId,
    required E2EConversationKeyEnvelope envelope,
    required List<int> senderPublicKey,
  }) async {
    final _StoredDeviceIdentity identity =
        await _loadOrCreateDeviceIdentity(userId);
    final SecretKey wrappingKey = await _deriveWrappingKey(
      privateSeed: identity.privateSeed,
      remotePublicKey: senderPublicKey,
      context: envelope.context,
    );

    try {
      final List<int> clearText = await _cipher.decrypt(
        _secretBoxFromPayload(envelope.payload),
        secretKey: wrappingKey,
        aad: _envelopeAssociatedData(envelope.context),
      );
      return E2EConversationKey(clearText);
    } on SecretBoxAuthenticationError catch (error) {
      throw E2EAuthenticationException(
        'Conversation key envelope authentication failed.',
        error,
      );
    } on ArgumentError catch (error) {
      throw E2ECryptoException(
        'Conversation key envelope has an invalid format.',
        error,
      );
    } finally {
      _destroySecretKey(wrappingKey);
    }
  }

  Future<E2EEncryptedPayload> encryptText({
    required String conversationId,
    required int keyVersion,
    required E2EConversationKey conversationKey,
    required String plainText,
  }) async {
    if (plainText.trim().isEmpty) {
      throw ArgumentError.value(
        plainText,
        'plainText',
        'Text message may not be empty.',
      );
    }

    final Uint8List clearBytes = Uint8List.fromList(utf8.encode(plainText));
    if (clearBytes.length > E2ECryptoConstants.maximumPlainTextBytes) {
      throw ArgumentError.value(
        clearBytes.length,
        'plainText',
        'UTF-8 text may contain at most '
            '${E2ECryptoConstants.maximumPlainTextBytes} bytes.',
      );
    }

    return _encryptPayload(
      clearBytes: clearBytes,
      conversationKey: conversationKey,
      associatedData: _messageAssociatedData(
        conversationId: conversationId,
        keyVersion: keyVersion,
        type: E2EPrivateMessageType.text,
        payloadPart: 'content',
      ),
    );
  }

  Future<String> decryptText({
    required String conversationId,
    required int keyVersion,
    required E2EConversationKey conversationKey,
    required E2EEncryptedPayload payload,
  }) async {
    final Uint8List clearBytes = await _decryptPayload(
      payload: payload,
      conversationKey: conversationKey,
      associatedData: _messageAssociatedData(
        conversationId: conversationId,
        keyVersion: keyVersion,
        type: E2EPrivateMessageType.text,
        payloadPart: 'content',
      ),
    );

    try {
      return utf8.decode(clearBytes, allowMalformed: false);
    } on FormatException catch (error) {
      throw E2ECryptoException(
        'Decrypted text is not valid UTF-8.',
        error,
      );
    }
  }

  Future<E2EEncryptedPayload> encryptMedia({
    required String conversationId,
    required int keyVersion,
    required E2EPrivateMessageType type,
    required E2EConversationKey conversationKey,
    required List<int> clearBytes,
    int? durationMilliseconds,
  }) async {
    if (type == E2EPrivateMessageType.text) {
      throw ArgumentError.value(
        type,
        'type',
        'Use encryptText for text messages.',
      );
    }
    if (clearBytes.isEmpty) {
      throw ArgumentError.value(
        clearBytes.length,
        'clearBytes',
        'Media content may not be empty.',
      );
    }
    if (clearBytes.length > E2ECryptoConstants.maximumPlainMediaBytes) {
      throw ArgumentError.value(
        clearBytes.length,
        'clearBytes',
        'Media may contain at most '
            '${E2ECryptoConstants.maximumPlainMediaBytes} plaintext bytes.',
      );
    }
    _validateMediaDuration(type, durationMilliseconds);

    return _encryptPayload(
      clearBytes: clearBytes,
      conversationKey: conversationKey,
      associatedData: _messageAssociatedData(
        conversationId: conversationId,
        keyVersion: keyVersion,
        type: type,
        payloadPart: 'attachment',
        durationMilliseconds: durationMilliseconds,
      ),
    );
  }

  Future<Uint8List> decryptMedia({
    required String conversationId,
    required int keyVersion,
    required E2EPrivateMessageType type,
    required E2EConversationKey conversationKey,
    required E2EEncryptedPayload payload,
    int? durationMilliseconds,
  }) {
    if (type == E2EPrivateMessageType.text) {
      throw ArgumentError.value(
        type,
        'type',
        'Use decryptText for text messages.',
      );
    }
    _validateMediaDuration(type, durationMilliseconds);

    return _decryptPayload(
      payload: payload,
      conversationKey: conversationKey,
      associatedData: _messageAssociatedData(
        conversationId: conversationId,
        keyVersion: keyVersion,
        type: type,
        payloadPart: 'attachment',
        durationMilliseconds: durationMilliseconds,
      ),
    );
  }

  Future<E2EEncryptedPayload> _encryptPayload({
    required List<int> clearBytes,
    required E2EConversationKey conversationKey,
    required List<int> associatedData,
  }) async {
    final SecretKey secretKey = SecretKey(conversationKey.bytes);
    try {
      final SecretBox secretBox = await _cipher.encrypt(
        clearBytes,
        secretKey: secretKey,
        nonce: _randomBytes(E2ECryptoConstants.nonceBytes),
        aad: associatedData,
      );
      return _payloadFromSecretBox(secretBox);
    } catch (error) {
      throw E2ECryptoException('Content encryption failed.', error);
    } finally {
      _destroySecretKey(secretKey);
    }
  }

  Future<Uint8List> _decryptPayload({
    required E2EEncryptedPayload payload,
    required E2EConversationKey conversationKey,
    required List<int> associatedData,
  }) async {
    final SecretKey secretKey = SecretKey(conversationKey.bytes);
    try {
      final List<int> clearText = await _cipher.decrypt(
        _secretBoxFromPayload(payload),
        secretKey: secretKey,
        aad: associatedData,
      );
      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError catch (error) {
      throw E2EAuthenticationException(
        'Encrypted content authentication failed.',
        error,
      );
    } on ArgumentError catch (error) {
      throw E2ECryptoException(
        'Encrypted content has an invalid format.',
        error,
      );
    } finally {
      _destroySecretKey(secretKey);
    }
  }

  Future<SecretKey> _deriveWrappingKey({
    required List<int> privateSeed,
    required List<int> remotePublicKey,
    required E2EEnvelopeContext context,
  }) async {
    _validatePrivateSeed(privateSeed);
    _validateX25519PublicKey(remotePublicKey);

    final SimpleKeyPair keyPair = await _keyAgreement.newKeyPairFromSeed(
      Uint8List.fromList(privateSeed),
    );
    SecretKey? sharedSecret;
    try {
      sharedSecret = await _keyAgreement.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: SimplePublicKey(
          remotePublicKey,
          type: KeyPairType.x25519,
        ),
      );
      final List<int> sharedSecretBytes = await sharedSecret.extractBytes();
      if (sharedSecretBytes.every((int byte) => byte == 0)) {
        throw const E2ECryptoException(
          'X25519 rejected a low-order remote public key.',
        );
      }

      return await _keyDerivation.deriveKey(
        secretKey: sharedSecret,
        nonce: _envelopeAssociatedData(context),
        info: _wrapKdfInfo,
      );
    } on E2ECryptoException {
      rethrow;
    } catch (error) {
      throw E2ECryptoException(
        'X25519 key agreement or HKDF key derivation failed.',
        error,
      );
    } finally {
      keyPair.destroy();
      if (sharedSecret != null) {
        _destroySecretKey(sharedSecret);
      }
    }
  }

  Future<_StoredDeviceIdentity> _loadOrCreateDeviceIdentity(
    String userId,
  ) {
    final String normalizedUserId = _requiredIdentifier(userId, 'userId');
    final Future<_StoredDeviceIdentity>? current =
        _identityLoads[normalizedUserId];
    if (current != null) {
      return current;
    }

    late final Future<_StoredDeviceIdentity> load;
    load = _loadOrCreateDeviceIdentityCore(normalizedUserId).whenComplete(() {
      if (identical(_identityLoads[normalizedUserId], load)) {
        _identityLoads.remove(normalizedUserId);
      }
    });
    _identityLoads[normalizedUserId] = load;
    return load;
  }

  Future<_StoredDeviceIdentity> _loadOrCreateDeviceIdentityCore(
    String normalizedUserId,
  ) async {
    final String namespace = _identityNamespace(normalizedUserId);
    final List<String?> stored;
    try {
      stored = await Future.wait<String?>(<Future<String?>>[
        _secureStorage.read(_installationDeviceIdKey),
        _secureStorage.read('$namespace.private_seed'),
        _secureStorage.read('$namespace.public_key'),
      ]);
    } catch (error) {
      throw E2EKeyStorageException(
        'The E2E device identity could not be read from secure storage.',
        error,
      );
    }

    String? deviceId = stored[0];
    final String? encodedPrivateSeed = stored[1];
    final String? encodedPublicKey = stored[2];

    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = 'ls-install-${_base64UrlWithoutPadding(_randomBytes(16))}';
      try {
        await _secureStorage.write(_installationDeviceIdKey, deviceId);
      } catch (error) {
        throw E2EKeyStorageException(
          'The stable E2E device ID could not be saved.',
          error,
        );
      }
    }
    deviceId = _requiredDeviceId(deviceId);

    if ((encodedPrivateSeed == null) != (encodedPublicKey == null)) {
      throw const E2EKeyStorageException(
        'The stored E2E identity is incomplete. Refusing silent key rotation.',
      );
    }

    if (encodedPrivateSeed == null && encodedPublicKey == null) {
      return _createAndStoreIdentity(
        deviceId: deviceId,
        namespace: namespace,
      );
    }

    try {
      final Uint8List privateSeed = Uint8List.fromList(
        base64Decode(encodedPrivateSeed!),
      );
      final Uint8List storedPublicKey = Uint8List.fromList(
        base64Decode(encodedPublicKey!),
      );
      _validatePrivateSeed(privateSeed);
      _validateX25519PublicKey(storedPublicKey);

      final SimpleKeyPair keyPair = await _keyAgreement.newKeyPairFromSeed(
        Uint8List.fromList(privateSeed),
      );
      try {
        final SimplePublicKey derivedPublicKey =
            await _extractSimplePublicKey(keyPair);
        if (!_bytesEqual(derivedPublicKey.bytes, storedPublicKey)) {
          throw const E2EKeyStorageException(
            'The stored E2E public and private keys do not match.',
          );
        }
      } finally {
        keyPair.destroy();
      }

      return _StoredDeviceIdentity(
        deviceId: deviceId,
        privateSeed: privateSeed,
        publicKey: storedPublicKey,
      );
    } on E2EKeyStorageException {
      rethrow;
    } on FormatException catch (error) {
      throw E2EKeyStorageException(
        'The stored E2E identity is not valid Base64.',
        error,
      );
    } on ArgumentError catch (error) {
      throw E2EKeyStorageException(
        'The stored E2E identity has invalid key material.',
        error,
      );
    }
  }

  Future<_StoredDeviceIdentity> _createAndStoreIdentity({
    required String deviceId,
    required String namespace,
  }) async {
    final Uint8List privateSeed =
        _randomBytes(E2ECryptoConstants.x25519KeyBytes);
    final SimpleKeyPair keyPair = await _keyAgreement.newKeyPairFromSeed(
      Uint8List.fromList(privateSeed),
    );
    final SimplePublicKey publicKey;
    try {
      publicKey = await _extractSimplePublicKey(keyPair);
    } finally {
      keyPair.destroy();
    }
    _validateX25519PublicKey(publicKey.bytes);

    try {
      await _secureStorage.write(
        '$namespace.private_seed',
        base64Encode(privateSeed),
      );
      await _secureStorage.write(
        '$namespace.public_key',
        base64Encode(publicKey.bytes),
      );
    } catch (error) {
      await Future.wait<void>(<Future<void>>[
        _deleteIgnoringStorageFailure('$namespace.private_seed'),
        _deleteIgnoringStorageFailure('$namespace.public_key'),
      ]);
      throw E2EKeyStorageException(
        'The new E2E device identity could not be saved.',
        error,
      );
    }

    return _StoredDeviceIdentity(
      deviceId: deviceId,
      privateSeed: privateSeed,
      publicKey: publicKey.bytes,
    );
  }

  Future<void> _deleteIgnoringStorageFailure(String key) async {
    try {
      await _secureStorage.delete(key);
    } catch (_) {
      return;
    }
  }

  Future<SimplePublicKey> _extractSimplePublicKey(
    SimpleKeyPair keyPair,
  ) async {
    final PublicKey publicKey = await keyPair.extractPublicKey();
    if (publicKey is! SimplePublicKey) {
      throw const E2ECryptoException(
        'X25519 returned an unexpected public key type.',
      );
    }
    return publicKey;
  }

  E2EEncryptedPayload _payloadFromSecretBox(SecretBox secretBox) {
    final Uint8List combined = Uint8List(
      secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    combined.setRange(
      0,
      secretBox.cipherText.length,
      secretBox.cipherText,
    );
    combined.setRange(
      secretBox.cipherText.length,
      combined.length,
      secretBox.mac.bytes,
    );
    return E2EEncryptedPayload(
      cipherTextWithMac: combined,
      nonce: secretBox.nonce,
    );
  }

  SecretBox _secretBoxFromPayload(E2EEncryptedPayload payload) {
    final Uint8List combined = payload.cipherTextWithMac;
    final int macStart =
        combined.length - E2ECryptoConstants.authenticationTagBytes;
    return SecretBox(
      combined.sublist(0, macStart),
      nonce: payload.nonce,
      mac: Mac(combined.sublist(macStart)),
    );
  }

  Uint8List _envelopeAssociatedData(E2EEnvelopeContext context) =>
      Uint8List.fromList(
        utf8.encode(
          'ladder-social/e2e/v${E2ECryptoConstants.protocolVersion}'
          '/envelope/${context.conversationId}'
          '/${context.senderDeviceKeyId}'
          '/${context.recipientDeviceKeyId}'
          '/${context.keyVersion}',
        ),
      );

  void _validateMediaDuration(
    E2EPrivateMessageType type,
    int? durationMilliseconds,
  ) {
    final bool requiresDuration = type == E2EPrivateMessageType.voice ||
        type == E2EPrivateMessageType.video;
    if (!requiresDuration) {
      if (durationMilliseconds != null) {
        throw ArgumentError.value(
          durationMilliseconds,
          'durationMilliseconds',
          'Image messages may not contain media duration.',
        );
      }
      return;
    }
    if (durationMilliseconds == null ||
        durationMilliseconds < 1 ||
        durationMilliseconds >
            E2ECryptoConstants.maximumMediaDurationMilliseconds) {
      throw ArgumentError.value(
        durationMilliseconds,
        'durationMilliseconds',
        'Voice and video duration must be between 1 millisecond and '
            '${E2ECryptoConstants.maximumMediaDurationMilliseconds} milliseconds.',
      );
    }
  }

  Uint8List _messageAssociatedData({
    required String conversationId,
    required int keyVersion,
    required E2EPrivateMessageType type,
    required String payloadPart,
    int? durationMilliseconds,
  }) {
    final String normalizedConversationId =
        _requiredIdentifier(conversationId, 'conversationId');
    if (keyVersion < 1) {
      throw ArgumentError.value(
        keyVersion,
        'keyVersion',
        'Key version must be greater than zero.',
      );
    }
    return Uint8List.fromList(
      utf8.encode(
        'ladder-social/e2e/v${E2ECryptoConstants.protocolVersion}'
        '/message/$normalizedConversationId'
        '/${type.wireValue}/$payloadPart/$keyVersion'
        '${durationMilliseconds == null ? '' : '/duration/$durationMilliseconds'}',
      ),
    );
  }

  String _identityNamespace(String normalizedUserId) =>
      '$_identityPrefix.${_storageToken(normalizedUserId)}';

  String _conversationStorageKey({
    required String userId,
    required String conversationId,
    required int keyVersion,
  }) {
    final String normalizedUserId = _requiredIdentifier(userId, 'userId');
    final String normalizedConversationId =
        _requiredIdentifier(conversationId, 'conversationId');
    if (keyVersion < 1) {
      throw ArgumentError.value(
        keyVersion,
        'keyVersion',
        'Key version must be greater than zero.',
      );
    }
    return '$_conversationKeyPrefix.${_storageToken(normalizedUserId)}'
        '.${_storageToken(normalizedConversationId)}.$keyVersion';
  }

  String _storageToken(String value) =>
      _base64UrlWithoutPadding(utf8.encode(value));

  String _base64UrlWithoutPadding(List<int> value) =>
      base64UrlEncode(value).replaceAll('=', '');

  String _requiredIdentifier(String value, String fieldName) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '$fieldName is required.');
    }
    return normalized;
  }

  String _requiredDeviceId(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 128) {
      throw const E2EKeyStorageException(
        'The stored E2E device ID has an invalid length.',
      );
    }
    if (normalized.runes.any((int rune) => rune < 0x20 || rune == 0x7f)) {
      throw const E2EKeyStorageException(
        'The stored E2E device ID contains control characters.',
      );
    }
    return normalized;
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList(
        List<int>.generate(
          length,
          (int _) => _random.nextInt(256),
          growable: false,
        ),
      );

  void _validatePrivateSeed(List<int> value) {
    if (value.length != E2ECryptoConstants.x25519KeyBytes) {
      throw ArgumentError.value(
        value.length,
        'privateSeed',
        'X25519 private seed must contain exactly 32 bytes.',
      );
    }
  }

  void _validateX25519PublicKey(List<int> value) {
    if (value.length != E2ECryptoConstants.x25519KeyBytes) {
      throw ArgumentError.value(
        value.length,
        'publicKey',
        'X25519 public key must contain exactly 32 bytes.',
      );
    }
    if (value.every((int byte) => byte == 0)) {
      throw ArgumentError.value(
        value,
        'publicKey',
        'X25519 public key may not be all zero.',
      );
    }
  }

  bool _bytesEqual(List<int> first, List<int> second) {
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }

  void _destroySecretKey(SecretKey key) {
    if (!key.isDestroyed) {
      key.destroy();
    }
  }
}

final class _StoredDeviceIdentity {
  _StoredDeviceIdentity({
    required this.deviceId,
    required List<int> privateSeed,
    required List<int> publicKey,
  })  : privateSeed = Uint8List.fromList(privateSeed),
        publicKey = Uint8List.fromList(publicKey);

  final String deviceId;
  final Uint8List privateSeed;
  final Uint8List publicKey;
}
