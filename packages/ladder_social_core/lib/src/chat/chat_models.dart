import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

abstract final class MessageType {
  static const int text = 1;
  static const int image = 2;
  static const int system = 3;
}

final class ConversationParticipant {
  const ConversationParticipant({
    required this.userId,
    required this.displayName,
    required this.isCurrentUser,
    this.avatarUrl,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) =>
      ConversationParticipant(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        avatarUrl: nullableString(json['avatarUrl']),
        isCurrentUser: requiredBool(json, 'isCurrentUser'),
      );

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;
}

final class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.displayTitle,
    required this.isGroup,
    required this.unreadCount,
    required this.participants,
    this.lastMessageAtUtc,
    this.lastMessagePreview,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) =>
      ConversationItem(
        id: requiredString(json, 'id'),
        displayTitle: requiredString(json, 'displayTitle'),
        isGroup: requiredBool(json, 'isGroup'),
        lastMessageAtUtc: nullableDateTime(json['lastMessageAtUtc']),
        lastMessagePreview: nullableString(json['lastMessagePreview']),
        unreadCount: requiredInt(json, 'unreadCount'),
        participants: List<ConversationParticipant>.unmodifiable(
          jsonList(json['participants'], context: 'conversation participants')
              .map((Object? item) => ConversationParticipant.fromJson(
                    jsonMap(item, context: 'conversation participant'),
                  )),
        ),
      );

  final String id;
  final String displayTitle;
  final bool isGroup;
  final DateTime? lastMessageAtUtc;
  final String? lastMessagePreview;
  final int unreadCount;
  final List<ConversationParticipant> participants;
}

final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.type,
    required this.sentAtUtc,
    this.content,
    this.attachmentId,
    this.attachmentUrl,
    this.attachmentMimeType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: requiredString(json, 'id'),
        conversationId: requiredString(json, 'conversationId'),
        senderUserId: requiredString(json, 'senderUserId'),
        senderDisplayName: requiredString(json, 'senderDisplayName'),
        type: requiredInt(json, 'type'),
        content: nullableString(json['content']),
        sentAtUtc: requiredDateTime(json, 'sentAtUtc'),
        attachmentId: nullableString(json['attachmentId']),
        attachmentUrl: nullableString(json['attachmentUrl']),
        attachmentMimeType: nullableString(json['attachmentMimeType']),
      );

  final String id;
  final String conversationId;
  final String senderUserId;
  final String senderDisplayName;
  final int type;
  final String? content;
  final DateTime sentAtUtc;
  final String? attachmentId;
  final String? attachmentUrl;
  final String? attachmentMimeType;
}
