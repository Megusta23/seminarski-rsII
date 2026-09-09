import 'dart:typed_data';

import 'package:ladder_social_core/src/chat/chat_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_chat_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_models.dart';

typedef E2ETransferProgress = void Function(
    int transferredBytes, int totalBytes);

abstract interface class E2EChatTransport {
  Future<E2EDeviceKeyRecord> registerDeviceKey(
    E2EDevicePublicIdentity identity,
  );

  Future<List<E2EDeviceKeyRecord>> getAllConversationDeviceKeys(
    String conversationId,
  );

  Future<E2EConversationKeyEnvelopeRecord?> tryGetConversationKeyEnvelope({
    required String conversationId,
    required String recipientDeviceKeyId,
    required int keyVersion,
  });

  Future<E2EConversationKeyEnvelopeRecord> putConversationKeyEnvelope({
    required String conversationId,
    required E2EConversationKeyEnvelope envelope,
  });

  Future<ChatMessage> sendEncryptedText({
    required String conversationId,
    required String senderDeviceKeyId,
    required int keyVersion,
    required E2EEncryptedPayload payload,
  });

  Future<ChatMessage> sendEncryptedMedia({
    required String conversationId,
    required String senderDeviceKeyId,
    required int keyVersion,
    required E2EPrivateMessageType type,
    required E2EEncryptedPayload payload,
    int? durationMilliseconds,
    E2ETransferProgress? onUploadProgress,
  });

  Future<Uint8List> downloadEncryptedAttachment(String attachmentUrl);
}
