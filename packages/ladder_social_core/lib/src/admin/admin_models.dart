import 'dart:typed_data';

import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

final class AdminTopUser {
  const AdminTopUser({
    required this.userId,
    required this.displayName,
    required this.completedTaskCount,
  });

  factory AdminTopUser.fromJson(Map<String, dynamic> json) => AdminTopUser(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        completedTaskCount: requiredInt(json, 'completedTaskCount'),
      );

  final String userId;
  final String displayName;
  final int completedTaskCount;
}

final class AdminDashboard {
  const AdminDashboard({
    required this.generatedAtUtc,
    required this.totalUsers,
    required this.activeUsers,
    required this.tasksCreated,
    required this.tasksCompletedToday,
    required this.sharedPosts,
    required this.friendRequests,
    required this.messages,
    required this.topUsers,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
        generatedAtUtc: requiredDateTime(json, 'generatedAtUtc'),
        totalUsers: requiredInt(json, 'totalUsers'),
        activeUsers: requiredInt(json, 'activeUsers'),
        tasksCreated: requiredInt(json, 'tasksCreated'),
        tasksCompletedToday: requiredInt(json, 'tasksCompletedToday'),
        sharedPosts: requiredInt(json, 'sharedPosts'),
        friendRequests: requiredInt(json, 'friendRequests'),
        messages: requiredInt(json, 'messages'),
        topUsers: List<AdminTopUser>.unmodifiable(
          jsonList(json['topUsers'], context: 'top users').map(
            (Object? item) => AdminTopUser.fromJson(
              jsonMap(item, context: 'top user'),
            ),
          ),
        ),
      );

  final DateTime generatedAtUtc;
  final int totalUsers;
  final int activeUsers;
  final int tasksCreated;
  final int tasksCompletedToday;
  final int sharedPosts;
  final int friendRequests;
  final int messages;
  final List<AdminTopUser> topUsers;
}

final class AdminUserItem {
  const AdminUserItem({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isActive,
    required this.createdAtUtc,
    required this.friendCount,
    required this.completedTaskCount,
    this.cityName,
    this.avatarUrl,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) => AdminUserItem(
        id: requiredString(json, 'id'),
        displayName: requiredString(json, 'displayName'),
        email: requiredString(json, 'email'),
        isActive: requiredBool(json, 'isActive'),
        cityName: nullableString(json['cityName']),
        createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
        friendCount: requiredInt(json, 'friendCount'),
        completedTaskCount: requiredInt(json, 'completedTaskCount'),
        avatarUrl: nullableString(json['avatarUrl']),
      );

  final String id;
  final String displayName;
  final String email;
  final bool isActive;
  final String? cityName;
  final DateTime createdAtUtc;
  final int friendCount;
  final int completedTaskCount;
  final String? avatarUrl;
}

final class AdminUserDetail {
  const AdminUserDetail({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isActive,
    required this.firstName,
    required this.lastName,
    required this.createdAtUtc,
    required this.friendCount,
    required this.taskCount,
    required this.completedTaskCount,
    required this.postCount,
    required this.messageCount,
    required this.roles,
    this.bio,
    this.cityName,
    this.dateOfBirth,
    this.avatarUrl,
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    final String? date = nullableString(json['dateOfBirth']);
    return AdminUserDetail(
      id: requiredString(json, 'id'),
      displayName: requiredString(json, 'displayName'),
      email: requiredString(json, 'email'),
      isActive: requiredBool(json, 'isActive'),
      firstName: requiredString(json, 'firstName'),
      lastName: requiredString(json, 'lastName'),
      bio: nullableString(json['bio']),
      cityName: nullableString(json['cityName']),
      dateOfBirth: date == null ? null : DateTime.parse(date),
      createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
      friendCount: requiredInt(json, 'friendCount'),
      taskCount: requiredInt(json, 'taskCount'),
      completedTaskCount: requiredInt(json, 'completedTaskCount'),
      postCount: requiredInt(json, 'postCount'),
      messageCount: requiredInt(json, 'messageCount'),
      avatarUrl: nullableString(json['avatarUrl']),
      roles: stringList(json['roles']),
    );
  }

  final String id;
  final String displayName;
  final String email;
  final bool isActive;
  final String firstName;
  final String lastName;
  final String? bio;
  final String? cityName;
  final DateTime? dateOfBirth;
  final DateTime createdAtUtc;
  final int friendCount;
  final int taskCount;
  final int completedTaskCount;
  final int postCount;
  final int messageCount;
  final String? avatarUrl;
  final List<String> roles;
}

final class AdminPostItem {
  const AdminPostItem({
    required this.id,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.taskTitle,
    required this.isVisible,
    required this.createdAtUtc,
    this.caption,
  });

  factory AdminPostItem.fromJson(Map<String, dynamic> json) => AdminPostItem(
        id: requiredString(json, 'id'),
        authorUserId: requiredString(json, 'authorUserId'),
        authorDisplayName: requiredString(json, 'authorDisplayName'),
        taskTitle: requiredString(json, 'taskTitle'),
        caption: nullableString(json['caption']),
        isVisible: requiredBool(json, 'isVisible'),
        createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
      );

  final String id;
  final String authorUserId;
  final String authorDisplayName;
  final String taskTitle;
  final String? caption;
  final bool isVisible;
  final DateTime createdAtUtc;
}

final class AdminCountry {
  const AdminCountry({
    required this.id,
    required this.isoCode,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  factory AdminCountry.fromJson(Map<String, dynamic> json) => AdminCountry(
        id: requiredString(json, 'id'),
        isoCode: requiredString(json, 'isoCode'),
        name: requiredString(json, 'name'),
        isActive: requiredBool(json, 'isActive'),
        sortOrder: requiredInt(json, 'sortOrder'),
      );

  final String id;
  final String isoCode;
  final String name;
  final bool isActive;
  final int sortOrder;
}

final class AdminCity {
  const AdminCity({
    required this.id,
    required this.name,
    required this.countryId,
    required this.countryName,
    required this.isActive,
    required this.sortOrder,
  });

  factory AdminCity.fromJson(Map<String, dynamic> json) => AdminCity(
        id: requiredString(json, 'id'),
        name: requiredString(json, 'name'),
        countryId: requiredString(json, 'countryId'),
        countryName: requiredString(json, 'countryName'),
        isActive: requiredBool(json, 'isActive'),
        sortOrder: requiredInt(json, 'sortOrder'),
      );

  final String id;
  final String name;
  final String countryId;
  final String countryName;
  final bool isActive;
  final int sortOrder;
}

final class AdminReferenceItem {
  const AdminReferenceItem({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.sortOrder,
  });

  factory AdminReferenceItem.fromJson(Map<String, dynamic> json) =>
      AdminReferenceItem(
        id: requiredString(json, 'id'),
        code: requiredString(json, 'code'),
        name: requiredString(json, 'name'),
        isActive: requiredBool(json, 'isActive'),
        sortOrder: requiredInt(json, 'sortOrder'),
      );

  final String id;
  final String code;
  final String name;
  final bool isActive;
  final int sortOrder;
}

final class DownloadedFile {
  const DownloadedFile({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
}
