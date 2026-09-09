import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  const String aliceUserId = '11111111-1111-1111-1111-111111111111';
  const String bobUserId = '22222222-2222-2222-2222-222222222222';
  const String conversationId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  test('first sender creates envelopes and sends ciphertext-only text',
      () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    const String marker = 'STEP-2B-PLAINTEXT-MARKER-žćčšđ';

    final ChatMessage local = await fixture.alice.sendEncryptedText(
      userId: aliceUserId,
      conversation: fixture.conversation,
      plainText: marker,
    );

    expect(fixture.server.envelopes, hasLength(2));
    expect(fixture.server.messages, hasLength(1));
    final ChatMessage stored = fixture.server.messages.single;
    expect(stored.content, isNull);
    expect(stored.encryptionVersion, ChatEncryptionVersion.clientE2E);
    expect(stored.keyVersion, E2EChatCoordinator.currentKeyVersion);
    expect(stored.encryptedContent, isNotNull);
    expect(
      _containsContiguousBytes(stored.encryptedContent!, utf8.encode(marker)),
      isFalse,
    );
    expect(local.decryptedContent, marker);
  });

  test('recipient recovers envelope and decrypts received text', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedText(
      userId: aliceUserId,
      conversation: fixture.conversation,
      plainText: 'Message only Bob can open',
    );

    final ChatMessage decrypted = await fixture.bob.decryptTextMessage(
      userId: bobUserId,
      message: fixture.server.messages.single,
    );

    expect(decrypted.decryptedContent, 'Message only Bob can open');
    expect(decrypted.decryptionError, isNull);
    expect(
      fixture.bobStorage.values.keys.any(
        (String key) => key.contains('.conversation_key.v1.'),
      ),
      isTrue,
    );
  });

  test('recipient can reply with the recovered conversation key', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedText(
      userId: aliceUserId,
      conversation: fixture.conversation,
      plainText: 'First encrypted message',
    );

    final ChatMessage bobReply = await fixture.bob.sendEncryptedText(
      userId: bobUserId,
      conversation: fixture.conversationFor(bobUserId),
      plainText: 'Encrypted reply',
    );
    final ChatMessage openedByAlice = await fixture.alice.decryptTextMessage(
      userId: aliceUserId,
      message: fixture.server.messages.last,
    );

    expect(bobReply.decryptedContent, 'Encrypted reply');
    expect(openedByAlice.decryptedContent, 'Encrypted reply');
    expect(fixture.server.messages.last.content, isNull);
  });

  test('tampered server ciphertext is never displayed as plaintext', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedText(
      userId: aliceUserId,
      conversation: fixture.conversation,
      plainText: 'Authenticated content',
    );
    final ChatMessage original = fixture.server.messages.single;
    final List<int> changed = List<int>.of(original.encryptedContent!);
    changed[0] ^= 0x01;
    final ChatMessage tampered = ChatMessage(
      id: original.id,
      conversationId: original.conversationId,
      senderUserId: original.senderUserId,
      senderDisplayName: original.senderDisplayName,
      type: original.type,
      sentAtUtc: original.sentAtUtc,
      encryptionVersion: original.encryptionVersion,
      encryptedContent: changed,
      contentNonce: original.contentNonce,
      keyVersion: original.keyVersion,
    );

    final ChatMessage result = await fixture.bob.decryptTextMessage(
      userId: bobUserId,
      message: tampered,
    );

    expect(result.decryptedContent, isNull);
    expect(result.decryptionError, contains('authentication failed'));
    expect(result.visibleContent, isNull);
  });

  test('encrypted text with attachment metadata is rejected locally', () async {
    final _Fixture fixture = _Fixture();
    final ChatMessage malformed = ChatMessage(
      id: 'malformed-message',
      conversationId: conversationId,
      senderUserId: aliceUserId,
      senderDisplayName: 'Alice',
      type: MessageType.text,
      sentAtUtc: DateTime.utc(2026, 9, 9),
      encryptionVersion: ChatEncryptionVersion.clientE2E,
      encryptedContent: List<int>.filled(32, 4),
      contentNonce: List<int>.filled(12, 5),
      keyVersion: 1,
      attachmentId: 'unexpected-attachment',
    );

    final ChatMessage result = await fixture.bob.decryptTextMessage(
      userId: bobUserId,
      message: malformed,
    );

    expect(result.decryptedContent, isNull);
    expect(result.decryptionError, contains('invalid plaintext or attachment'));
    expect(fixture.server.devicesByUser, isEmpty);
  });

  test('missing participant device blocks E2E send without fallback', () async {
    final _Fixture fixture = _Fixture();

    await expectLater(
      fixture.alice.sendEncryptedText(
        userId: aliceUserId,
        conversation: fixture.conversation,
        plainText: 'Must not fall back to plaintext',
      ),
      throwsA(
        isA<E2EChatSetupException>().having(
          (E2EChatSetupException error) => error.message,
          'message',
          contains('Bob'),
        ),
      ),
    );
    expect(fixture.server.messages, isEmpty);
    expect(fixture.server.envelopes, isEmpty);
  });

  test('conversation state blocks sending before crypto or network work',
      () async {
    final _Fixture fixture = _Fixture();
    const ConversationItem blockedConversation = ConversationItem(
      id: conversationId,
      displayTitle: 'Alice and Bob',
      isGroup: false,
      canSendMessages: false,
      unreadCount: 0,
      participants: <ConversationParticipant>[
        ConversationParticipant(
          userId: aliceUserId,
          displayName: 'Alice',
          isCurrentUser: true,
        ),
        ConversationParticipant(
          userId: bobUserId,
          displayName: 'Bob',
          isCurrentUser: false,
        ),
      ],
    );

    await expectLater(
      fixture.alice.sendEncryptedText(
        userId: aliceUserId,
        conversation: blockedConversation,
        plainText: 'Must remain unsent',
      ),
      throwsA(
        isA<E2EChatSetupException>().having(
          (E2EChatSetupException error) => error.message,
          'message',
          contains('disabled'),
        ),
      ),
    );
    expect(fixture.server.devicesByUser, isEmpty);
    expect(fixture.server.envelopes, isEmpty);
    expect(fixture.server.messages, isEmpty);
  });

  test('TOFU trust store rejects a changed key for the same peer device',
      () async {
    final _MemorySecureStorage storage = _MemorySecureStorage();
    final SecureE2EPeerKeyTrustStore trustStore =
        SecureE2EPeerKeyTrustStore(secureStorage: storage);
    final E2EDeviceKeyRecord original = _deviceRecord(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      userId: bobUserId,
      deviceId: 'bob-phone',
      publicKey: List<int>.filled(E2ECryptoConstants.x25519KeyBytes, 1),
    );
    final E2EDeviceKeyRecord changed = _deviceRecord(
      id: original.id,
      userId: bobUserId,
      deviceId: original.deviceId,
      publicKey: List<int>.filled(E2ECryptoConstants.x25519KeyBytes, 2),
    );

    await trustStore.verifyOrTrust(
      currentUserId: aliceUserId,
      peerDevice: original,
    );
    await expectLater(
      trustStore.verifyOrTrust(
        currentUserId: aliceUserId,
        peerDevice: changed,
      ),
      throwsA(isA<E2EKeyTrustException>()),
    );
  });

  test('TOFU trust store rejects a corrupted empty peer-key pin', () async {
    final _MemorySecureStorage storage = _MemorySecureStorage();
    final SecureE2EPeerKeyTrustStore trustStore =
        SecureE2EPeerKeyTrustStore(secureStorage: storage);
    final E2EDeviceKeyRecord peer = _deviceRecord(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      userId: bobUserId,
      deviceId: 'bob-phone',
      publicKey: List<int>.filled(E2ECryptoConstants.x25519KeyBytes, 1),
    );

    await trustStore.verifyOrTrust(
      currentUserId: aliceUserId,
      peerDevice: peer,
    );
    storage.values[storage.values.keys.single] = '';

    await expectLater(
      trustStore.verifyOrTrust(
        currentUserId: aliceUserId,
        peerDevice: peer,
      ),
      throwsA(
        isA<E2EKeyTrustException>().having(
          (E2EKeyTrustException error) => error.message,
          'message',
          contains('corrupted'),
        ),
      ),
    );
  });

  test('legacy plaintext remains readable and is marked as legacy', () async {
    final _Fixture fixture = _Fixture();
    final ChatMessage legacy = ChatMessage(
      id: 'legacy-message',
      conversationId: conversationId,
      senderUserId: aliceUserId,
      senderDisplayName: 'Alice',
      type: MessageType.text,
      content: 'Old readable message',
      sentAtUtc: DateTime.utc(2026, 9, 9),
      encryptionVersion: ChatEncryptionVersion.legacyPlaintext,
    );

    final ChatMessage result = await fixture.bob.decryptTextMessage(
      userId: bobUserId,
      message: legacy,
    );

    expect(result, same(legacy));
    expect(result.visibleContent, 'Old readable message');
    expect(result.isLegacy, isTrue);
  });

  test('invalid server response cannot reintroduce plaintext content',
      () async {
    final _Fixture fixture = _Fixture(invalidPlaintextResponse: true);
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);

    await expectLater(
      fixture.alice.sendEncryptedText(
        userId: aliceUserId,
        conversation: fixture.conversation,
        plainText: 'Client plaintext',
      ),
      throwsA(isA<E2EChatSetupException>()),
    );
  });

  test('changed ciphertext in the send response is rejected', () async {
    final _Fixture fixture = _Fixture(mutateEncryptedResponse: true);
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);

    await expectLater(
      fixture.alice.sendEncryptedText(
        userId: aliceUserId,
        conversation: fixture.conversation,
        plainText: 'Response integrity marker',
      ),
      throwsA(isA<E2EChatSetupException>()),
    );
    expect(fixture.server.messages, hasLength(1));
    expect(fixture.server.messages.single.content, isNull);
  });

  test('a device key for a non-participant stops envelope creation', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    fixture.server.devicesByUser['outsider-user'] = _deviceRecord(
      id: '33333333-cccc-cccc-cccc-cccccccccccc',
      userId: '33333333-3333-3333-3333-333333333333',
      deviceId: 'outsider-phone',
      publicKey: List<int>.filled(E2ECryptoConstants.x25519KeyBytes, 3),
    );

    await expectLater(
      fixture.alice.sendEncryptedText(
        userId: aliceUserId,
        conversation: fixture.conversation,
        plainText: 'Do not wrap for outsiders',
      ),
      throwsA(
        isA<E2EChatSetupException>().having(
          (E2EChatSetupException error) => error.message,
          'message',
          contains('non-participant'),
        ),
      ),
    );
    expect(fixture.server.envelopes, isEmpty);
    expect(fixture.server.messages, isEmpty);
  });

  test('image validation accepts only supported magic-byte signatures', () {
    expect(E2EImageValidator.validate(_pngBytes('png')), E2EImageFormat.png);
    expect(
      E2EImageValidator.validate(
        const <int>[0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46],
      ),
      E2EImageFormat.jpeg,
    );
    expect(
      E2EImageValidator.validate(
        const <int>[
          0x52,
          0x49,
          0x46,
          0x46,
          0x04,
          0x00,
          0x00,
          0x00,
          0x57,
          0x45,
          0x42,
          0x50,
        ],
      ),
      E2EImageFormat.webp,
    );
    expect(
      () => E2EImageValidator.validate(utf8.encode('renamed-not-image.jpg')),
      throwsA(isA<E2EImageValidationException>()),
    );
  });

  test('encrypted image roundtrip keeps clear bytes off the server', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    final Uint8List clearImage = _pngBytes(
      'STEP-3-IMAGE-PLAINTEXT-MARKER-zcCsd',
    );

    final ChatMessage sent = await fixture.alice.sendEncryptedImage(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearImageBytes: clearImage,
    );

    expect(sent.type, MessageType.image);
    expect(sent.content, isNull);
    expect(sent.encryptedContent, isNull);
    expect(sent.contentNonce, isNull);
    expect(
        sent.attachmentMimeType, E2ECryptoConstants.encryptedMediaContentType);
    expect(sent.attachmentDurationMilliseconds, isNull);
    final List<int> storedCipherText =
        fixture.server.attachments[sent.attachmentUrl]!;
    expect(storedCipherText.length, clearImage.length + 16);
    expect(_containsContiguousBytes(storedCipherText, clearImage), isFalse);
    expect(
      _containsContiguousBytes(
        storedCipherText,
        utf8.encode('STEP-3-IMAGE-PLAINTEXT-MARKER'),
      ),
      isFalse,
    );

    final Uint8List opened = await fixture.bob.downloadAndDecryptImage(
      userId: bobUserId,
      message: fixture.server.messages.single,
    );
    expect(opened, orderedEquals(clearImage));
  });

  test('tampered encrypted image bytes fail authentication', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedImage(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearImageBytes: _pngBytes('authenticated image'),
    );
    final ChatMessage stored = fixture.server.messages.single;
    fixture.server.attachments[stored.attachmentUrl]![0] ^= 0x01;

    await expectLater(
      fixture.bob.downloadAndDecryptImage(
        userId: bobUserId,
        message: stored,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('changed encrypted image nonce fails authentication', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedImage(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearImageBytes: _pngBytes('nonce protected image'),
    );
    final ChatMessage stored = fixture.server.messages.single;
    final List<int> changedNonce = List<int>.of(stored.attachmentNonce!);
    changedNonce[0] ^= 0x01;
    final ChatMessage changedMetadata = _copyWithAttachmentNonce(
      stored,
      changedNonce,
    );

    await expectLater(
      fixture.bob.downloadAndDecryptImage(
        userId: bobUserId,
        message: changedMetadata,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('invalid local image is rejected before crypto or network work',
      () async {
    final _Fixture fixture = _Fixture();

    await expectLater(
      fixture.alice.sendEncryptedImage(
        userId: aliceUserId,
        conversation: fixture.conversation,
        clearImageBytes: utf8.encode('not an image'),
      ),
      throwsA(isA<E2EImageValidationException>()),
    );
    expect(fixture.server.devicesByUser, isEmpty);
    expect(fixture.server.envelopes, isEmpty);
    expect(fixture.server.messages, isEmpty);
    expect(fixture.server.attachments, isEmpty);
  });

  test('invalid encrypted image send response is rejected locally', () async {
    final _Fixture fixture = _Fixture(invalidMediaResponse: true);
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);

    await expectLater(
      fixture.alice.sendEncryptedImage(
        userId: aliceUserId,
        conversation: fixture.conversation,
        clearImageBytes: _pngBytes('response validation'),
      ),
      throwsA(isA<E2EChatSetupException>()),
    );
    expect(fixture.server.messages, hasLength(1));
    expect(fixture.server.messages.single.content, isNull);
  });

  test('encrypted image size mismatch is rejected before decryption', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedImage(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearImageBytes: _pngBytes('size metadata'),
    );
    final ChatMessage stored = fixture.server.messages.single;
    fixture.server.attachments[stored.attachmentUrl]!.removeLast();

    await expectLater(
      fixture.bob.downloadAndDecryptImage(
        userId: bobUserId,
        message: stored,
      ),
      throwsA(
        isA<E2EChatSetupException>().having(
          (E2EChatSetupException error) => error.message,
          'message',
          contains('size'),
        ),
      ),
    );
  });

  test('absolute encrypted attachment URL is rejected before download',
      () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedImage(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearImageBytes: _pngBytes('relative URL only'),
    );
    final ChatMessage stored = fixture.server.messages.single;
    final ChatMessage maliciousUrl = _copyWithAttachmentUrl(
      stored,
      'https://attacker.invalid${stored.attachmentUrl}',
    );

    await expectLater(
      fixture.bob.downloadAndDecryptImage(
        userId: bobUserId,
        message: maliciousUrl,
      ),
      throwsA(
        isA<E2EChatSetupException>().having(
          (E2EChatSetupException error) => error.message,
          'message',
          contains('metadata'),
        ),
      ),
    );
  });

  test('incoming E2E image with plaintext metadata is rejected before download',
      () async {
    final _Fixture fixture = _Fixture();
    final ChatMessage malformed = ChatMessage(
      id: 'malformed-image',
      conversationId: conversationId,
      senderUserId: aliceUserId,
      senderDisplayName: 'Alice',
      type: MessageType.image,
      content: 'server plaintext',
      sentAtUtc: DateTime.utc(2026, 9, 9),
      encryptionVersion: ChatEncryptionVersion.clientE2E,
      keyVersion: 1,
      attachmentId: '00000000-0000-0000-0000-000000000001',
      attachmentUrl:
          '/api/media/message-attachments/00000000-0000-0000-0000-000000000001',
      attachmentMimeType: E2ECryptoConstants.encryptedMediaContentType,
      attachmentNonce: List<int>.filled(12, 1),
      attachmentEncryptionVersion: ChatEncryptionVersion.clientE2E,
      attachmentKeyVersion: 1,
      attachmentSizeBytes: 32,
    );

    await expectLater(
      fixture.bob.downloadAndDecryptImage(
        userId: bobUserId,
        message: malformed,
      ),
      throwsA(
        isA<E2EChatSetupException>().having(
          (E2EChatSetupException error) => error.message,
          'message',
          contains('plaintext'),
        ),
      ),
    );
    expect(fixture.server.devicesByUser, isEmpty);
  });

  test('voice validation accepts M4A and AAC signatures with valid duration',
      () {
    expect(
      E2EVoiceValidator.validate(
        bytes: _m4aBytes('m4a voice'),
        durationMilliseconds: 1200,
      ),
      E2EVoiceFormat.m4a,
    );
    expect(
      E2EVoiceValidator.validate(
        bytes: _aacBytes('aac voice'),
        durationMilliseconds: 1200,
      ),
      E2EVoiceFormat.aacAdts,
    );
    expect(
      () => E2EVoiceValidator.validate(
        bytes: utf8.encode('renamed-not-audio.m4a'),
        durationMilliseconds: 1200,
      ),
      throwsA(isA<E2EVoiceValidationException>()),
    );
    expect(
      () => E2EVoiceValidator.validate(
        bytes: _m4aBytes('too short'),
        durationMilliseconds: 100,
      ),
      throwsA(isA<E2EVoiceValidationException>()),
    );
  });

  test('voice validation rejects excessive duration and clear byte size', () {
    expect(
      () => E2EVoiceValidator.validate(
        bytes: _m4aBytes('too long'),
        durationMilliseconds: E2EVoiceValidator.maximumDurationMilliseconds + 1,
      ),
      throwsA(isA<E2EVoiceValidationException>()),
    );

    final Uint8List oversized = Uint8List(
      E2ECryptoConstants.maximumPlainMediaBytes + 1,
    )
      ..[4] = 0x66
      ..[5] = 0x74
      ..[6] = 0x79
      ..[7] = 0x70;
    expect(
      () => E2EVoiceValidator.validate(
        bytes: oversized,
        durationMilliseconds: 1200,
      ),
      throwsA(isA<E2EVoiceValidationException>()),
    );
  });

  test('encrypted voice roundtrip authenticates duration and hides clear bytes',
      () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    final Uint8List clearVoice = _m4aBytes(
      'STEP-4-VOICE-PLAINTEXT-MARKER-zcCsd',
    );
    final List<(int, int)> progress = <(int, int)>[];

    final ChatMessage sent = await fixture.alice.sendEncryptedVoice(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearVoiceBytes: clearVoice,
      durationMilliseconds: 1850,
      onUploadProgress: (int transferred, int total) {
        progress.add((transferred, total));
      },
    );

    expect(sent.type, MessageType.voice);
    expect(sent.content, isNull);
    expect(sent.encryptedContent, isNull);
    expect(sent.contentNonce, isNull);
    expect(
      sent.attachmentMimeType,
      E2ECryptoConstants.encryptedMediaContentType,
    );
    expect(sent.attachmentDurationMilliseconds, 1850);
    final List<int> storedCipherText =
        fixture.server.attachments[sent.attachmentUrl]!;
    expect(
      storedCipherText.length,
      clearVoice.length + E2ECryptoConstants.authenticationTagBytes,
    );
    expect(_containsContiguousBytes(storedCipherText, clearVoice), isFalse);
    expect(
      _containsContiguousBytes(
        storedCipherText,
        utf8.encode('STEP-4-VOICE-PLAINTEXT-MARKER'),
      ),
      isFalse,
    );
    expect(progress, isNotEmpty);
    expect(progress.last.$1, storedCipherText.length);
    expect(progress.last.$2, storedCipherText.length);

    final Uint8List opened = await fixture.bob.downloadAndDecryptVoice(
      userId: bobUserId,
      message: fixture.server.messages.single,
    );
    expect(opened, orderedEquals(clearVoice));
  });

  test('tampered encrypted voice bytes fail authentication', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedVoice(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearVoiceBytes: _m4aBytes('authenticated voice'),
      durationMilliseconds: 1500,
    );
    final ChatMessage stored = fixture.server.messages.single;
    fixture.server.attachments[stored.attachmentUrl]![0] ^= 0x01;

    await expectLater(
      fixture.bob.downloadAndDecryptVoice(
        userId: bobUserId,
        message: stored,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('changed encrypted voice duration fails authentication', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedVoice(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearVoiceBytes: _m4aBytes('duration protected voice'),
      durationMilliseconds: 1600,
    );
    final ChatMessage stored = fixture.server.messages.single;
    final ChatMessage changedDuration = _copyWithAttachmentDuration(
      stored,
      1601,
    );

    await expectLater(
      fixture.bob.downloadAndDecryptVoice(
        userId: bobUserId,
        message: changedDuration,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('invalid local voice is rejected before crypto or network work',
      () async {
    final _Fixture fixture = _Fixture();

    await expectLater(
      fixture.alice.sendEncryptedVoice(
        userId: aliceUserId,
        conversation: fixture.conversation,
        clearVoiceBytes: utf8.encode('not an AAC or M4A recording'),
        durationMilliseconds: 1500,
      ),
      throwsA(isA<E2EVoiceValidationException>()),
    );
    expect(fixture.server.devicesByUser, isEmpty);
    expect(fixture.server.envelopes, isEmpty);
    expect(fixture.server.messages, isEmpty);
    expect(fixture.server.attachments, isEmpty);
  });

  test('incoming encrypted voice without duration is rejected before download',
      () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedVoice(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearVoiceBytes: _m4aBytes('duration required'),
      durationMilliseconds: 1700,
    );
    final ChatMessage malformed = _copyWithAttachmentDuration(
      fixture.server.messages.single,
      null,
    );

    await expectLater(
      fixture.bob.downloadAndDecryptVoice(
        userId: bobUserId,
        message: malformed,
      ),
      throwsA(
        isA<E2EChatSetupException>().having(
          (E2EChatSetupException error) => error.message,
          'message',
          contains('metadata'),
        ),
      ),
    );
  });

  test('changed voice duration in send response is rejected locally', () async {
    final _Fixture fixture = _Fixture(invalidVoiceDurationResponse: true);
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);

    await expectLater(
      fixture.alice.sendEncryptedVoice(
        userId: aliceUserId,
        conversation: fixture.conversation,
        clearVoiceBytes: _m4aBytes('response duration validation'),
        durationMilliseconds: 1900,
      ),
      throwsA(isA<E2EChatSetupException>()),
    );
    expect(fixture.server.messages, hasLength(1));
    expect(fixture.server.messages.single.content, isNull);
  });

  test('video validation accepts MP4 MOV and WebM magic-byte signatures', () {
    expect(
      E2EVideoValidator.validate(
        bytes: _mp4Bytes('mp4 video'),
        durationMilliseconds: 1800,
      ),
      E2EVideoFormat.mp4,
    );
    expect(
      E2EVideoValidator.validate(
        bytes: _movBytes('quicktime video'),
        durationMilliseconds: 1800,
      ),
      E2EVideoFormat.quickTime,
    );
    expect(
      E2EVideoValidator.validate(
        bytes: _webmBytes('webm video'),
        durationMilliseconds: 1800,
      ),
      E2EVideoFormat.webm,
    );
    expect(
      () => E2EVideoValidator.validate(
        bytes: utf8.encode('renamed-not-video.mp4'),
        durationMilliseconds: 1800,
      ),
      throwsA(isA<E2EVideoValidationException>()),
    );
  });

  test('video validation rejects invalid duration and clear byte size', () {
    expect(
      () => E2EVideoValidator.validate(
        bytes: _mp4Bytes('too short'),
        durationMilliseconds: 100,
      ),
      throwsA(isA<E2EVideoValidationException>()),
    );
    expect(
      () => E2EVideoValidator.validate(
        bytes: _mp4Bytes('too long'),
        durationMilliseconds: E2EVideoValidator.maximumDurationMilliseconds + 1,
      ),
      throwsA(isA<E2EVideoValidationException>()),
    );

    final Uint8List oversized = Uint8List(
      E2ECryptoConstants.maximumPlainMediaBytes + 1,
    )
      ..[4] = 0x66
      ..[5] = 0x74
      ..[6] = 0x79
      ..[7] = 0x70
      ..[8] = 0x69
      ..[9] = 0x73
      ..[10] = 0x6f
      ..[11] = 0x6d;
    expect(
      () => E2EVideoValidator.validate(
        bytes: oversized,
        durationMilliseconds: 1800,
      ),
      throwsA(isA<E2EVideoValidationException>()),
    );
  });

  test('encrypted video roundtrip authenticates duration and hides clear bytes',
      () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    final Uint8List clearVideo = _mp4Bytes(
      'STEP-5-VIDEO-PLAINTEXT-MARKER-zcCsd',
    );
    final List<(int, int)> progress = <(int, int)>[];

    final ChatMessage sent = await fixture.alice.sendEncryptedVideo(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearVideoBytes: clearVideo,
      durationMilliseconds: 4200,
      onUploadProgress: (int transferred, int total) {
        progress.add((transferred, total));
      },
    );

    expect(sent.type, MessageType.video);
    expect(sent.content, isNull);
    expect(sent.encryptedContent, isNull);
    expect(sent.contentNonce, isNull);
    expect(
      sent.attachmentMimeType,
      E2ECryptoConstants.encryptedMediaContentType,
    );
    expect(sent.attachmentDurationMilliseconds, 4200);
    final List<int> storedCipherText =
        fixture.server.attachments[sent.attachmentUrl]!;
    expect(
      storedCipherText.length,
      clearVideo.length + E2ECryptoConstants.authenticationTagBytes,
    );
    expect(_containsContiguousBytes(storedCipherText, clearVideo), isFalse);
    expect(
      _containsContiguousBytes(
        storedCipherText,
        utf8.encode('STEP-5-VIDEO-PLAINTEXT-MARKER'),
      ),
      isFalse,
    );
    expect(progress, isNotEmpty);
    expect(progress.last.$1, storedCipherText.length);
    expect(progress.last.$2, storedCipherText.length);

    final Uint8List opened = await fixture.bob.downloadAndDecryptVideo(
      userId: bobUserId,
      message: fixture.server.messages.single,
    );
    expect(opened, orderedEquals(clearVideo));
  });

  test('tampered encrypted video bytes fail authentication', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedVideo(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearVideoBytes: _mp4Bytes('authenticated video'),
      durationMilliseconds: 3100,
    );
    final ChatMessage stored = fixture.server.messages.single;
    fixture.server.attachments[stored.attachmentUrl]![0] ^= 0x01;

    await expectLater(
      fixture.bob.downloadAndDecryptVideo(
        userId: bobUserId,
        message: stored,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('changed encrypted video duration fails authentication', () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedVideo(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearVideoBytes: _mp4Bytes('duration protected video'),
      durationMilliseconds: 3200,
    );
    final ChatMessage stored = fixture.server.messages.single;
    final ChatMessage changedDuration = _copyWithAttachmentDuration(
      stored,
      3201,
    );

    await expectLater(
      fixture.bob.downloadAndDecryptVideo(
        userId: bobUserId,
        message: changedDuration,
      ),
      throwsA(isA<E2EAuthenticationException>()),
    );
  });

  test('invalid local video is rejected before crypto or network work',
      () async {
    final _Fixture fixture = _Fixture();

    await expectLater(
      fixture.alice.sendEncryptedVideo(
        userId: aliceUserId,
        conversation: fixture.conversation,
        clearVideoBytes: utf8.encode('not an MP4 MOV or WebM video'),
        durationMilliseconds: 1800,
      ),
      throwsA(isA<E2EVideoValidationException>()),
    );
    expect(fixture.server.devicesByUser, isEmpty);
    expect(fixture.server.envelopes, isEmpty);
    expect(fixture.server.messages, isEmpty);
    expect(fixture.server.attachments, isEmpty);
  });

  test('incoming encrypted video without duration is rejected before download',
      () async {
    final _Fixture fixture = _Fixture();
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);
    await fixture.alice.sendEncryptedVideo(
      userId: aliceUserId,
      conversation: fixture.conversation,
      clearVideoBytes: _mp4Bytes('duration required'),
      durationMilliseconds: 3300,
    );
    final ChatMessage malformed = _copyWithAttachmentDuration(
      fixture.server.messages.single,
      null,
    );

    await expectLater(
      fixture.bob.downloadAndDecryptVideo(
        userId: bobUserId,
        message: malformed,
      ),
      throwsA(
        isA<E2EChatSetupException>().having(
          (E2EChatSetupException error) => error.message,
          'message',
          contains('metadata'),
        ),
      ),
    );
  });

  test('changed video duration in send response is rejected locally', () async {
    final _Fixture fixture = _Fixture(invalidVideoDurationResponse: true);
    await fixture.bob.ensureDeviceRegistered(userId: bobUserId);

    await expectLater(
      fixture.alice.sendEncryptedVideo(
        userId: aliceUserId,
        conversation: fixture.conversation,
        clearVideoBytes: _mp4Bytes('response duration validation'),
        durationMilliseconds: 3500,
      ),
      throwsA(isA<E2EChatSetupException>()),
    );
    expect(fixture.server.messages, hasLength(1));
    expect(fixture.server.messages.single.content, isNull);
  });
}

final class _Fixture {
  _Fixture({
    bool invalidPlaintextResponse = false,
    bool mutateEncryptedResponse = false,
    bool invalidMediaResponse = false,
    bool invalidVoiceDurationResponse = false,
    bool invalidVideoDurationResponse = false,
  })  : server = _FakeE2EServer(
          invalidPlaintextResponse: invalidPlaintextResponse,
          mutateEncryptedResponse: mutateEncryptedResponse,
          invalidMediaResponse: invalidMediaResponse,
          invalidVoiceDurationResponse: invalidVoiceDurationResponse,
          invalidVideoDurationResponse: invalidVideoDurationResponse,
        ),
        aliceStorage = _MemorySecureStorage(),
        bobStorage = _MemorySecureStorage() {
    alice = _coordinator(
      transport: _FakeE2ETransport(server, _aliceUserId),
      storage: aliceStorage,
      seed: 101,
    );
    bob = _coordinator(
      transport: _FakeE2ETransport(server, _bobUserId),
      storage: bobStorage,
      seed: 202,
    );
  }

  static const String _aliceUserId = '11111111-1111-1111-1111-111111111111';
  static const String _bobUserId = '22222222-2222-2222-2222-222222222222';
  static const String _conversationId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  final _FakeE2EServer server;
  final _MemorySecureStorage aliceStorage;
  final _MemorySecureStorage bobStorage;
  late final E2EChatCoordinator alice;
  late final E2EChatCoordinator bob;

  ConversationItem get conversation => conversationFor(_aliceUserId);

  ConversationItem conversationFor(String currentUserId) => ConversationItem(
        id: _conversationId,
        displayTitle: 'Alice and Bob',
        isGroup: false,
        canSendMessages: true,
        unreadCount: 0,
        participants: <ConversationParticipant>[
          ConversationParticipant(
            userId: _aliceUserId,
            displayName: 'Alice',
            isCurrentUser: currentUserId == _aliceUserId,
          ),
          ConversationParticipant(
            userId: _bobUserId,
            displayName: 'Bob',
            isCurrentUser: currentUserId == _bobUserId,
          ),
        ],
      );
}

E2EChatCoordinator _coordinator({
  required E2EChatTransport transport,
  required _MemorySecureStorage storage,
  required int seed,
}) =>
    E2EChatCoordinator(
      transport: transport,
      cryptoService: E2ECryptoService(
        secureStorage: storage,
        random: SecureRandom.forTesting(seed: seed),
      ),
      keyTrustStore: SecureE2EPeerKeyTrustStore(secureStorage: storage),
      bootstrapPollAttempts: 2,
      bootstrapPollDelay: Duration.zero,
      delay: (_) async {},
    );

final class _FakeE2EServer {
  _FakeE2EServer({
    required this.invalidPlaintextResponse,
    required this.mutateEncryptedResponse,
    required this.invalidMediaResponse,
    required this.invalidVoiceDurationResponse,
    required this.invalidVideoDurationResponse,
  });

  static const String conversationId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  static const String aliceUserId = '11111111-1111-1111-1111-111111111111';

  final bool invalidPlaintextResponse;
  final bool mutateEncryptedResponse;
  final bool invalidMediaResponse;
  final bool invalidVoiceDurationResponse;
  final bool invalidVideoDurationResponse;
  final Map<String, E2EDeviceKeyRecord> devicesByUser =
      <String, E2EDeviceKeyRecord>{};
  final Map<String, E2EConversationKeyEnvelopeRecord> envelopes =
      <String, E2EConversationKeyEnvelopeRecord>{};
  final List<ChatMessage> messages = <ChatMessage>[];
  final Map<String, List<int>> attachments = <String, List<int>>{};

  E2EDeviceKeyRecord register(
    String userId,
    E2EDevicePublicIdentity identity,
  ) {
    final E2EDeviceKeyRecord? existing = devicesByUser[userId];
    if (existing != null) {
      if (!existing.matchesIdentity(identity)) {
        throw const ApiException(
          message: 'Device key conflict.',
          statusCode: 409,
        );
      }
      return existing;
    }

    final String id = userId == aliceUserId
        ? '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        : '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    final E2EDeviceKeyRecord record = _deviceRecord(
      id: id,
      userId: userId,
      deviceId: identity.deviceId,
      publicKey: identity.publicKey,
    );
    devicesByUser[userId] = record;
    return record;
  }

  List<E2EDeviceKeyRecord> get deviceKeys =>
      List<E2EDeviceKeyRecord>.unmodifiable(devicesByUser.values);

  String envelopeKey({
    required String recipientDeviceKeyId,
    required int keyVersion,
  }) =>
      '$conversationId|$recipientDeviceKeyId|$keyVersion';
}

final class _FakeE2ETransport implements E2EChatTransport {
  const _FakeE2ETransport(this.server, this.userId);

  final _FakeE2EServer server;
  final String userId;

  @override
  Future<E2EDeviceKeyRecord> registerDeviceKey(
    E2EDevicePublicIdentity identity,
  ) async =>
      server.register(userId, identity);

  @override
  Future<List<E2EDeviceKeyRecord>> getAllConversationDeviceKeys(
    String conversationId,
  ) async {
    expect(conversationId, _FakeE2EServer.conversationId);
    return server.deviceKeys;
  }

  @override
  Future<E2EConversationKeyEnvelopeRecord?> tryGetConversationKeyEnvelope({
    required String conversationId,
    required String recipientDeviceKeyId,
    required int keyVersion,
  }) async {
    final E2EDeviceKeyRecord owner = server.deviceKeys.firstWhere(
      (E2EDeviceKeyRecord item) => item.id == recipientDeviceKeyId,
    );
    if (owner.userId != userId) {
      throw const ApiException(message: 'Not found.', statusCode: 404);
    }
    return server.envelopes[server.envelopeKey(
      recipientDeviceKeyId: recipientDeviceKeyId,
      keyVersion: keyVersion,
    )];
  }

  @override
  Future<E2EConversationKeyEnvelopeRecord> putConversationKeyEnvelope({
    required String conversationId,
    required E2EConversationKeyEnvelope envelope,
  }) async {
    final E2EConversationKeyEnvelopeRecord record =
        E2EConversationKeyEnvelopeRecord(
      id: 'envelope-${server.envelopes.length + 1}',
      conversationId: conversationId,
      recipientDeviceKeyId: envelope.context.recipientDeviceKeyId,
      senderDeviceKeyId: envelope.context.senderDeviceKeyId,
      encryptedConversationKey: envelope.payload.cipherTextWithMac,
      nonce: envelope.payload.nonce,
      keyVersion: envelope.context.keyVersion,
      createdAtUtc: DateTime.utc(2026, 9, 9),
    );
    final String key = server.envelopeKey(
      recipientDeviceKeyId: record.recipientDeviceKeyId,
      keyVersion: record.keyVersion,
    );
    final E2EConversationKeyEnvelopeRecord? existing = server.envelopes[key];
    if (existing != null) {
      final bool samePayload =
          existing.senderDeviceKeyId == record.senderDeviceKeyId &&
              _bytesEqual(
                existing.encryptedConversationKey,
                record.encryptedConversationKey,
              ) &&
              _bytesEqual(existing.nonce, record.nonce);
      if (!samePayload) {
        throw const ApiException(
          message: 'Envelope conflict.',
          statusCode: 409,
        );
      }
      return existing;
    }
    server.envelopes[key] = record;
    return record;
  }

  void _requireEnvelopeCoverage(int keyVersion) {
    for (final E2EDeviceKeyRecord device in server.deviceKeys) {
      final String envelopeKey = server.envelopeKey(
        recipientDeviceKeyId: device.id,
        keyVersion: keyVersion,
      );
      if (!server.envelopes.containsKey(envelopeKey)) {
        throw const ApiException(
          message: 'Envelope coverage is incomplete.',
          statusCode: 409,
        );
      }
    }
  }

  @override
  Future<ChatMessage> sendEncryptedText({
    required String conversationId,
    required String senderDeviceKeyId,
    required int keyVersion,
    required E2EEncryptedPayload payload,
  }) async {
    _requireEnvelopeCoverage(keyVersion);

    final List<int> responseCipherText =
        List<int>.of(payload.cipherTextWithMac);
    if (server.mutateEncryptedResponse) {
      responseCipherText[0] ^= 0x01;
    }
    final ChatMessage message = ChatMessage(
      id: 'message-${server.messages.length + 1}',
      conversationId: conversationId,
      senderUserId: userId,
      senderDisplayName: userId == _FakeE2EServer.aliceUserId ? 'Alice' : 'Bob',
      type: MessageType.text,
      content: server.invalidPlaintextResponse ? 'invalid plaintext' : null,
      encryptedContent: responseCipherText,
      contentNonce: payload.nonce,
      encryptionVersion: ChatEncryptionVersion.clientE2E,
      keyVersion: keyVersion,
      sentAtUtc: DateTime.utc(2026, 9, 9, 12, server.messages.length),
    );
    server.messages.add(message);
    return message;
  }

  @override
  Future<ChatMessage> sendEncryptedMedia({
    required String conversationId,
    required String senderDeviceKeyId,
    required int keyVersion,
    required E2EPrivateMessageType type,
    required E2EEncryptedPayload payload,
    int? durationMilliseconds,
    E2ETransferProgress? onUploadProgress,
  }) async {
    if (type == E2EPrivateMessageType.text) {
      throw ArgumentError.value(
        type,
        'type',
        'Use sendEncryptedText for text messages.',
      );
    }
    _requireEnvelopeCoverage(keyVersion);

    final int ordinal = server.messages.length + 1;
    final String attachmentId =
        '00000000-0000-0000-0000-${ordinal.toString().padLeft(12, '0')}';
    final String attachmentUrl = '/api/media/message-attachments/$attachmentId';
    final List<int> cipherText = List<int>.of(payload.cipherTextWithMac);
    server.attachments[attachmentUrl] = cipherText;
    onUploadProgress?.call(cipherText.length, cipherText.length);

    final ChatMessage message = ChatMessage(
      id: 'message-$ordinal',
      conversationId: conversationId,
      senderUserId: userId,
      senderDisplayName: userId == _FakeE2EServer.aliceUserId ? 'Alice' : 'Bob',
      type: type.wireValue,
      encryptionVersion: ChatEncryptionVersion.clientE2E,
      keyVersion: keyVersion,
      sentAtUtc: DateTime.utc(2026, 9, 9, 12, server.messages.length),
      attachmentId: attachmentId,
      attachmentUrl: attachmentUrl,
      attachmentMimeType: server.invalidMediaResponse
          ? 'image/jpeg'
          : E2ECryptoConstants.encryptedMediaContentType,
      attachmentNonce: payload.nonce,
      attachmentEncryptionVersion: ChatEncryptionVersion.clientE2E,
      attachmentKeyVersion: keyVersion,
      attachmentSizeBytes: cipherText.length,
      attachmentDurationMilliseconds: ((server.invalidVoiceDurationResponse &&
                      type == E2EPrivateMessageType.voice) ||
                  (server.invalidVideoDurationResponse &&
                      type == E2EPrivateMessageType.video)) &&
              durationMilliseconds != null
          ? durationMilliseconds + 1
          : durationMilliseconds,
    );
    server.messages.add(message);
    return message;
  }

  @override
  Future<Uint8List> downloadEncryptedAttachment(String attachmentUrl) async {
    final List<int>? cipherText = server.attachments[attachmentUrl];
    if (cipherText == null) {
      throw const ApiException(
        message: 'Encrypted attachment was not found.',
        statusCode: 404,
      );
    }
    return Uint8List.fromList(cipherText);
  }
}

Uint8List _pngBytes(String marker) => Uint8List.fromList(<int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      ...utf8.encode(marker),
    ]);

Uint8List _m4aBytes(String marker) => Uint8List.fromList(<int>[
      0x00,
      0x00,
      0x00,
      0x18,
      0x66,
      0x74,
      0x79,
      0x70,
      0x4d,
      0x34,
      0x41,
      0x20,
      0x00,
      0x00,
      0x00,
      0x00,
      ...utf8.encode(marker),
    ]);

Uint8List _aacBytes(String marker) => Uint8List.fromList(<int>[
      0xff,
      0xf1,
      0x50,
      0x80,
      0x00,
      0x1f,
      0xfc,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      ...utf8.encode(marker),
    ]);

Uint8List _mp4Bytes(String marker) => Uint8List.fromList(<int>[
      0x00,
      0x00,
      0x00,
      0x18,
      0x66,
      0x74,
      0x79,
      0x70,
      0x69,
      0x73,
      0x6f,
      0x6d,
      0x00,
      0x00,
      0x00,
      0x00,
      ...utf8.encode(marker),
    ]);

Uint8List _movBytes(String marker) => Uint8List.fromList(<int>[
      0x00,
      0x00,
      0x00,
      0x18,
      0x66,
      0x74,
      0x79,
      0x70,
      0x71,
      0x74,
      0x20,
      0x20,
      0x00,
      0x00,
      0x00,
      0x00,
      ...utf8.encode(marker),
    ]);

Uint8List _webmBytes(String marker) => Uint8List.fromList(<int>[
      0x1a,
      0x45,
      0xdf,
      0xa3,
      0x9f,
      0x42,
      0x86,
      0x81,
      0x01,
      0x42,
      0xf7,
      0x81,
      0x01,
      0x42,
      0xf2,
      0x81,
      ...utf8.encode(marker),
    ]);

ChatMessage _copyWithAttachmentNonce(
  ChatMessage message,
  List<int> attachmentNonce,
) =>
    ChatMessage(
      id: message.id,
      conversationId: message.conversationId,
      senderUserId: message.senderUserId,
      senderDisplayName: message.senderDisplayName,
      type: message.type,
      content: message.content,
      encryptedContent: message.encryptedContent,
      contentNonce: message.contentNonce,
      encryptionVersion: message.encryptionVersion,
      keyVersion: message.keyVersion,
      sentAtUtc: message.sentAtUtc,
      attachmentId: message.attachmentId,
      attachmentUrl: message.attachmentUrl,
      attachmentMimeType: message.attachmentMimeType,
      attachmentNonce: attachmentNonce,
      attachmentEncryptionVersion: message.attachmentEncryptionVersion,
      attachmentKeyVersion: message.attachmentKeyVersion,
      attachmentSizeBytes: message.attachmentSizeBytes,
      attachmentDurationMilliseconds: message.attachmentDurationMilliseconds,
      decryptedContent: message.decryptedContent,
      decryptionError: message.decryptionError,
    );

ChatMessage _copyWithAttachmentUrl(
  ChatMessage message,
  String attachmentUrl,
) =>
    ChatMessage(
      id: message.id,
      conversationId: message.conversationId,
      senderUserId: message.senderUserId,
      senderDisplayName: message.senderDisplayName,
      type: message.type,
      content: message.content,
      encryptedContent: message.encryptedContent,
      contentNonce: message.contentNonce,
      encryptionVersion: message.encryptionVersion,
      keyVersion: message.keyVersion,
      sentAtUtc: message.sentAtUtc,
      attachmentId: message.attachmentId,
      attachmentUrl: attachmentUrl,
      attachmentMimeType: message.attachmentMimeType,
      attachmentNonce: message.attachmentNonce,
      attachmentEncryptionVersion: message.attachmentEncryptionVersion,
      attachmentKeyVersion: message.attachmentKeyVersion,
      attachmentSizeBytes: message.attachmentSizeBytes,
      attachmentDurationMilliseconds: message.attachmentDurationMilliseconds,
      decryptedContent: message.decryptedContent,
      decryptionError: message.decryptionError,
    );

ChatMessage _copyWithAttachmentDuration(
  ChatMessage message,
  int? attachmentDurationMilliseconds,
) =>
    ChatMessage(
      id: message.id,
      conversationId: message.conversationId,
      senderUserId: message.senderUserId,
      senderDisplayName: message.senderDisplayName,
      type: message.type,
      content: message.content,
      encryptedContent: message.encryptedContent,
      contentNonce: message.contentNonce,
      encryptionVersion: message.encryptionVersion,
      keyVersion: message.keyVersion,
      sentAtUtc: message.sentAtUtc,
      attachmentId: message.attachmentId,
      attachmentUrl: message.attachmentUrl,
      attachmentMimeType: message.attachmentMimeType,
      attachmentNonce: message.attachmentNonce,
      attachmentEncryptionVersion: message.attachmentEncryptionVersion,
      attachmentKeyVersion: message.attachmentKeyVersion,
      attachmentSizeBytes: message.attachmentSizeBytes,
      attachmentDurationMilliseconds: attachmentDurationMilliseconds,
      decryptedContent: message.decryptedContent,
      decryptionError: message.decryptionError,
    );

E2EDeviceKeyRecord _deviceRecord({
  required String id,
  required String userId,
  required String deviceId,
  required List<int> publicKey,
}) =>
    E2EDeviceKeyRecord(
      id: id,
      userId: userId,
      deviceId: deviceId,
      publicKey: publicKey,
      createdAtUtc: DateTime.utc(2026, 9, 9),
      lastSeenAtUtc: DateTime.utc(2026, 9, 9),
    );

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
