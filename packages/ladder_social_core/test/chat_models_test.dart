import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('conversation parses whether new messages are allowed', () {
    final ConversationItem conversation = ConversationItem.fromJson(
      <String, dynamic>{
        'id': 'conversation-id',
        'displayTitle': 'Bob Review',
        'isGroup': false,
        'canSendMessages': false,
        'lastMessageAtUtc': '2026-09-01T10:00:00Z',
        'lastMessagePreview': 'Previous message',
        'unreadCount': 0,
        'participants': <Map<String, dynamic>>[
          <String, dynamic>{
            'userId': 'current-user-id',
            'displayName': 'Alice Review',
            'avatarUrl': null,
            'isCurrentUser': true,
          },
          <String, dynamic>{
            'userId': 'friend-user-id',
            'displayName': 'Bob Review',
            'avatarUrl': null,
            'isCurrentUser': false,
          },
        ],
      },
    );

    expect(conversation.canSendMessages, isFalse);
    expect(conversation.participants, hasLength(2));
  });

  test('encrypted text response decodes Base64 without exposing content', () {
    final List<int> cipherText = List<int>.generate(32, (int index) => index);
    final List<int> nonce = List<int>.generate(12, (int index) => index + 10);
    final ChatMessage message = ChatMessage.fromJson(<String, dynamic>{
      'id': 'message-id',
      'conversationId': 'conversation-id',
      'senderUserId': 'sender-id',
      'senderDisplayName': 'Sender',
      'type': MessageType.text,
      'content': null,
      'encryptedContent': base64Encode(cipherText),
      'contentNonce': base64Encode(nonce),
      'encryptionVersion': ChatEncryptionVersion.clientE2E,
      'keyVersion': 1,
      'sentAtUtc': '2026-09-09T12:00:00Z',
      'attachmentId': null,
      'attachmentUrl': null,
      'attachmentMimeType': null,
      'attachmentNonce': null,
      'attachmentEncryptionVersion': null,
      'attachmentKeyVersion': null,
      'attachmentSizeBytes': null,
      'attachmentDurationMilliseconds': null,
    });

    expect(message.encryptedContent, cipherText);
    expect(message.contentNonce, nonce);
    expect(message.content, isNull);
    expect(message.visibleContent, isNull);
    expect(message.isE2E, isTrue);

    final ChatMessage decrypted = message.withDecryptedContent('Local text');
    expect(decrypted.visibleContent, 'Local text');
    expect(decrypted.content, isNull);
  });

  test('E2E response containing plaintext content is rejected', () {
    expect(
      () => ChatMessage.fromJson(<String, dynamic>{
        'id': 'message-id',
        'conversationId': 'conversation-id',
        'senderUserId': 'sender-id',
        'senderDisplayName': 'Sender',
        'type': MessageType.text,
        'content': 'Server plaintext must be rejected',
        'encryptedContent': base64Encode(List<int>.filled(32, 7)),
        'contentNonce': base64Encode(List<int>.filled(12, 8)),
        'encryptionVersion': ChatEncryptionVersion.clientE2E,
        'keyVersion': 1,
        'sentAtUtc': '2026-09-09T12:00:00Z',
        'attachmentId': null,
        'attachmentUrl': null,
        'attachmentMimeType': null,
        'attachmentNonce': null,
        'attachmentEncryptionVersion': null,
        'attachmentKeyVersion': null,
        'attachmentSizeBytes': null,
        'attachmentDurationMilliseconds': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('unknown encryption version never falls back to server content', () {
    final ChatMessage message = ChatMessage(
      id: 'future-message',
      conversationId: 'conversation-id',
      senderUserId: 'sender-id',
      senderDisplayName: 'Sender',
      type: MessageType.text,
      content: 'Server-provided text must stay hidden',
      sentAtUtc: DateTime.utc(2026, 9, 9),
      encryptionVersion: 999,
    );

    expect(message.isLegacy, isFalse);
    expect(message.visibleContent, isNull);
  });
}
