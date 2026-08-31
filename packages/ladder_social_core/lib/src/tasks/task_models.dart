import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

abstract final class TaskStatus {
  static const int active = 1;
  static const int completed = 2;
  static const int cancelled = 3;
  static const int archived = 4;

  static String label(int value) => switch (value) {
        active => 'Active',
        completed => 'Completed',
        cancelled => 'Cancelled',
        archived => 'Archived',
        _ => 'Unknown',
      };
}

final class TaskListItem {
  const TaskListItem({
    required this.id,
    required this.title,
    required this.categoryName,
    required this.categoryCode,
    required this.recurrenceName,
    required this.recurrenceCode,
    required this.status,
    required this.requiresProofImage,
    required this.shareWithFriends,
    required this.isCompletedForToday,
    required this.canCompleteForToday,
    required this.businessDate,
    required this.createdAtUtc,
    this.dueAtUtc,
  });

  factory TaskListItem.fromJson(Map<String, dynamic> json) => TaskListItem(
        id: requiredString(json, 'id'),
        title: requiredString(json, 'title'),
        categoryName: requiredString(json, 'categoryName'),
        categoryCode: requiredString(json, 'categoryCode'),
        recurrenceName: requiredString(json, 'recurrenceName'),
        recurrenceCode: requiredString(json, 'recurrenceCode'),
        dueAtUtc: nullableDateTime(json['dueAtUtc']),
        status: requiredInt(json, 'status'),
        requiresProofImage: requiredBool(json, 'requiresProofImage'),
        shareWithFriends: requiredBool(json, 'shareWithFriends'),
        isCompletedForToday: requiredBool(json, 'isCompletedForToday'),
        canCompleteForToday: requiredBool(json, 'canCompleteForToday'),
        businessDate: _requiredDateOnly(json, 'businessDate'),
        createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
      );

  final String id;
  final String title;
  final String categoryName;
  final String categoryCode;
  final String recurrenceName;
  final String recurrenceCode;
  final DateTime? dueAtUtc;
  final int status;
  final bool requiresProofImage;
  final bool shareWithFriends;
  final bool isCompletedForToday;
  final bool canCompleteForToday;
  final DateTime businessDate;
  final DateTime createdAtUtc;
}

final class TaskCompletionItem {
  const TaskCompletionItem({
    required this.id,
    required this.taskId,
    required this.occurrenceDate,
    required this.completedAtUtc,
    required this.scorePoints,
    this.note,
    this.proofMediaId,
    this.proofUrl,
    this.postId,
  });

  factory TaskCompletionItem.fromJson(Map<String, dynamic> json) {
    return TaskCompletionItem(
      id: requiredString(json, 'id'),
      taskId: requiredString(json, 'taskId'),
      occurrenceDate: _requiredDateOnly(json, 'occurrenceDate'),
      completedAtUtc: requiredDateTime(json, 'completedAtUtc'),
      note: nullableString(json['note']),
      scorePoints: requiredInt(json, 'scorePoints'),
      proofMediaId: nullableString(json['proofMediaId']),
      proofUrl: nullableString(json['proofUrl']),
      postId: nullableString(json['postId']),
    );
  }

  final String id;
  final String taskId;
  final DateTime occurrenceDate;
  final DateTime completedAtUtc;
  final String? note;
  final int scorePoints;
  final String? proofMediaId;
  final String? proofUrl;
  final String? postId;
}

final class TaskDetail {
  const TaskDetail({
    required this.id,
    required this.title,
    required this.taskCategoryId,
    required this.categoryName,
    required this.categoryCode,
    required this.recurrenceTypeId,
    required this.recurrenceName,
    required this.recurrenceCode,
    required this.status,
    required this.requiresProofImage,
    required this.shareWithFriends,
    required this.createdAtUtc,
    required this.businessDate,
    required this.canEdit,
    required this.canComplete,
    required this.allowedEditStatuses,
    required this.recentCompletions,
    this.description,
    this.dueAtUtc,
    this.updatedAtUtc,
  });

  factory TaskDetail.fromJson(Map<String, dynamic> json) => TaskDetail(
        id: requiredString(json, 'id'),
        title: requiredString(json, 'title'),
        description: nullableString(json['description']),
        taskCategoryId: requiredString(json, 'taskCategoryId'),
        categoryName: requiredString(json, 'categoryName'),
        categoryCode: requiredString(json, 'categoryCode'),
        recurrenceTypeId: requiredString(json, 'recurrenceTypeId'),
        recurrenceName: requiredString(json, 'recurrenceName'),
        recurrenceCode: requiredString(json, 'recurrenceCode'),
        dueAtUtc: nullableDateTime(json['dueAtUtc']),
        status: requiredInt(json, 'status'),
        requiresProofImage: requiredBool(json, 'requiresProofImage'),
        shareWithFriends: requiredBool(json, 'shareWithFriends'),
        createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
        updatedAtUtc: nullableDateTime(json['updatedAtUtc']),
        businessDate: _requiredDateOnly(json, 'businessDate'),
        canEdit: requiredBool(json, 'canEdit'),
        canComplete: requiredBool(json, 'canComplete'),
        allowedEditStatuses: List<int>.unmodifiable(
          jsonList(
            json['allowedEditStatuses'],
            context: 'allowed task statuses',
          ).map(_intValue),
        ),
        recentCompletions: List<TaskCompletionItem>.unmodifiable(
          jsonList(json['recentCompletions'], context: 'task completions')
              .map((Object? item) => TaskCompletionItem.fromJson(
                    jsonMap(item, context: 'task completion'),
                  )),
        ),
      );

  final String id;
  final String title;
  final String? description;
  final String taskCategoryId;
  final String categoryName;
  final String categoryCode;
  final String recurrenceTypeId;
  final String recurrenceName;
  final String recurrenceCode;
  final DateTime? dueAtUtc;
  final int status;
  final bool requiresProofImage;
  final bool shareWithFriends;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final DateTime businessDate;
  final bool canEdit;
  final bool canComplete;
  final List<int> allowedEditStatuses;
  final List<TaskCompletionItem> recentCompletions;
}

final class CompletionDateOptions {
  const CompletionDateOptions({
    required this.businessDate,
    required this.recurrenceAnchorDate,
    required this.recurrenceCode,
    required this.allowedDates,
  });

  factory CompletionDateOptions.fromJson(Map<String, dynamic> json) =>
      CompletionDateOptions(
        businessDate: _requiredDateOnly(json, 'businessDate'),
        recurrenceAnchorDate:
            _requiredDateOnly(json, 'recurrenceAnchorDate'),
        recurrenceCode: requiredString(json, 'recurrenceCode'),
        allowedDates: List<DateTime>.unmodifiable(
          jsonList(json['allowedDates'], context: 'completion dates').map(
            (Object? value) => _parseDateOnly(
              value,
              fieldName: 'allowedDates',
            ),
          ),
        ),
      );

  final DateTime businessDate;
  final DateTime recurrenceAnchorDate;
  final String recurrenceCode;
  final List<DateTime> allowedDates;
}

final class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.taskCategoryId,
    required this.recurrenceTypeId,
    required this.requiresProofImage,
    required this.shareWithFriends,
    this.description,
    this.dueAtUtc,
    this.status = TaskStatus.active,
  });

  final String title;
  final String? description;
  final String taskCategoryId;
  final String recurrenceTypeId;
  final DateTime? dueAtUtc;
  final bool requiresProofImage;
  final bool shareWithFriends;
  final int status;

  Map<String, dynamic> toCreateJson() => <String, dynamic>{
        'title': title.trim(),
        'description': _optional(description),
        'taskCategoryId': taskCategoryId,
        'recurrenceTypeId': recurrenceTypeId,
        'dueAtUtc': dueAtUtc?.toUtc().toIso8601String(),
        'requiresProofImage': requiresProofImage,
        'shareWithFriends': shareWithFriends,
      };

  Map<String, dynamic> toUpdateJson() => <String, dynamic>{
        ...toCreateJson(),
        'status': status,
      };

  static String? _optional(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final class TaskQuery {
  const TaskQuery({
    this.search,
    this.categoryId,
    this.recurrenceTypeId,
    this.status,
    this.dueFromUtc,
    this.dueToUtc,
    this.page = 1,
    this.pageSize = 20,
    this.sortBy,
    this.sortDirection,
  });

  final String? search;
  final String? categoryId;
  final String? recurrenceTypeId;
  final int? status;
  final DateTime? dueFromUtc;
  final DateTime? dueToUtc;
  final int page;
  final int pageSize;
  final String? sortBy;
  final String? sortDirection;

  Map<String, dynamic> toQueryParameters() => <String, dynamic>{
        if (search != null && search!.trim().isNotEmpty) 'search': search!.trim(),
        if (categoryId != null) 'categoryId': categoryId,
        if (recurrenceTypeId != null) 'recurrenceTypeId': recurrenceTypeId,
        if (status != null) 'status': status,
        if (dueFromUtc != null) 'dueFromUtc': dueFromUtc!.toUtc().toIso8601String(),
        if (dueToUtc != null) 'dueToUtc': dueToUtc!.toUtc().toIso8601String(),
        'page': page,
        'pageSize': pageSize,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortDirection != null) 'sortDirection': sortDirection,
      };
}

final class ImageUpload {
  const ImageUpload({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final List<int> bytes;
  final String fileName;
  final String contentType;
}

DateTime _requiredDateOnly(Map<String, dynamic> json, String key) =>
    _parseDateOnly(json[key], fieldName: key);

DateTime _parseDateOnly(Object? value, {required String fieldName}) {
  final String text = value?.toString() ?? '';
  final DateTime? parsed = DateTime.tryParse(text);
  if (parsed == null) {
    throw FormatException(
      'Server response is missing a valid "$fieldName" date.',
    );
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  final int? parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw const FormatException(
      'Server response contains an invalid task status.',
    );
  }
  return parsed;
}
