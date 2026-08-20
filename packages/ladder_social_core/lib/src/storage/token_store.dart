import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class StoredTokens {
  const StoredTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

final class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<StoredTokens?> readTokens() async {
    final List<String?> values = await Future.wait<String?>(<Future<String?>>[
      readAccessToken(),
      readRefreshToken(),
    ]);

    final String? accessToken = values[0];
    final String? refreshToken = values[1];
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }

    return StoredTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      // Persist the refresh token first so an interrupted write can still be
      // recovered by the normal session-restoration flow.
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      await _storage.write(key: _accessTokenKey, value: accessToken);
    } catch (_) {
      await clear();
      rethrow;
    }
  }

  Future<void> clear() async {
    await Future.wait<void>(<Future<void>>[
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}
