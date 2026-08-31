import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/chat/chat_models.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/models/paged_json.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/network/api_client.dart';
import 'package:ladder_social_core/src/tasks/task_models.dart';

final class ChatRepository {
  const ChatRepository(this._client);
  final ApiClient _client;

  Future<PagedResult<ConversationItem>> getConversations({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/conversations',
        queryParameters: <String, dynamic>{
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      return parsePagedResult(response.data, ConversationItem.fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<ConversationItem> startDirectConversation(String friendUserId) async {
    try {
      final Response<dynamic> response = await _client.dio.post<dynamic>(
        '/api/conversations/direct/$friendUserId',
      );
      return ConversationItem.fromJson(
        jsonMap(response.data, context: 'conversation'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<ConversationItem> getConversation(String conversationId) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/conversations/$conversationId',
      );
      return ConversationItem.fromJson(
        jsonMap(response.data, context: 'conversation'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<PagedResult<ChatMessage>> getMessages(
    String conversationId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/conversations/$conversationId/messages',
        queryParameters: <String, dynamic>{'page': page, 'pageSize': pageSize},
      );
      return parsePagedResult(response.data, ChatMessage.fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    String? content,
    ImageUpload? attachment,
  }) async {
    try {
      final FormData form = FormData.fromMap(<String, dynamic>{
        if (content != null && content.trim().isNotEmpty) 'content': content.trim(),
        if (attachment != null)
          'attachment': MultipartFile.fromBytes(
            attachment.bytes,
            filename: attachment.fileName,
            contentType: DioMediaType.parse(attachment.contentType),
          ),
      });
      final Response<dynamic> response = await _client.dio.post<dynamic>(
        '/api/conversations/$conversationId/messages',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return ChatMessage.fromJson(
        jsonMap(response.data, context: 'chat message'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<void> markRead(String conversationId, {String? throughMessageId}) async {
    try {
      await _client.dio.post<void>(
        '/api/conversations/$conversationId/read',
        queryParameters: <String, dynamic>{
          if (throughMessageId != null) 'throughMessageId': throughMessageId,
        },
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }
}
