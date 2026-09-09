import 'dart:convert';

import 'package:ladder_social_core/src/chat/e2e/e2e_chat_models.dart';
import 'package:ladder_social_core/src/chat/e2e/e2e_secure_storage.dart';

class E2EKeyTrustException implements Exception {
  const E2EKeyTrustException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class E2EPeerKeyTrustStore {
  Future<void> verifyOrTrust({
    required String currentUserId,
    required E2EDeviceKeyRecord peerDevice,
  });
}

final class SecureE2EPeerKeyTrustStore implements E2EPeerKeyTrustStore {
  SecureE2EPeerKeyTrustStore({E2ESecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? FlutterE2ESecureStorage();

  static const String _trustPrefix = 'ladder_social.e2e.peer_key.v1';

  final E2ESecureStorage _secureStorage;

  @override
  Future<void> verifyOrTrust({
    required String currentUserId,
    required E2EDeviceKeyRecord peerDevice,
  }) async {
    final String storageKey = _storageKey(
      currentUserId: currentUserId,
      peerUserId: peerDevice.userId,
      peerDeviceId: peerDevice.deviceId,
    );
    final String encodedPublicKey = base64Encode(peerDevice.publicKey);
    final String? trusted = await _secureStorage.read(storageKey);

    if (trusted == null) {
      await _secureStorage.write(storageKey, encodedPublicKey);
      return;
    }
    if (trusted.isEmpty) {
      throw const E2EKeyTrustException(
        'Security check failed: the stored peer-key pin is corrupted.',
      );
    }

    if (trusted != encodedPublicKey) {
      throw E2EKeyTrustException(
        'Security check failed: the public key for device '
        '"${peerDevice.deviceId}" changed. The key was not accepted '
        'automatically.',
      );
    }
  }

  String _storageKey({
    required String currentUserId,
    required String peerUserId,
    required String peerDeviceId,
  }) =>
      '$_trustPrefix.${_token(currentUserId)}.${_token(peerUserId)}.'
      '${_token(peerDeviceId)}';

  String _token(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
          value, 'value', 'Trust identifier is required.');
    }
    return base64UrlEncode(utf8.encode(normalized)).replaceAll('=', '');
  }
}
