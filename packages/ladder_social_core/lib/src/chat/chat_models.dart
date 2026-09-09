import 'dart:convert';

import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

abstract final class MessageType {
  static const int text = 1;
  static const int image = 2;
  static const int system = 3;
  static const int voice = 4;
  static const int video = 5;
}

abstract final class ChatEncryptionVersion {
  static const int legacyPlaintext = 0;
  static const int clientE2E = 1;
}

final class ConversationParticipant {
  const ConversationParticipant({
    required this.userId,
    required this.displayName,
    required this.isCurrentUser,
    this.avatarUrl,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) =>
      ConversationParticipant(
        userId: requiredString(json, 'userId'),
        displayName: requiredString(json, 'displayName'),
        avatarUrl: nullableString(json['avatarUrl']),
        isCurrentUser: requiredBool(json, 'isCurrentUser'),
      );

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isCurrentUser;
}

final class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.displayTitle,
    required this.isGroup,
    required this.canSendMessages,
    required this.unreadCount,
    required this.participants,
    this.lastMessageAtUtc,
    this.lastMessagePreview,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) =>
      ConversationItem(
        id: requiredString(json, 'id'),
        displayTitle: requiredString(json, 'displayTitle'),
        isGroup: requiredBool(json, 'isGroup'),
        canSendMessages: requiredBool(json, 'canSendMessages'),
        lastMessageAtUtc: nullableDateTime(json['lastMessageAtUtc']),
        lastMessagePreview: nullableString(json['lastMessagePreview']),
        unreadCount: requiredInt(json, 'unreadCount'),
        participants: List<ConversationParticipant>.unmodifiable(
          jsonList(json['participants'], context: 'conversation participants')
              .map(
            (Object? item) => ConversationParticipant.fromJson(
              jsonMap(item, context: 'conversation participant'),
            ),
          ),
        ),
      );

  final String id;
  final String displayTitle;
  final bool isGroup;
  final bool canSendMessages;
  final DateTime? lastMessageAtUtc;
  final String? lastMessagePreview;
  final int unreadCount;
  final List<ConversationParticipant> participants;
}

final class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.type,
    required this.sentAtUtc,
    required this.encryptionVersion,
    this.content,
    List<int>? encryptedContent,
    List<int>? contentNonce,
    this.keyVersion,
    this.attachmentId,
    this.attachmentUrl,
    this.attachmentMimeType,
    List<int>? attachmentNonce,
    this.attachmentEncryptionVersion,
    this.attachmentKeyVersion,
    this.attachmentSizeBytes,
    this.attachmentDurationMilliseconds,
    this.decryptedContent,
    this.decryptionError,
  })  : encryptedContent = encryptedContent == null
            ? null
            : List<int>.unmodifiable(encryptedContent),
        contentNonce =
            contentNonce == null ? null : List<int>.unmodifiable(contentNonce),
        attachmentNonce = attachmentNonce == null
            ? null
            : List<int>.unmodifiable(attachmentNonce);

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final int encryptionVersion = requiredInt(json, 'encryptionVersion');
    final String? content = nullableString(json['content']);
    if (encryptionVersion == ChatEncryptionVersion.clientE2E &&
        content != null) {
      throw const FormatException(
        'An E2E message response may not contain plaintext content.',
      );
    }

    return ChatMessage(
      id: requiredString(json, 'id'),
      conversationId: requiredString(json, 'conversationId'),
      senderUserId: requiredString(json, 'senderUserId'),
      senderDisplayName: requiredString(json, 'senderDisplayName'),
      type: requiredInt(json, 'type'),
      content: content,
      encryptedContent: _nullableBase64Bytes(
        json['encryptedContent'],
        fieldName: 'encryptedContent',
      ),
      contentNonce: _nullableBase64Bytes(
        json['contentNonce'],
        fieldName: 'contentNonce',
      ),
      encryptionVersion: encryptionVersion,
      keyVersion: _nullableInt(json['keyVersion'], fieldName: 'keyVersion'),
      sentAtUtc: requiredDateTime(json, 'sentAtUtc'),
      attachmentId: nullableString(json['attachmentId']),
      attachmentUrl: nullableString(json['attachmentUrl']),
      attachmentMimeType: nullableString(json['attachmentMimeType']),
      attachmentNonce: _nullableBase64Bytes(
        json['attachmentNonce'],
        fieldName: 'attachmentNonce',
      ),
      attachmentEncryptionVersion: _nullableInt(
        json['attachmentEncryptionVersion'],
        fieldName: 'attachmentEncryptionVersion',
      ),
      attachmentKeyVersion: _nullableInt(
        json['attachmentKeyVersion'],
        fieldName: 'attachmentKeyVersion',
      ),
      attachmentSizeBytes: _nullableInt(
        json['attachmentSizeBytes'],
        fieldName: 'attachmentSizeBytes',
      ),
      attachmentDurationMilliseconds: _nullableInt(
        json['attachmentDurationMilliseconds'],
        fieldName: 'attachmentDurationMilliseconds',
      ),
    );
  }

  final String id;
  final String conversationId;
  final String senderUserId;
  final String senderDisplayName;
  final int type;
  final String? content;
  final List<int>? encryptedContent;
  final List<int>? contentNonce;
  final int encryptionVersion;
  final int? keyVersion;
  final DateTime sentAtUtc;
  final String? attachmentId;
  final String? attachmentUrl;
  final String? attachmentMimeType;
  final List<int>? attachmentNonce;
  final int? attachmentEncryptionVersion;
  final int? attachmentKeyVersion;
  final int? attachmentSizeBytes;
  final int? attachmentDurationMilliseconds;
  final String? decryptedContent;
  final String? decryptionError;

  bool get isE2E => encryptionVersion == ChatEncryptionVersion.clientE2E;

  bool get isLegacy =>
      encryptionVersion == ChatEncryptionVersion.legacyPlaintext;

  String? get visibleContent => isLegacy ? content : decryptedContent;

  ChatMessage withDecryptedContent(String value) => _copyWith(
        decryptedContent: value,
        clearDecryptionError: true,
      );

  ChatMessage withDecryptionError(String value) => _copyWith(
        decryptionError: value,
        clearDecryptedContent: true,
      );

  ChatMessage _copyWith({
    String? decryptedContent,
    String? decryptionError,
    bool clearDecryptedContent = false,
    bool clearDecryptionError = false,
  }) =>
      ChatMessage(
        id: id,
        conversationId: conversationId,
        senderUserId: senderUserId,
        senderDisplayName: senderDisplayName,
        type: type,
        content: content,
        encryptedContent: encryptedContent,
        contentNonce: contentNonce,
        encryptionVersion: encryptionVersion,
        keyVersion: keyVersion,
        sentAtUtc: sentAtUtc,
        attachmentId: attachmentId,
        attachmentUrl: attachmentUrl,
        attachmentMimeType: attachmentMimeType,
        attachmentNonce: attachmentNonce,
        attachmentEncryptionVersion: attachmentEncryptionVersion,
        attachmentKeyVersion: attachmentKeyVersion,
        attachmentSizeBytes: attachmentSizeBytes,
        attachmentDurationMilliseconds: attachmentDurationMilliseconds,
        decryptedContent: clearDecryptedContent
            ? null
            : decryptedContent ?? this.decryptedContent,
        decryptionError: clearDecryptionError
            ? null
            : decryptionError ?? this.decryptionError,
      );
}

List<int>? _nullableBase64Bytes(
  Object? value, {
  required String fieldName,
}) {
  final String? encoded = nullableString(value);
  if (encoded == null) {
    return null;
  }

  try {
    return base64Decode(encoded);
  } on FormatException catch (error) {
    throw FormatException(
      'Server response contains invalid Base64 in "$fieldName": '
      '${error.message}',
    );
  }
}

int? _nullableInt(Object? value, {required String fieldName}) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }

  final int? parsed = int.tryParse(value.toString());
  if (parsed == null) {
    throw FormatException(
      'Server response contains an invalid "$fieldName" value.',
    );
  }
  return parsed;
}
