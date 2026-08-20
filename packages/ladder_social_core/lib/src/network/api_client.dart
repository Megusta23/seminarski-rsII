import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/storage/token_store.dart';

final class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStore tokenStore,
  })  : _tokenStore = tokenStore,
        dio = Dio(_createOptions(baseUrl)),
        _refreshDio = Dio(_createOptions(baseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _attachAccessToken,
        onError: _handleError,
      ),
    );
  }

  static const String _retryExtraKey = 'ladder_auth_retried';

  final Dio dio;

  String get baseUrl => dio.options.baseUrl;

  String absoluteUrl(String path) {
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(baseUrl).resolve(normalizedPath).toString();
  }
  final Dio _refreshDio;
  final TokenStore _tokenStore;

  Future<bool>? _refreshInFlight;
  Future<void> Function()? _onUnauthorized;

  void setUnauthorizedHandler(Future<void> Function() handler) {
    _onUnauthorized = handler;
  }

  Future<void> _attachAccessToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublicAuthRequest(options.path)) {
      final String? accessToken = await _tokenStore.readAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    handler.next(options);
  }

  Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final bool isUnauthorized = error.response?.statusCode == 401;
    final bool isProtectedRequest =
        !_isPublicAuthRequest(error.requestOptions.path);

    if (isUnauthorized && isProtectedRequest) {
      if (_canAttemptRefresh(error)) {
        bool refreshed = false;
        try {
          refreshed = await _refreshTokens();
        } catch (_) {
          refreshed = false;
        }

        if (refreshed) {
          final String? accessToken = await _tokenStore.readAccessToken();
          if (accessToken != null && accessToken.isNotEmpty) {
            error.requestOptions.headers['Authorization'] =
                'Bearer $accessToken';
            error.requestOptions.extra[_retryExtraKey] = true;

            try {
              final Response<dynamic> response =
                  await dio.fetch<dynamic>(error.requestOptions);
              handler.resolve(response);
              return;
            } on DioException catch (retryError) {
              if (retryError.response?.statusCode == 401) {
                await _clearSessionAndNotify();
              }
              handler.reject(_withApiException(retryError));
              return;
            }
          }
        }
      }

      await _clearSessionAndNotify();
    }

    handler.reject(_withApiException(error));
  }

  bool _canAttemptRefresh(DioException error) {
    final RequestOptions options = error.requestOptions;
    return options.extra[_retryExtraKey] != true &&
        !_isLogoutRequest(options.path) &&
        options.data is! FormData;
  }

  bool _isPublicAuthRequest(String path) {
    return path.endsWith('/api/auth/login') ||
        path.endsWith('/api/auth/register') ||
        path.endsWith('/api/auth/refresh') ||
        path.endsWith('/api/auth/forgot-password') ||
        path.endsWith('/api/auth/reset-password');
  }

  bool _isLogoutRequest(String path) => path.endsWith('/api/auth/logout');

  Future<bool> _refreshTokens() {
    final Future<bool>? existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }

    late final Future<bool> refresh;
    refresh = _performRefresh().whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });

    _refreshInFlight = refresh;
    return refresh;
  }

  Future<bool> _performRefresh() async {
    final String? refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final Response<dynamic> response = await _refreshDio.post<dynamic>(
        '/api/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
      final Object? data = response.data;
      if (data is! Map<dynamic, dynamic>) {
        return false;
      }

      final AuthSession session = AuthSession.fromJson(
        Map<String, dynamic>.from(data),
      );
      await _tokenStore.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return true;
    } on DioException {
      return false;
    } on FormatException {
      return false;
    }
  }

  Future<void> _clearSessionAndNotify() async {
    await _tokenStore.clear();
    await _onUnauthorized?.call();
  }

  DioException _withApiException(DioException error) {
    return DioException(
      requestOptions: error.requestOptions,
      response: error.response,
      type: error.type,
      error: ApiException.from(error),
      stackTrace: error.stackTrace,
      message: error.message,
    );
  }

  static BaseOptions _createOptions(String baseUrl) {
    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const <String, Object>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
  }
}
