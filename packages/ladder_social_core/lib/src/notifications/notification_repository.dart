import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/models/paged_json.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/network/api_client.dart';
import 'package:ladder_social_core/src/notifications/notification_models.dart';

final class NotificationRepository {
  const NotificationRepository(this._client);
  final ApiClient _client;

  Future<PagedResult<AppNotification>> getNotifications({
    bool? isRead,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/notifications',
        queryParameters: <String, dynamic>{
          if (isRead != null) 'isRead': isRead,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      return parsePagedResult(response.data, AppNotification.fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<NotificationSummary> getSummary() async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/notifications/summary',
      );
      return NotificationSummary.fromJson(
        jsonMap(response.data, context: 'notification summary'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<void> markRead(String id) => _post('/api/notifications/$id/read');
  Future<void> markAllRead() => _post('/api/notifications/read-all');

  Future<void> _post(String path) async {
    try {
      await _client.dio.post<void>(path);
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
