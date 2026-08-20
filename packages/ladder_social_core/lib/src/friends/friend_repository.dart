import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/friends/friend_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/models/paged_json.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/network/api_client.dart';

final class FriendRepository {
  const FriendRepository(this._client);
  final ApiClient _client;

  Future<PagedResult<FriendSummary>> getFriends({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) => _getPage(
        '/api/friends',
        FriendSummary.fromJson,
        search: search,
        page: page,
        pageSize: pageSize,
      );

  Future<PagedResult<UserSearchItem>> searchUsers({
    String? search,
    bool excludeExistingRelationships = true,
    int page = 1,
    int pageSize = 20,
  }) => _getPage(
        '/api/friends/search',
        UserSearchItem.fromJson,
        search: search,
        page: page,
        pageSize: pageSize,
        extra: <String, dynamic>{
          'excludeExistingRelationships': excludeExistingRelationships,
        },
      );

  Future<PagedResult<FriendRequestItem>> getIncomingRequests({
    int page = 1,
    int pageSize = 20,
  }) => _getPage(
        '/api/friends/requests/incoming',
        FriendRequestItem.fromJson,
        page: page,
        pageSize: pageSize,
      );

  Future<PagedResult<FriendRequestItem>> getOutgoingRequests({
    int page = 1,
    int pageSize = 20,
  }) => _getPage(
        '/api/friends/requests/outgoing',
        FriendRequestItem.fromJson,
        page: page,
        pageSize: pageSize,
      );

  Future<FriendRequestItem> sendRequest(String receiverUserId) async {
    try {
      final Response<dynamic> response = await _client.dio.post<dynamic>(
        '/api/friends/requests/$receiverUserId',
      );
      return FriendRequestItem.fromJson(
        jsonMap(response.data, context: 'friend request'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<void> acceptRequest(String requestId) =>
      _postAction('/api/friends/requests/$requestId/accept');
  Future<void> rejectRequest(String requestId) =>
      _postAction('/api/friends/requests/$requestId/reject');
  Future<void> cancelRequest(String requestId) =>
      _postAction('/api/friends/requests/$requestId/cancel');

  Future<void> removeFriend(String friendUserId) async {
    try {
      await _client.dio.delete<void>('/api/friends/$friendUserId');
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<FriendProfile> getProfile(String userId) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/friends/$userId/profile',
      );
      return FriendProfile.fromJson(
        jsonMap(response.data, context: 'friend profile'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<List<FriendRecommendation>> getRecommendations() async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/friends/recommendations',
      );
      return List<FriendRecommendation>.unmodifiable(
        jsonList(response.data, context: 'recommendations').map(
          (Object? item) => FriendRecommendation.fromJson(
            jsonMap(item, context: 'recommendation'),
          ),
        ),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<PagedResult<T>> _getPage<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    String? search,
    int page = 1,
    int pageSize = 20,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        path,
        queryParameters: <String, dynamic>{
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          'page': page,
          'pageSize': pageSize,
          ...?extra,
        },
      );
      return parsePagedResult(response.data, fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<void> _postAction(String path) async {
    try {
      await _client.dio.post<void>(path);
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
