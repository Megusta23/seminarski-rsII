import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/friends/friend_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

final class OwnProfileOverview {
  const OwnProfileOverview({
    required this.userId,
    required this.displayName,
    required this.memberSinceUtc,
    required this.visiblePostCount,
    required this.friendCount,
    required this.completedTaskCount,
    required this.habitCount,
    required this.currentStreak,
    required this.highlightedPosts,
    this.bio,
    this.avatarUrl,
    this.cityName,
  });

  factory OwnProfileOverview.fromJson(Map<String, dynamic> json) =>
      OwnProfileOverview(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        bio: nullableString(json['bio']),
        avatarUrl: nullableString(json['avatarUrl']),
        cityName: nullableString(json['cityName']),
        memberSinceUtc: requiredDateTime(json, 'memberSinceUtc'),
        visiblePostCount: requiredInt(json, 'visiblePostCount'),
        friendCount: requiredInt(json, 'friendCount'),
        completedTaskCount: requiredInt(json, 'completedTaskCount'),
        habitCount: requiredInt(json, 'habitCount'),
        currentStreak: requiredInt(json, 'currentStreak'),
        highlightedPosts: List<HighlightedPost>.unmodifiable(
          jsonList(json['highlightedPosts'], context: 'highlighted posts').map(
            (Object? item) => HighlightedPost.fromJson(
              jsonMap(item, context: 'highlighted post'),
            ),
          ),
        ),
      );

  final String userId;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String? cityName;
  final DateTime memberSinceUtc;
  final int visiblePostCount;
  final int friendCount;
  final int completedTaskCount;
  final int habitCount;
  final int currentStreak;
  final List<HighlightedPost> highlightedPosts;
}
