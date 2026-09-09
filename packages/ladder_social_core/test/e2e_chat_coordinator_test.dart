import 'dart:convert';

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
}

final class _Fixture {
  _Fixture({
    bool invalidPlaintextResponse = false,
    bool mutateEncryptedResponse = false,
  })  : server = _FakeE2EServer(
          invalidPlaintextResponse: invalidPlaintextResponse,
          mutateEncryptedResponse: mutateEncryptedResponse,
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
  });

  static const String conversationId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  static const String aliceUserId = '11111111-1111-1111-1111-111111111111';

  final bool invalidPlaintextResponse;
  final bool mutateEncryptedResponse;
  final Map<String, E2EDeviceKeyRecord> devicesByUser =
      <String, E2EDeviceKeyRecord>{};
  final Map<String, E2EConversationKeyEnvelopeRecord> envelopes =
      <String, E2EConversationKeyEnvelopeRecord>{};
  final List<ChatMessage> messages = <ChatMessage>[];

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

  @override
  Future<ChatMessage> sendEncryptedText({
    required String conversationId,
    required String senderDeviceKeyId,
    required int keyVersion,
    required E2EEncryptedPayload payload,
  }) async {
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
}

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
