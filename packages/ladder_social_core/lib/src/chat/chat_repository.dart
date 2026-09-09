import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/chat/chat_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_chat_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_chat_transport.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_models.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/models/paged_json.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/network/api_client.dart';
import 'package:ladder_social_core/src/tasks/task_models.dart';

final class ChatRepository implements E2EChatTransport {
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
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
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

  @override
  Future<E2EDeviceKeyRecord> registerDeviceKey(
    E2EDevicePublicIdentity identity,
  ) async {
    try {
      final Response<dynamic> response = await _client.dio.put<dynamic>(
        '/api/conversations/device-keys',
        data: identity.toRegistrationJson(),
      );
      return E2EDeviceKeyRecord.fromJson(
        jsonMap(response.data, context: 'registered device key'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<PagedResult<E2EDeviceKeyRecord>> getConversationDeviceKeys(
    String conversationId, {
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/conversations/$conversationId/device-keys',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
        },
      );
      return parsePagedResult(response.data, E2EDeviceKeyRecord.fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  @override
  Future<List<E2EDeviceKeyRecord>> getAllConversationDeviceKeys(
    String conversationId,
  ) async {
    const int pageSize = 100;
    var page = 1;
    var totalPages = 1;
    final List<E2EDeviceKeyRecord> items = <E2EDeviceKeyRecord>[];

    do {
      final PagedResult<E2EDeviceKeyRecord> result =
          await getConversationDeviceKeys(
        conversationId,
        page: page,
        pageSize: pageSize,
      );
      items.addAll(result.items);
      totalPages = result.totalPages;
      page++;
    } while (page <= totalPages);

    return List<E2EDeviceKeyRecord>.unmodifiable(items);
  }

  @override
  Future<E2EConversationKeyEnvelopeRecord?> tryGetConversationKeyEnvelope({
    required String conversationId,
    required String recipientDeviceKeyId,
    required int keyVersion,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        '/api/conversations/$conversationId/key-envelopes/'
        '$recipientDeviceKeyId',
        queryParameters: <String, dynamic>{'keyVersion': keyVersion},
      );
      return E2EConversationKeyEnvelopeRecord.fromJson(
        jsonMap(response.data, context: 'conversation key envelope'),
      );
    } on DioException catch (error) {
      final ApiException exception = ApiException.from(error);
      if (exception.statusCode == 404) {
        return null;
      }
      throw exception;
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  @override
  Future<E2EConversationKeyEnvelopeRecord> putConversationKeyEnvelope({
    required String conversationId,
    required E2EConversationKeyEnvelope envelope,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.put<dynamic>(
        '/api/conversations/$conversationId/key-envelopes',
        data: envelope.toRequestJson(),
      );
      return E2EConversationKeyEnvelopeRecord.fromJson(
        jsonMap(response.data, context: 'conversation key envelope'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  @override
  Future<ChatMessage> sendEncryptedText({
    required String conversationId,
    required String senderDeviceKeyId,
    required int keyVersion,
    required E2EEncryptedPayload payload,
  }) async {
    try {
      final FormData form = FormData.fromMap(<String, dynamic>{
        'type': MessageType.text,
        'senderDeviceKeyId': senderDeviceKeyId,
        'keyVersion': keyVersion,
        'encryptedContentBase64': payload.cipherTextWithMacBase64,
        'contentNonceBase64': payload.nonceBase64,
      });
      final Response<dynamic> response = await _client.dio.post<dynamic>(
        '/api/conversations/$conversationId/messages/e2e',
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return ChatMessage.fromJson(
        jsonMap(response.data, context: 'encrypted chat message'),
      );
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
        if (content != null && content.trim().isNotEmpty)
          'content': content.trim(),
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

  Future<void> markRead(String conversationId,
      {String? throughMessageId}) async {
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
