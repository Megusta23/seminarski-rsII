import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

abstract final class FriendRequestStatus {
  static const int pending = 1;
  static const int accepted = 2;
  static const int rejected = 3;
  static const int cancelled = 4;
}

final class FriendSummary {
  const FriendSummary({
    required this.userId,
    required this.displayName,
    required this.completedTaskCount,
    required this.currentStreak,
    this.avatarUrl,
  });

  factory FriendSummary.fromJson(Map<String, dynamic> json) => FriendSummary(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        avatarUrl: nullableString(json['avatarUrl']),
        completedTaskCount: requiredInt(json, 'completedTaskCount'),
        currentStreak: requiredInt(json, 'currentStreak'),
      );

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int completedTaskCount;
  final int currentStreak;
}

final class UserSearchItem {
  const UserSearchItem({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.isFriend,
    required this.hasOutgoingPendingRequest,
    required this.hasIncomingPendingRequest,
    this.avatarUrl,
  });

  factory UserSearchItem.fromJson(Map<String, dynamic> json) => UserSearchItem(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        email: requiredString(json, 'email'),
        avatarUrl: nullableString(json['avatarUrl']),
        isFriend: requiredBool(json, 'isFriend'),
        hasOutgoingPendingRequest:
            requiredBool(json, 'hasOutgoingPendingRequest'),
        hasIncomingPendingRequest:
            requiredBool(json, 'hasIncomingPendingRequest'),
      );

  final String userId;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final bool isFriend;
  final bool hasOutgoingPendingRequest;
  final bool hasIncomingPendingRequest;
}

final class FriendRequestItem {
  const FriendRequestItem({
    required this.id,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.receiverUserId,
    required this.receiverDisplayName,
    required this.status,
    required this.createdAtUtc,
    this.senderAvatarUrl,
    this.respondedAtUtc,
  });

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) =>
      FriendRequestItem(
        id: requiredString(json, 'id'),
        senderUserId: requiredString(json, 'senderUserId'),
        senderDisplayName: requiredString(json, 'senderDisplayName'),
        senderAvatarUrl: nullableString(json['senderAvatarUrl']),
        receiverUserId: requiredString(json, 'receiverUserId'),
        receiverDisplayName: requiredString(json, 'receiverDisplayName'),
        status: requiredInt(json, 'status'),
        createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
        respondedAtUtc: nullableDateTime(json['respondedAtUtc']),
      );

  final String id;
  final String senderUserId;
  final String senderDisplayName;
  final String? senderAvatarUrl;
  final String receiverUserId;
  final String receiverDisplayName;
  final int status;
  final DateTime createdAtUtc;
  final DateTime? respondedAtUtc;
}

final class MutualFriend {
  const MutualFriend({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  factory MutualFriend.fromJson(Map<String, dynamic> json) => MutualFriend(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        avatarUrl: nullableString(json['avatarUrl']),
      );

  final String userId;
  final String displayName;
  final String? avatarUrl;
}

final class MutualFriends {
  const MutualFriends({required this.count, required this.items});

  factory MutualFriends.fromJson(Map<String, dynamic> json) => MutualFriends(
        count: requiredInt(json, 'count'),
        items: List<MutualFriend>.unmodifiable(
          jsonList(json['items'], context: 'mutual friends').map(
            (Object? item) => MutualFriend.fromJson(
              jsonMap(item, context: 'mutual friend'),
            ),
          ),
        ),
      );

  final int count;
  final List<MutualFriend> items;
}

final class HighlightedPost {
  const HighlightedPost({
    required this.postId,
    required this.taskId,
    required this.taskTitle,
    required this.categoryName,
    required this.categoryCode,
    required this.proofMediaId,
    required this.proofUrl,
    required this.completedAtUtc,
    required this.highlightedAtUtc,
    this.caption,
  });

  factory HighlightedPost.fromJson(Map<String, dynamic> json) =>
      HighlightedPost(
        postId: requiredString(json, 'postId'),
        taskId: requiredString(json, 'taskId'),
        taskTitle: requiredString(json, 'taskTitle'),
        caption: nullableString(json['caption']),
        categoryName: requiredString(json, 'categoryName'),
        categoryCode: requiredString(json, 'categoryCode'),
        proofMediaId: requiredString(json, 'proofMediaId'),
        proofUrl: requiredString(json, 'proofUrl'),
        completedAtUtc: requiredDateTime(json, 'completedAtUtc'),
        highlightedAtUtc: requiredDateTime(json, 'highlightedAtUtc'),
      );

  final String postId;
  final String taskId;
  final String taskTitle;
  final String? caption;
  final String categoryName;
  final String categoryCode;
  final String proofMediaId;
  final String proofUrl;
  final DateTime completedAtUtc;
  final DateTime highlightedAtUtc;
}

final class ProfileHighlightCandidate {
  const ProfileHighlightCandidate({
    required this.postId,
    required this.taskId,
    required this.taskTitle,
    required this.categoryName,
    required this.categoryCode,
    required this.proofMediaId,
    required this.proofUrl,
    required this.completedAtUtc,
    required this.isHighlighted,
    this.caption,
    this.highlightedAtUtc,
  });

  factory ProfileHighlightCandidate.fromJson(Map<String, dynamic> json) =>
      ProfileHighlightCandidate(
        postId: requiredString(json, 'postId'),
        taskId: requiredString(json, 'taskId'),
        taskTitle: requiredString(json, 'taskTitle'),
        caption: nullableString(json['caption']),
        categoryName: requiredString(json, 'categoryName'),
        categoryCode: requiredString(json, 'categoryCode'),
        proofMediaId: requiredString(json, 'proofMediaId'),
        proofUrl: requiredString(json, 'proofUrl'),
        completedAtUtc: requiredDateTime(json, 'completedAtUtc'),
        isHighlighted: requiredBool(json, 'isHighlighted'),
        highlightedAtUtc: nullableDateTime(json['highlightedAtUtc']),
      );

  final String postId;
  final String taskId;
  final String taskTitle;
  final String? caption;
  final String categoryName;
  final String categoryCode;
  final String proofMediaId;
  final String proofUrl;
  final DateTime completedAtUtc;
  final bool isHighlighted;
  final DateTime? highlightedAtUtc;

  ProfileHighlightCandidate copyWithHighlighted(bool value) =>
      ProfileHighlightCandidate(
        postId: postId,
        taskId: taskId,
        taskTitle: taskTitle,
        caption: caption,
        categoryName: categoryName,
        categoryCode: categoryCode,
        proofMediaId: proofMediaId,
        proofUrl: proofUrl,
        completedAtUtc: completedAtUtc,
        isHighlighted: value,
        highlightedAtUtc: value ? DateTime.now().toUtc() : null,
      );
}

final class FriendProfile {
  const FriendProfile({
    required this.userId,
    required this.displayName,
    required this.memberSinceUtc,
    required this.visiblePostCount,
    required this.friendCount,
    required this.completedTaskCount,
    required this.habitCount,
    required this.currentStreak,
    required this.canMessage,
    required this.mutualFriends,
    required this.highlightedPosts,
    this.bio,
    this.avatarUrl,
    this.cityName,
  });

  factory FriendProfile.fromJson(Map<String, dynamic> json) => FriendProfile(
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
        canMessage: requiredBool(json, 'canMessage'),
        mutualFriends: MutualFriends.fromJson(
          jsonMap(json['mutualFriends'], context: 'mutual friends summary'),
        ),
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
  final bool canMessage;
  final MutualFriends mutualFriends;
  final List<HighlightedPost> highlightedPosts;
}

final class FriendRecommendation {
  const FriendRecommendation({
    required this.userId,
    required this.displayName,
    required this.mutualFriendCount,
    required this.explanation,
    this.avatarUrl,
  });

  factory FriendRecommendation.fromJson(Map<String, dynamic> json) =>
      FriendRecommendation(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        avatarUrl: nullableString(json['avatarUrl']),
        mutualFriendCount: requiredInt(json, 'mutualFriendCount'),
        explanation: requiredString(json, 'explanation'),
      );

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int mutualFriendCount;
  final String explanation;
}
