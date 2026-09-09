import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  const String aliceUserId = '11111111-1111-1111-1111-111111111111';
  const String bobUserId = '22222222-2222-2222-2222-222222222222';
  const String conversationId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const String aliceDeviceKeyId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  const String bobDeviceKeyId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

  test('private E2E message type values match the backend contract', () {
    expect(E2EPrivateMessageType.text.wireValue, MessageType.text);
    expect(E2EPrivateMessageType.image.wireValue, MessageType.image);
    expect(E2EPrivateMessageType.voice.wireValue, MessageType.voice);
    expect(E2EPrivateMessageType.video.wireValue, MessageType.video);
    expect(E2EPrivateMessageType.fromWireValue(4), E2EPrivateMessageType.voice);
    expect(
      () => E2EPrivateMessageType.fromWireValue(MessageType.system),
      throwsFormatException,
    );
  });

  test(
    'device identity is generated once and private key stays local',
    () async {
      final _MemorySecureStorage storage = _MemorySecureStorage();
      final E2ECryptoService first = _service(storage, seed: 10);
      final E2EDevicePublicIdentity firstIdentity =
          await first.loadOrCreateDeviceIdentity(userId: aliceUserId);

      final E2ECryptoService restarted = _service(storage, seed: 999);
      final E2EDevicePublicIdentity restoredIdentity =
          await restarted.loadOrCreateDeviceIdentity(userId: aliceUserId);

      expect(restoredIdentity.deviceId, firstIdentity.deviceId);
      expect(restoredIdentity.publicKey, firstIdentity.publicKey);
      expect(
        firstIdentity.publicKey,
        hasLength(E2ECryptoConstants.x25519KeyBytes),
      );

      final Map<String, Object> registration =
          firstIdentity.toRegistrationJson();
      expect(registration.keys, containsAll(<String>['deviceId', 'publicKey']));
      expect(registration.keys, isNot(contains('privateKey')));
      expect(registration.keys, isNot(contains('privateSeed')));
      expect(
        base64Decode(registration['publicKey']! as String),
        firstIdentity.publicKey,
      );
      expect(
        storage.values.keys.any((String key) => key.endsWith('.private_seed')),
        isTrue,
      );
    },
  );

  test('incomplete stored identity is rejected instead of silently rotated',
      () async {
    final _MemorySecureStorage storage = _MemorySecureStorage();
    final E2ECryptoService service = _service(storage, seed: 11);
    await service.loadOrCreateDeviceIdentity(userId: aliceUserId);

    final String publicKeyStorageKey = storage.values.keys.singleWhere(
      (String key) => key.endsWith('.public_key'),
    );
    storage.values.remove(publicKeyStorageKey);

    final E2ECryptoService restarted = _service(storage, seed: 12);
    await expectLater(
      restarted.loadOrCreateDeviceIdentity(userId: aliceUserId),
      throwsA(isA<E2EKeyStorageException>()),
    );
  });

  test('conversation key envelope opens for the intended device context',
      () async {
    final _MemorySecureStorage aliceStorage = _MemorySecureStorage();
    final _MemorySecureStorage bobStorage = _MemorySecureStorage();
    final E2ECryptoService alice = _service(aliceStorage, seed: 20);
    final E2ECryptoService bob = _service(bobStorage, seed: 21);
    final E2EDevicePublicIdentity aliceIdentity =
        await alice.loadOrCreateDeviceIdentity(userId: aliceUserId);
    final E2EDevicePublicIdentity bobIdentity =
        await bob.loadOrCreateDeviceIdentity(userId: bobUserId);
    final E2EConversationKey key = await alice.generateConversationKey();
    final E2EEnvelopeContext context = E2EEnvelopeContext(
      conversationId: conversationId,
      senderDeviceKeyId: aliceDeviceKeyId,
      recipientDeviceKeyId: bobDeviceKeyId,
      keyVersion: 1,
    );

    final E2EConversationKeyEnvelope envelope = await alice.wrapConversationKey(
      userId: aliceUserId,
      conversationKey: key,
      recipientPublicKey: bobIdentity.publicKey,
      context: context,
    );
    final E2EConversationKey opened = await bob.openConversationKeyEnvelope(
      userId: bobUserId,
      envelope: envelope,
      senderPublicKey: aliceIdentity.publicKey,
    );

    expect(opened.bytes, key.bytes);
    expect(
      envelope.payload.cipherTextWithMac,
      hasLength(E2ECryptoConstants.wrappedConversationKeyBytes),
    );
    expect(envelope.payload.nonce, hasLength(E2ECryptoConstants.nonceBytes));
    expect(envelope.toRequestJson().keys, isNot(contains('conversationKey')));
  });

  test('tampered conversation key envelope fails authentication', () async {
    final _EnvelopeFixture fixture = await _createEnvelopeFixture();
    final Uint8List tampered = fixture.envelope.payload.cipherTextWithMac;
    tampered[0] ^= 0x01;
    final E2EConversationKeyEnvelope changed = E2EConversationKeyEnvelope(
      context: fixture.context,
      payload: E2EEncryptedPayload(
        cipherTextWithMac: tampered,
        nonce: fixture.envelope.payload.nonce,
      ),
    );

    await expectLater(
      fixture.bob.openConversationKeyEnvelope(
        userId: bobUserId,
        envelope: changed,
        senderPublicKey: fixture.aliceIdentity.publicKey,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('envelope associated data binds recipient and key version', () async {
    final _EnvelopeFixture fixture = await _createEnvelopeFixture();
    final E2EEnvelopeContext changedContext = E2EEnvelopeContext(
      conversationId: conversationId,
      senderDeviceKeyId: aliceDeviceKeyId,
      recipientDeviceKeyId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      keyVersion: 2,
    );
    final E2EConversationKeyEnvelope changed = E2EConversationKeyEnvelope(
      context: changedContext,
      payload: fixture.envelope.payload,
    );

    await expectLater(
      fixture.bob.openConversationKeyEnvelope(
        userId: bobUserId,
        envelope: changed,
        senderPublicKey: fixture.aliceIdentity.publicKey,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('text encryption roundtrip preserves UTF-8 and hides plaintext',
      () async {
    final E2ECryptoService service = _service(_MemorySecureStorage(), seed: 40);
    final E2EConversationKey key = await service.generateConversationKey();
    const String marker = 'PROFESSOR-PLAINTEXT-MARKER-žćčšđ';

    final E2EEncryptedPayload payload = await service.encryptText(
      conversationId: conversationId,
      keyVersion: 1,
      conversationKey: key,
      plainText: marker,
    );
    final String decrypted = await service.decryptText(
      conversationId: conversationId,
      keyVersion: 1,
      conversationKey: key,
      payload: payload,
    );

    expect(decrypted, marker);
    expect(
      _containsContiguousBytes(
        payload.cipherTextWithMac,
        utf8.encode(marker),
      ),
      isFalse,
    );
    expect(payload.nonce, hasLength(E2ECryptoConstants.nonceBytes));
  });

  test('tampered text ciphertext and nonce fail authentication', () async {
    final E2ECryptoService service = _service(_MemorySecureStorage(), seed: 50);
    final E2EConversationKey key = await service.generateConversationKey();
    final E2EEncryptedPayload original = await service.encryptText(
      conversationId: conversationId,
      keyVersion: 1,
      conversationKey: key,
      plainText: 'Authenticated message',
    );

    final Uint8List changedCiphertext = original.cipherTextWithMac;
    changedCiphertext[1] ^= 0x80;
    await expectLater(
      service.decryptText(
        conversationId: conversationId,
        keyVersion: 1,
        conversationKey: key,
        payload: E2EEncryptedPayload(
          cipherTextWithMac: changedCiphertext,
          nonce: original.nonce,
        ),
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );

    final Uint8List changedNonce = original.nonce;
    changedNonce[0] ^= 0x01;
    await expectLater(
      service.decryptText(
        conversationId: conversationId,
        keyVersion: 1,
        conversationKey: key,
        payload: E2EEncryptedPayload(
          cipherTextWithMac: original.cipherTextWithMac,
          nonce: changedNonce,
        ),
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('associated data binds text to conversation and key version', () async {
    final E2ECryptoService service = _service(_MemorySecureStorage(), seed: 60);
    final E2EConversationKey key = await service.generateConversationKey();
    final E2EEncryptedPayload payload = await service.encryptText(
      conversationId: conversationId,
      keyVersion: 1,
      conversationKey: key,
      plainText: 'Context-bound message',
    );

    await expectLater(
      service.decryptText(
        conversationId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
        keyVersion: 1,
        conversationKey: key,
        payload: payload,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
    await expectLater(
      service.decryptText(
        conversationId: conversationId,
        keyVersion: 2,
        conversationKey: key,
        payload: payload,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('encrypted image bytes roundtrip and wrong media type is rejected',
      () async {
    final E2ECryptoService service = _service(_MemorySecureStorage(), seed: 70);
    final E2EConversationKey key = await service.generateConversationKey();
    final Uint8List imageBytes = Uint8List.fromList(<int>[
      0xff,
      0xd8,
      0xff,
      0xe0,
      ...List<int>.generate(1024, (int index) => index % 256),
      0xff,
      0xd9,
    ]);
    final E2EEncryptedPayload payload = await service.encryptMedia(
      conversationId: conversationId,
      keyVersion: 1,
      type: E2EPrivateMessageType.image,
      conversationKey: key,
      clearBytes: imageBytes,
    );

    final Uint8List decrypted = await service.decryptMedia(
      conversationId: conversationId,
      keyVersion: 1,
      type: E2EPrivateMessageType.image,
      conversationKey: key,
      payload: payload,
    );
    expect(decrypted, imageBytes);
    expect(
      payload.cipherTextWithMac.length,
      imageBytes.length + E2ECryptoConstants.authenticationTagBytes,
    );

    await expectLater(
      service.decryptMedia(
        conversationId: conversationId,
        keyVersion: 1,
        type: E2EPrivateMessageType.video,
        conversationKey: key,
        payload: payload,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('voice and video payloads use authenticated type-specific contexts',
      () async {
    final E2ECryptoService service = _service(_MemorySecureStorage(), seed: 75);
    final E2EConversationKey key = await service.generateConversationKey();
    final Uint8List clearBytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);

    for (final E2EPrivateMessageType type in <E2EPrivateMessageType>[
      E2EPrivateMessageType.voice,
      E2EPrivateMessageType.video,
    ]) {
      final E2EEncryptedPayload payload = await service.encryptMedia(
        conversationId: conversationId,
        keyVersion: 1,
        type: type,
        conversationKey: key,
        clearBytes: clearBytes,
      );
      expect(
        await service.decryptMedia(
          conversationId: conversationId,
          keyVersion: 1,
          type: type,
          conversationKey: key,
          payload: payload,
        ),
        clearBytes,
      );
    }
  });

  test('Base64 payload transport preserves ciphertext and nonce', () async {
    final E2ECryptoService service = _service(_MemorySecureStorage(), seed: 77);
    final E2EConversationKey key = await service.generateConversationKey();
    final E2EEncryptedPayload original = await service.encryptText(
      conversationId: conversationId,
      keyVersion: 1,
      conversationKey: key,
      plainText: 'Transport-safe content',
    );

    final E2EEncryptedPayload restored = E2EEncryptedPayload.fromBase64(
      cipherTextWithMac: original.cipherTextWithMacBase64,
      nonce: original.nonceBase64,
    );

    expect(restored.cipherTextWithMac, original.cipherTextWithMac);
    expect(restored.nonce, original.nonce);
  });

  test('conversation key is persisted only in secure storage namespace',
      () async {
    final _MemorySecureStorage storage = _MemorySecureStorage();
    final E2ECryptoService service = _service(storage, seed: 80);
    final E2EConversationKey key = await service.generateConversationKey();

    await service.storeConversationKey(
      userId: aliceUserId,
      conversationId: conversationId,
      keyVersion: 3,
      conversationKey: key,
    );
    final E2EConversationKey? restored = await service.readConversationKey(
      userId: aliceUserId,
      conversationId: conversationId,
      keyVersion: 3,
    );

    expect(restored, isNotNull);
    expect(restored!.bytes, key.bytes);
    expect(
      storage.values.keys.any(
        (String item) => item.contains('.conversation_key.v1.'),
      ),
      isTrue,
    );

    await service.deleteConversationKey(
      userId: aliceUserId,
      conversationId: conversationId,
      keyVersion: 3,
    );
    expect(
      await service.readConversationKey(
        userId: aliceUserId,
        conversationId: conversationId,
        keyVersion: 3,
      ),
      isNull,
    );
  });
}

bool _containsContiguousBytes(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) {
    return true;
  }
  if (needle.length > haystack.length) {
    return false;
  }

  for (var offset = 0; offset <= haystack.length - needle.length; offset++) {
    var matches = true;
    for (var index = 0; index < needle.length; index++) {
      if (haystack[offset + index] != needle[index]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return true;
    }
  }
  return false;
}

Future<_EnvelopeFixture> _createEnvelopeFixture() async {
  const String aliceUserId = '11111111-1111-1111-1111-111111111111';
  const String bobUserId = '22222222-2222-2222-2222-222222222222';
  const String conversationId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const String aliceDeviceKeyId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  const String bobDeviceKeyId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

  final E2ECryptoService alice = _service(_MemorySecureStorage(), seed: 30);
  final E2ECryptoService bob = _service(_MemorySecureStorage(), seed: 31);
  final E2EDevicePublicIdentity aliceIdentity =
      await alice.loadOrCreateDeviceIdentity(userId: aliceUserId);
  final E2EDevicePublicIdentity bobIdentity =
      await bob.loadOrCreateDeviceIdentity(userId: bobUserId);
  final E2EEnvelopeContext context = E2EEnvelopeContext(
    conversationId: conversationId,
    senderDeviceKeyId: aliceDeviceKeyId,
    recipientDeviceKeyId: bobDeviceKeyId,
    keyVersion: 1,
  );
  final E2EConversationKeyEnvelope envelope = await alice.wrapConversationKey(
    userId: aliceUserId,
    conversationKey: await alice.generateConversationKey(),
    recipientPublicKey: bobIdentity.publicKey,
    context: context,
  );

  return _EnvelopeFixture(
    bob: bob,
    aliceIdentity: aliceIdentity,
    context: context,
    envelope: envelope,
  );
}

E2ECryptoService _service(_MemorySecureStorage storage, {required int seed}) =>
    E2ECryptoService(
      secureStorage: storage,
      random: SecureRandom.forTesting(seed: seed),
    );

final class _EnvelopeFixture {
  const _EnvelopeFixture({
    required this.bob,
    required this.aliceIdentity,
    required this.context,
    required this.envelope,
  });

  final E2ECryptoService bob;
  final E2EDevicePublicIdentity aliceIdentity;
  final E2EEnvelopeContext context;
  final E2EConversationKeyEnvelope envelope;
}

final class _MemorySecureStorage implements E2ESecureStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
