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
    await _postVoid(
      '/api/auth/logout',
      <String, dynamic>{'refreshToken': refreshToken},
    );
  }

  Future<OperationMessage> forgotPassword(String email) async {
    try {
      final Response<dynamic> response = await _apiClient.dio.post<dynamic>(
        '/api/auth/forgot-password',
        data: <String, dynamic>{'email': email},
      );
      return OperationMessage.fromJson(_responseJson(response));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _postVoid(
      '/api/auth/reset-password',
      <String, dynamic>{
        'email': email,
        'code': code,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _postVoid(
      '/api/profile/change-password',
      <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
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

  Future<CurrentProfile> updateCurrentProfile({
    required String firstName,
    required String lastName,
    String? bio,
    String? cityId,
    DateTime? dateOfBirth,
  }) async {
    try {
      final Response<dynamic> response = await _apiClient.dio.put<dynamic>(
        '/api/profile/me',
        data: <String, dynamic>{
          'firstName': firstName,
          'lastName': lastName,
          'bio': bio,
          'cityId': cityId,
          'dateOfBirth': dateOfBirth == null
              ? null
              : _formatDateOnly(dateOfBirth),
        },
      );
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

  Future<void> _postVoid(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _apiClient.dio.post<void>(path, data: payload);
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  Map<String, dynamic> _responseJson(Response<dynamic> response) {
    final Object? data = response.data;
    if (data is! Map<dynamic, dynamic>) {
      throw const FormatException('The server returned an invalid JSON object.');
    }
    return Map<String, dynamic>.from(data);
  }

  String _formatDateOnly(DateTime value) {
    final DateTime local = value.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
