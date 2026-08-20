import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/models/paged_json.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/network/api_client.dart';
import 'package:ladder_social_core/src/tasks/task_models.dart';

final class TaskApiService {
  const TaskApiService(this._client);
  final ApiClient _client;

  Future<PagedResult<TaskListItem>> getTasks(TaskQuery query) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/tasks',
        queryParameters: query.toQueryParameters(),
      );
      return parsePagedResult(response.data, TaskListItem.fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<TaskDetail> getTask(String id) => _getTask('/api/tasks/$id');

  Future<TaskDetail> createTask(TaskDraft draft) async {
    try {
      final Response<dynamic> response = await _client.dio.post<dynamic>(
        '/api/tasks',
        data: draft.toCreateJson(),
      );
      return TaskDetail.fromJson(jsonMap(response.data, context: 'task'));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<TaskDetail> updateTask(String id, TaskDraft draft) async {
    try {
      final Response<dynamic> response = await _client.dio.put<dynamic>(
        '/api/tasks/$id',
        data: draft.toUpdateJson(),
      );
      return TaskDetail.fromJson(jsonMap(response.data, context: 'task'));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _client.dio.delete<void>('/api/tasks/$id');
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<TaskCompletionItem> completeTask({
    required String taskId,
    required DateTime occurrenceDate,
    String? note,
    String? caption,
    ImageUpload? proof,
  }) async {
    try {
      final FormData form = FormData.fromMap(<String, dynamic>{
        'occurrenceDate': dateOnlyString(occurrenceDate),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (caption != null && caption.trim().isNotEmpty)
          'caption': caption.trim(),
        if (proof != null)
          'proofImage': MultipartFile.fromBytes(
            proof.bytes,
            filename: proof.fileName,
            contentType: DioMediaType.parse(proof.contentType),
          ),
      });
      final Response<dynamic> response = await _client.dio.post<dynamic>(
        '/api/tasks/$taskId/complete',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return TaskCompletionItem.fromJson(
        jsonMap(response.data, context: 'task completion'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<PagedResult<TaskCompletionItem>> getCompletions(
    String taskId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/tasks/$taskId/completions',
        queryParameters: <String, dynamic>{'page': page, 'pageSize': pageSize},
      );
      return parsePagedResult(response.data, TaskCompletionItem.fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<TaskDetail> _getTask(String path) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(path);
      return TaskDetail.fromJson(jsonMap(response.data, context: 'task'));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }
}
