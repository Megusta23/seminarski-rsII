import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/network/api_client.dart';

final class AuthApiService {
  const AuthApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
  }) {
    return _postSession(
      '/api/auth/register',
      <String, dynamic>{
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
        'firstName': firstName,
        'lastName': lastName,
      },
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) {
    return _postSession(
      '/api/auth/login',
      <String, dynamic>{
        'email': email,
        'password': password,
      },
    );
  }

  Future<AuthSession> refresh(String refreshToken) {
    return _postSession(
      '/api/auth/refresh',
      <String, dynamic>{'refreshToken': refreshToken},
    );
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _apiClient.dio.post<void>(
        '/api/auth/logout',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<CurrentProfile> getCurrentProfile() async {
    try {
      final Response<dynamic> response =
          await _apiClient.dio.get<dynamic>('/api/profile/me');
      return CurrentProfile.fromJson(_responseJson(response));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<AdminAccessResult> checkAdminAccess() async {
    try {
      final Response<dynamic> response =
          await _apiClient.dio.get<dynamic>('/api/admin/access');
      return AdminAccessResult.fromJson(_responseJson(response));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<AuthSession> _postSession(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final Response<dynamic> response = await _apiClient.dio.post<dynamic>(
        path,
        data: payload,
      );
      return AuthSession.fromJson(_responseJson(response));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Map<String, dynamic> _responseJson(Response<dynamic> response) {
    final Object? data = response.data;
    if (data is! Map<dynamic, dynamic>) {
      throw const FormatException('The server returned an invalid JSON object.');
    }
    return Map<String, dynamic>.from(data);
  }
}
