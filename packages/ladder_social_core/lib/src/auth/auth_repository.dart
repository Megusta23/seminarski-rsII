import 'package:ladder_social_core/src/auth/auth_api_service.dart';
import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/friends/friend_models.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/storage/token_store.dart';
import 'package:ladder_social_core/src/tasks/task_models.dart';

final class AuthRepository {
  const AuthRepository({
    required AuthApiService apiService,
    required TokenStore tokenStore,
  })  : _apiService = apiService,
        _tokenStore = tokenStore;

  final AuthApiService _apiService;
  final TokenStore _tokenStore;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
  }) async {
    final AuthSession session = await _apiService.register(
      email: email.trim(),
      password: password,
      confirmPassword: confirmPassword,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    );
    await _saveSession(session);
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final AuthSession session = await _apiService.login(
      email: email.trim(),
      password: password,
    );
    await _saveSession(session);
    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final String? refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final AuthSession session = await _apiService.refresh(refreshToken);
      await _saveSession(session);
      return session;
    } on ApiException catch (error) {
      if (_isTerminalSessionError(error)) {
        await _tokenStore.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final String? refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStore.clear();
      return;
    }

    try {
      final AuthSession currentSession = await _apiService.refresh(refreshToken);
      await _saveSession(currentSession);
      await _apiService.logout(currentSession.refreshToken);
      await _tokenStore.clear();
    } on ApiException catch (error) {
      if (_isTerminalSessionError(error)) {
        await _tokenStore.clear();
        return;
      }
      rethrow;
    }
  }

  Future<OperationMessage> forgotPassword(String email) =>
      _apiService.forgotPassword(email.trim());

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) =>
      _apiService.resetPassword(
        email: email.trim(),
        code: code.trim(),
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _apiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    await _tokenStore.clear();
  }

  Future<void> clearLocalSession() => _tokenStore.clear();

  Future<CurrentProfile> getCurrentProfile() =>
      _apiService.getCurrentProfile();

  Future<CurrentProfile> updateCurrentProfile({
    required String firstName,
    required String lastName,
    String? bio,
    String? cityId,
    DateTime? dateOfBirth,
  }) {
    final String? normalizedBio = bio == null || bio.trim().isEmpty
        ? null
        : bio.trim();

    return _apiService.updateCurrentProfile(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      bio: normalizedBio,
      cityId: cityId,
      dateOfBirth: dateOfBirth,
    );
  }

  Future<CurrentProfile> updateAvatar(ImageUpload image) =>
      _apiService.updateAvatar(image);

  Future<CurrentProfile> removeAvatar() => _apiService.removeAvatar();

  Future<PagedResult<ProfileHighlightCandidate>> getHighlightCandidates({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) =>
      _apiService.getHighlightCandidates(
        search: search,
        page: page,
        pageSize: pageSize,
      );

  Future<void> highlightPost(String postId) =>
      _apiService.highlightPost(postId);

  Future<void> removeHighlight(String postId) =>
      _apiService.removeHighlight(postId);

  Future<AdminAccessResult> checkAdminAccess() =>
      _apiService.checkAdminAccess();

  Future<void> _saveSession(AuthSession session) {
    return _tokenStore.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }

  bool _isTerminalSessionError(ApiException error) {
    final int? statusCode = error.statusCode;
    return statusCode != null && statusCode >= 400 && statusCode < 500;
  }
}
