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
}
