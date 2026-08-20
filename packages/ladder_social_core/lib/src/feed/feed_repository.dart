import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/feed/feed_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/models/paged_json.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/network/api_client.dart';

final class FeedRepository {
  const FeedRepository(this._client);
  final ApiClient _client;

  Future<PagedResult<FeedPost>> getFeed({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/feed',
        queryParameters: <String, dynamic>{
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      return parsePagedResult(response.data, FeedPost.fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<FeedPost> getPost(String id) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>('/api/feed/$id');
      return FeedPost.fromJson(jsonMap(response.data, context: 'feed post'));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<void> markViewed(String id) async {
    try {
      await _client.dio.post<void>('/api/feed/$id/view');
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
