import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

final class LeaderboardEntry {
  const LeaderboardEntry({
    required this.position,
    required this.userId,
    required this.displayName,
    required this.score,
    required this.isCurrentUser,
    this.avatarUrl,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        position: requiredInt(json, 'position'),
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        avatarUrl: nullableString(json['avatarUrl']),
        score: requiredInt(json, 'score'),
        isCurrentUser: requiredBool(json, 'isCurrentUser'),
      );

  final int position;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int score;
  final bool isCurrentUser;
}

final class LeaderboardResult {
  const LeaderboardResult({
    required this.fromDate,
    required this.toDate,
    required this.entries,
    this.currentUser,
  });

  factory LeaderboardResult.fromJson(Map<String, dynamic> json) {
    final Object? current = json['currentUser'];
    return LeaderboardResult(
      fromDate: DateTime.parse(requiredString(json, 'fromDate')),
      toDate: DateTime.parse(requiredString(json, 'toDate')),
      entries: List<LeaderboardEntry>.unmodifiable(
        jsonList(json['entries'], context: 'leaderboard entries').map(
          (Object? item) => LeaderboardEntry.fromJson(
            jsonMap(item, context: 'leaderboard entry'),
          ),
        ),
      ),
      currentUser: current == null
          ? null
          : LeaderboardEntry.fromJson(
              jsonMap(current, context: 'current leaderboard entry'),
            ),
    );
  }

  final DateTime fromDate;
  final DateTime toDate;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUser;
}
