import 'dart:convert';

import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

final class E2EDeviceKeyRecord {
  E2EDeviceKeyRecord({
    required this.id,
    required this.userId,
    required this.deviceId,
    required List<int> publicKey,
    required this.createdAtUtc,
    required this.lastSeenAtUtc,
  }) : publicKey = List<int>.unmodifiable(_validatedPublicKey(publicKey));

  factory E2EDeviceKeyRecord.fromJson(Map<String, dynamic> json) =>
      E2EDeviceKeyRecord(
        id: requiredString(json, 'id'),
        userId: requiredString(json, 'userId'),
        deviceId: requiredString(json, 'deviceId'),
        publicKey: _requiredPublicKey(json),
        createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
        lastSeenAtUtc: requiredDateTime(json, 'lastSeenAtUtc'),
      );

  final String id;
  final String userId;
  final String deviceId;
  final List<int> publicKey;
  final DateTime createdAtUtc;
  final DateTime lastSeenAtUtc;

  bool matchesIdentity(E2EDevicePublicIdentity identity) =>
      deviceId == identity.deviceId &&
      _bytesEqual(publicKey, identity.publicKey);

  @override
  String toString() => 'E2EDeviceKeyRecord(id: $id, userId: $userId, '
      'deviceId: $deviceId, publicKey: <redacted>)';
}

final class E2EConversationKeyEnvelopeRecord {
  E2EConversationKeyEnvelopeRecord({
    required this.id,
    required this.conversationId,
    required this.recipientDeviceKeyId,
    required this.senderDeviceKeyId,
    required List<int> encryptedConversationKey,
    required List<int> nonce,
    required this.keyVersion,
    required this.createdAtUtc,
  })  : encryptedConversationKey =
            List<int>.unmodifiable(encryptedConversationKey),
        nonce = List<int>.unmodifiable(nonce);

  factory E2EConversationKeyEnvelopeRecord.fromJson(
    Map<String, dynamic> json,
  ) =>
      E2EConversationKeyEnvelopeRecord(
        id: requiredString(json, 'id'),
        conversationId: requiredString(json, 'conversationId'),
        recipientDeviceKeyId: requiredString(
          json,
          'recipientDeviceKeyId',
        ),
        senderDeviceKeyId: requiredString(json, 'senderDeviceKeyId'),
        encryptedConversationKey: _requiredBase64Bytes(
          json,
          'encryptedConversationKey',
        ),
        nonce: _requiredBase64Bytes(json, 'nonce'),
        keyVersion: requiredInt(json, 'keyVersion'),
        createdAtUtc: requiredDateTime(json, 'createdAtUtc'),
      );

  final String id;
  final String conversationId;
  final String recipientDeviceKeyId;
  final String senderDeviceKeyId;
  final List<int> encryptedConversationKey;
  final List<int> nonce;
  final int keyVersion;
  final DateTime createdAtUtc;

  E2EConversationKeyEnvelope toCryptoEnvelope() => E2EConversationKeyEnvelope(
        context: E2EEnvelopeContext(
          conversationId: conversationId,
          senderDeviceKeyId: senderDeviceKeyId,
          recipientDeviceKeyId: recipientDeviceKeyId,
          keyVersion: keyVersion,
        ),
        payload: E2EEncryptedPayload(
          cipherTextWithMac: encryptedConversationKey,
          nonce: nonce,
        ),
      );

  @override
  String toString() => 'E2EConversationKeyEnvelopeRecord(id: $id, '
      'conversationId: $conversationId, keyVersion: $keyVersion, '
      'payload: <redacted>)';
}

final class E2EConversationReadyState {
  const E2EConversationReadyState({
    required this.conversationId,
    required this.currentDeviceKeyId,
    required this.keyVersion,
    required this.activeDeviceCount,
  });

  final String conversationId;
  final String currentDeviceKeyId;
  final int keyVersion;
  final int activeDeviceCount;
}

List<int> _requiredPublicKey(Map<String, dynamic> json) {
  final List<int> publicKey = _requiredBase64Bytes(json, 'publicKey');
  if (publicKey.length != E2ECryptoConstants.x25519KeyBytes ||
      publicKey.every((int byte) => byte == 0)) {
    throw const FormatException(
      'Server response contains an invalid X25519 public key.',
    );
  }
  return publicKey;
}

List<int> _validatedPublicKey(List<int> publicKey) {
  if (publicKey.length != E2ECryptoConstants.x25519KeyBytes) {
    throw ArgumentError.value(
      publicKey.length,
      'publicKey',
      'X25519 public key must contain exactly '
          '${E2ECryptoConstants.x25519KeyBytes} bytes.',
    );
  }
  if (publicKey.every((int byte) => byte == 0)) {
    throw ArgumentError.value(
      publicKey,
      'publicKey',
      'X25519 public key may not be the all-zero value.',
    );
  }
  return publicKey;
}

List<int> _requiredBase64Bytes(
  Map<String, dynamic> json,
  String fieldName,
) {
  final String encoded = requiredString(json, fieldName);
  try {
    return base64Decode(encoded);
  } on FormatException catch (error) {
    throw FormatException(
      'Server response contains invalid Base64 in "$fieldName": '
      '${error.message}',
    );
  }
}

bool _bytesEqual(List<int> first, List<int> second) {
  if (first.length != second.length) {
    return false;
  }
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }
  return true;
}
