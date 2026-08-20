import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

abstract final class NotificationKind {
  static const int friendRequestReceived = 1;
  static const int friendRequestAccepted = 2;
  static const int taskCompleted = 3;
  static const int newMessage = 4;
  static const int system = 5;

  static String label(int value) => switch (value) {
        friendRequestReceived => 'Friend request',
        friendRequestAccepted => 'Friend accepted',
        taskCompleted => 'Task completed',
        newMessage => 'New message',
        _ => 'System',
      };
}

final class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAtUtc,
    this.readAtUtc,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: requiredString(json, 'id'),
        kind: requiredInt(json, 'kind'),
        title: requiredString(json, 'title'),
        body: requiredString(json, 'body'),
        isRead: requiredBool(json, 'isRead'),
        createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
        readAtUtc: nullableDateTime(json['readAtUtc']),
        relatedEntityType: nullableString(json['relatedEntityType']),
        relatedEntityId: nullableString(json['relatedEntityId']),
      );

  final String id;
  final int kind;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAtUtc;
  final DateTime? readAtUtc;
  final String? relatedEntityType;
  final String? relatedEntityId;
}

final class NotificationSummary {
  const NotificationSummary({
    required this.unreadCount,
    required this.generatedAtUtc,
  });

  factory NotificationSummary.fromJson(Map<String, dynamic> json) =>
      NotificationSummary(
        unreadCount: requiredInt(json, 'unreadCount'),
        generatedAtUtc: requiredDateTime(json, 'generatedAtUtc'),
      );

  final int unreadCount;
  final DateTime generatedAtUtc;
}
