import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

final class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.taskId,
    required this.taskTitle,
    required this.categoryName,
    required this.completedAtUtc,
    required this.hasBeenViewed,
    this.authorAvatarUrl,
    this.caption,
    this.proofMediaId,
    this.proofUrl,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) => FeedPost(
        id: requiredString(json, 'id'),
        authorUserId: requiredString(json, 'authorUserId'),
        authorDisplayName: requiredString(json, 'authorDisplayName'),
        authorAvatarUrl: nullableString(json['authorAvatarUrl']),
        taskId: requiredString(json, 'taskId'),
        taskTitle: requiredString(json, 'taskTitle'),
        categoryName: requiredString(json, 'categoryName'),
        caption: nullableString(json['caption']),
        completedAtUtc: requiredDateTime(json, 'completedAtUtc'),
        proofMediaId: nullableString(json['proofMediaId']),
        proofUrl: nullableString(json['proofUrl']),
        hasBeenViewed: requiredBool(json, 'hasBeenViewed'),
      );

  final String id;
  final String authorUserId;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String taskId;
  final String taskTitle;
  final String categoryName;
  final String? caption;
  final DateTime completedAtUtc;
  final String? proofMediaId;
  final String? proofUrl;
  final bool hasBeenViewed;
}
