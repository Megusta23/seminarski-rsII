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

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) => FriendRequestItem(
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

final class FriendProfile {
  const FriendProfile({
    required this.userId,
    required this.displayName,
    required this.friendCount,
    required this.completedTaskCount,
    required this.habitCount,
    required this.currentStreak,
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
        friendCount: requiredInt(json, 'friendCount'),
        completedTaskCount: requiredInt(json, 'completedTaskCount'),
        habitCount: requiredInt(json, 'habitCount'),
        currentStreak: requiredInt(json, 'currentStreak'),
      );

  final String userId;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String? cityName;
  final int friendCount;
  final int completedTaskCount;
  final int habitCount;
  final int currentStreak;
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
