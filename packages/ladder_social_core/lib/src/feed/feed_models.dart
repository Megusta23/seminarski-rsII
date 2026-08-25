import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

// Values mirror LadderSocial.Domain.Enums.FeedActivityType.
enum FeedActivityType {
  unfinished(1),
  completedWithoutProof(2),
  completedWithProof(3);

  const FeedActivityType(this.value);
  final int value;

  static FeedActivityType fromJson(Object? value) {
    final int parsed = value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
    return FeedActivityType.values.firstWhere(
      (FeedActivityType item) => item.value == parsed,
      orElse: () => throw const FormatException(
        'The server returned an unknown feed activity type.',
      ),
    );
  }
}

final class FeedPost {
  const FeedPost({
    required this.id,
    required this.activityType,
    required this.activityAtUtc,
    required this.occurrenceDate,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.taskId,
    required this.taskTitle,
    required this.categoryName,
    required this.categoryCode,
    required this.recurrenceName,
    required this.recurrenceCode,
    required this.hasBeenViewed,
    this.authorAvatarUrl,
    this.dueAtUtc,
    this.caption,
    this.proofMediaId,
    this.proofUrl,
    this.viewedAtUtc,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    final DateTime activityAtUtc = json.containsKey('activityAtUtc')
        ? requiredDateTime(json, 'activityAtUtc')
        : requiredDateTime(json, 'completedAtUtc');
    final String? proofMediaId = nullableString(json['proofMediaId']);
    final FeedActivityType activityType = json.containsKey('activityType')
        ? FeedActivityType.fromJson(json['activityType'])
        : proofMediaId == null
            ? FeedActivityType.completedWithoutProof
            : FeedActivityType.completedWithProof;
    final String occurrenceText = nullableString(json['occurrenceDate']) ??
        '${activityAtUtc.year.toString().padLeft(4, '0')}-'
            '${activityAtUtc.month.toString().padLeft(2, '0')}-'
            '${activityAtUtc.day.toString().padLeft(2, '0')}';

    return FeedPost(
      id: requiredString(json, 'id'),
      activityType: activityType,
      activityAtUtc: activityAtUtc,
      occurrenceDate: DateTime.parse(occurrenceText),
      authorUserId: requiredString(json, 'authorUserId'),
      authorDisplayName: requiredString(json, 'authorDisplayName'),
      authorAvatarUrl: nullableString(json['authorAvatarUrl']),
      taskId: requiredString(json, 'taskId'),
      taskTitle: requiredString(json, 'taskTitle'),
      categoryName: requiredString(json, 'categoryName'),
      categoryCode: nullableString(json['categoryCode']) ?? 'unknown',
      recurrenceName: nullableString(json['recurrenceName']) ?? 'Does not repeat',
      recurrenceCode: nullableString(json['recurrenceCode']) ?? 'none',
      dueAtUtc: nullableDateTime(json['dueAtUtc']),
      caption: nullableString(json['caption']),
      proofMediaId: proofMediaId,
      proofUrl: nullableString(json['proofUrl']),
      hasBeenViewed: json.containsKey('hasBeenViewed')
          ? requiredBool(json, 'hasBeenViewed')
          : false,
      viewedAtUtc: nullableDateTime(json['viewedAtUtc']),
    );
  }

  final String id;
  final FeedActivityType activityType;
  final DateTime activityAtUtc;
  final DateTime occurrenceDate;
  final String authorUserId;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String taskId;
  final String taskTitle;
  final String categoryName;
  final String categoryCode;
  final String recurrenceName;
  final String recurrenceCode;
  final DateTime? dueAtUtc;
  final String? caption;
  final String? proofMediaId;
  final String? proofUrl;
  final bool hasBeenViewed;
  final DateTime? viewedAtUtc;

  bool get isCompleted => activityType != FeedActivityType.unfinished;
  bool get hasProof => proofMediaId != null && proofUrl != null;
  bool get hasUnseenProof => hasProof && !hasBeenViewed;

  // Backward-compatible name used by earlier feed UI/tests.
  DateTime get completedAtUtc => activityAtUtc;

  FeedPost copyWithViewed({DateTime? atUtc}) => FeedPost(
        id: id,
        activityType: activityType,
        activityAtUtc: activityAtUtc,
        occurrenceDate: occurrenceDate,
        authorUserId: authorUserId,
        authorDisplayName: authorDisplayName,
        authorAvatarUrl: authorAvatarUrl,
        taskId: taskId,
        taskTitle: taskTitle,
        categoryName: categoryName,
        categoryCode: categoryCode,
        recurrenceName: recurrenceName,
        recurrenceCode: recurrenceCode,
        dueAtUtc: dueAtUtc,
        caption: caption,
        proofMediaId: proofMediaId,
        proofUrl: proofUrl,
        hasBeenViewed: true,
        viewedAtUtc: atUtc ?? DateTime.now().toUtc(),
      );
}

final class FriendProgress {
  const FriendProgress({
    required this.userId,
    required this.displayName,
    required this.completedToday,
    required this.scheduledToday,
    required this.currentStreak,
    this.avatarUrl,
    this.percentage,
  });

  factory FriendProgress.fromJson(Map<String, dynamic> json) => FriendProgress(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        avatarUrl: nullableString(json['avatarUrl']),
        completedToday: requiredInt(json, 'completedToday'),
        scheduledToday: requiredInt(json, 'scheduledToday'),
        percentage: json['percentage'] == null ? null : requiredInt(json, 'percentage'),
        currentStreak: requiredInt(json, 'currentStreak'),
      );

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int completedToday;
  final int scheduledToday;
  final int? percentage;
  final int currentStreak;

  double? get progress => percentage == null ? null : percentage!.clamp(0, 100) / 100;
}

final class FeedPage {
  const FeedPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.date,
    required this.hasFriends,
    required this.friendCount,
    required this.friendProgress,
  });

  factory FeedPage.fromJson(Map<String, dynamic> json) => FeedPage(
        items: List<FeedPost>.unmodifiable(
          jsonList(json['items'], context: 'feed items').map(
            (Object? item) => FeedPost.fromJson(
              jsonMap(item, context: 'feed item'),
            ),
          ),
        ),
        page: requiredInt(json, 'page'),
        pageSize: requiredInt(json, 'pageSize'),
        totalCount: requiredInt(json, 'totalCount'),
        totalPages: requiredInt(json, 'totalPages'),
        date: DateTime.parse(requiredString(json, 'date')),
        hasFriends: requiredBool(json, 'hasFriends'),
        friendCount: requiredInt(json, 'friendCount'),
        friendProgress: List<FriendProgress>.unmodifiable(
          jsonList(json['friendProgress'], context: 'friend progress').map(
            (Object? item) => FriendProgress.fromJson(
              jsonMap(item, context: 'friend progress item'),
            ),
          ),
        ),
      );

  final List<FeedPost> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final DateTime date;
  final bool hasFriends;
  final int friendCount;
  final List<FriendProgress> friendProgress;
}
