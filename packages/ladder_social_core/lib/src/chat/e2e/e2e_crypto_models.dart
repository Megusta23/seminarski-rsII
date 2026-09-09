import 'dart:convert';
import 'dart:typed_data';

abstract final class E2ECryptoConstants {
  static const int protocolVersion = 1;
  static const int x25519KeyBytes = 32;
  static const int conversationKeyBytes = 32;
  static const int nonceBytes = 12;
  static const int authenticationTagBytes = 16;
  static const int wrappedConversationKeyBytes =
      conversationKeyBytes + authenticationTagBytes;
  static const int maximumEncryptedTextBytes = 20 * 1024;
  static const int maximumPlainTextBytes =
      maximumEncryptedTextBytes - authenticationTagBytes;
  static const int maximumEncryptedMediaBytes = 25 * 1024 * 1024;
  static const int maximumPlainMediaBytes =
      maximumEncryptedMediaBytes - authenticationTagBytes;
  static const int maximumMediaDurationMilliseconds = 60 * 60 * 1000;
  static const String encryptedMediaContentType = 'application/octet-stream';
}

enum E2EPrivateMessageType {
  text(1),
  image(2),
  voice(4),
  video(5);

  const E2EPrivateMessageType(this.wireValue);

  final int wireValue;

  static E2EPrivateMessageType fromWireValue(int value) {
    for (final E2EPrivateMessageType type in values) {
      if (type.wireValue == value) {
        return type;
      }
    }

    throw FormatException('Unsupported private E2E message type: $value.');
  }
}

final class E2EDevicePublicIdentity {
  E2EDevicePublicIdentity({
    required String deviceId,
    required List<int> publicKey,
  })  : deviceId = _validateDeviceId(deviceId),
        _publicKey = _validatedBytes(
          publicKey,
          expectedLength: E2ECryptoConstants.x25519KeyBytes,
          fieldName: 'publicKey',
          rejectAllZero: true,
        );

  final String deviceId;
  final Uint8List _publicKey;

  Uint8List get publicKey => Uint8List.fromList(_publicKey);

  Map<String, Object> toRegistrationJson() => <String, Object>{
        'deviceId': deviceId,
        'publicKey': base64Encode(_publicKey),
      };

  @override
  String toString() =>
      'E2EDevicePublicIdentity(deviceId: $deviceId, publicKey: <redacted>)';
}

final class E2EConversationKey {
  E2EConversationKey(List<int> bytes)
      : _bytes = _validatedBytes(
          bytes,
          expectedLength: E2ECryptoConstants.conversationKeyBytes,
          fieldName: 'conversationKey',
        );

  final Uint8List _bytes;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  @override
  String toString() => 'E2EConversationKey(<redacted>)';
}

final class E2EEncryptedPayload {
  E2EEncryptedPayload({
    required List<int> cipherTextWithMac,
    required List<int> nonce,
  })  : _cipherTextWithMac = _validateCipherText(cipherTextWithMac),
        _nonce = _validatedBytes(
          nonce,
          expectedLength: E2ECryptoConstants.nonceBytes,
          fieldName: 'nonce',
        );

  factory E2EEncryptedPayload.fromBase64({
    required String cipherTextWithMac,
    required String nonce,
  }) =>
      E2EEncryptedPayload(
        cipherTextWithMac: base64Decode(cipherTextWithMac),
        nonce: base64Decode(nonce),
      );

  final Uint8List _cipherTextWithMac;
  final Uint8List _nonce;

  Uint8List get cipherTextWithMac => Uint8List.fromList(_cipherTextWithMac);
  Uint8List get nonce => Uint8List.fromList(_nonce);

  String get cipherTextWithMacBase64 => base64Encode(_cipherTextWithMac);
  String get nonceBase64 => base64Encode(_nonce);

  @override
  String toString() => 'E2EEncryptedPayload(cipherTextWithMacBytes: '
      '${_cipherTextWithMac.length}, nonceBytes: ${_nonce.length})';
}

final class E2EEnvelopeContext {
  E2EEnvelopeContext({
    required String conversationId,
    required String senderDeviceKeyId,
    required String recipientDeviceKeyId,
    required this.keyVersion,
  })  : conversationId = _validateIdentifier(
          conversationId,
          fieldName: 'conversationId',
        ),
        senderDeviceKeyId = _validateIdentifier(
          senderDeviceKeyId,
          fieldName: 'senderDeviceKeyId',
        ),
        recipientDeviceKeyId = _validateIdentifier(
          recipientDeviceKeyId,
          fieldName: 'recipientDeviceKeyId',
        ) {
    if (keyVersion < 1) {
      throw ArgumentError.value(
        keyVersion,
        'keyVersion',
        'Key version must be greater than zero.',
      );
    }
  }

  final String conversationId;
  final String senderDeviceKeyId;
  final String recipientDeviceKeyId;
  final int keyVersion;
}

final class E2EConversationKeyEnvelope {
  E2EConversationKeyEnvelope({
    required this.context,
    required E2EEncryptedPayload payload,
  }) : _payload = _validateEnvelopePayload(payload);

  final E2EEnvelopeContext context;
  final E2EEncryptedPayload _payload;

  E2EEncryptedPayload get payload => E2EEncryptedPayload(
        cipherTextWithMac: _payload._cipherTextWithMac,
        nonce: _payload._nonce,
      );

  Map<String, Object> toRequestJson() => <String, Object>{
        'recipientDeviceKeyId': context.recipientDeviceKeyId,
        'senderDeviceKeyId': context.senderDeviceKeyId,
        'encryptedConversationKey': _payload.cipherTextWithMacBase64,
        'nonce': _payload.nonceBase64,
        'keyVersion': context.keyVersion,
      };

  @override
  String toString() =>
      'E2EConversationKeyEnvelope(keyVersion: ${context.keyVersion}, '
      'payload: $_payload)';
}

String _validateDeviceId(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 128) {
    throw ArgumentError.value(
      value,
      'deviceId',
      'Device ID must contain between 1 and 128 characters.',
    );
  }
  if (normalized.runes.any((int rune) => rune < 0x20 || rune == 0x7f)) {
    throw ArgumentError.value(
      value,
      'deviceId',
      'Device ID may not contain control characters.',
    );
  }
  return normalized;
}

String _validateIdentifier(String value, {required String fieldName}) {
  final String normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, fieldName, '$fieldName is required.');
  }
  return normalized;
}

Uint8List _validatedBytes(
  List<int> value, {
  required int expectedLength,
  required String fieldName,
  bool rejectAllZero = false,
}) {
  if (value.length != expectedLength) {
    throw ArgumentError.value(
      value.length,
      fieldName,
      '$fieldName must contain exactly $expectedLength bytes.',
    );
  }

  final Uint8List result = Uint8List.fromList(value);
  if (rejectAllZero && result.every((int byte) => byte == 0)) {
    throw ArgumentError.value(
      value,
      fieldName,
      '$fieldName may not be the all-zero value.',
    );
  }
  return result;
}

Uint8List _validateCipherText(List<int> value) {
  if (value.length <= E2ECryptoConstants.authenticationTagBytes) {
    throw ArgumentError.value(
      value.length,
      'cipherTextWithMac',
      'Ciphertext must contain encrypted bytes and a 16-byte '
          'authentication tag.',
    );
  }
  return Uint8List.fromList(value);
}

E2EEncryptedPayload _validateEnvelopePayload(E2EEncryptedPayload value) {
  if (value._cipherTextWithMac.length !=
      E2ECryptoConstants.wrappedConversationKeyBytes) {
    throw ArgumentError.value(
      value._cipherTextWithMac.length,
      'payload',
      'Wrapped conversation key must contain exactly '
          '${E2ECryptoConstants.wrappedConversationKeyBytes} bytes.',
    );
  }
  return E2EEncryptedPayload(
    cipherTextWithMac: value._cipherTextWithMac,
    nonce: value._nonce,
  );
}
