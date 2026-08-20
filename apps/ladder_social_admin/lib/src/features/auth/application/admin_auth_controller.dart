import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_state.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class AdminAuthController extends StateNotifier<AdminAuthState> {
  AdminAuthController(this._authRepository)
      : super(const AdminAuthState.checking()) {
    Future<void>.microtask(_restoreSession);
  }

  final AuthRepository _authRepository;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AdminAuthState.busy();

    try {
      final AuthSession session = await _authRepository.login(
        email: email,
        password: password,
      );

      if (!session.isAdmin) {
        await _revokeNonAdminSession();
        state = const AdminAuthState.unauthenticated(
          errorMessage: 'This account does not have administrator access.',
        );
        return;
      }

      state = AdminAuthState.authenticated(session);
    } catch (error) {
      final ApiException exception = ApiException.from(error);
      state = AdminAuthState.unauthenticated(
        errorMessage: exception.message,
        validationErrors: exception.validationErrors,
      );
    }
  }

  Future<void> logout() async {
    final AuthSession? currentSession = state.session;
    state = AdminAuthState.busy(session: currentSession);

    try {
      await _authRepository.logout();
      state = const AdminAuthState.unauthenticated();
    } catch (error) {
      final ApiException exception = ApiException.from(error);
      state = currentSession == null
          ? AdminAuthState.unauthenticated(
              errorMessage: exception.message,
              validationErrors: exception.validationErrors,
            )
          : AdminAuthState.authenticated(
              currentSession,
              errorMessage: exception.message,
            );
    }
  }

  Future<void> handleUnauthorized() async {
    await _authRepository.clearLocalSession();
    state = const AdminAuthState.unauthenticated(
      errorMessage: 'Your administrator session expired. Please sign in again.',
    );
  }

  Future<void> _restoreSession() async {
    try {
      final AuthSession? session = await _authRepository.restoreSession();
      if (session == null) {
        state = const AdminAuthState.unauthenticated();
        return;
      }

      if (!session.isAdmin) {
        await _revokeNonAdminSession();
        state = const AdminAuthState.unauthenticated(
          errorMessage: 'This account does not have administrator access.',
        );
        return;
      }

      state = AdminAuthState.authenticated(session);
    } catch (error) {
      final ApiException exception = ApiException.from(error);
      state = AdminAuthState.unauthenticated(
        errorMessage: exception.message,
        validationErrors: exception.validationErrors,
      );
    }
  }

  Future<void> _revokeNonAdminSession() async {
    try {
      await _authRepository.logout();
    } catch (_) {
      await _authRepository.clearLocalSession();
    }
  }
}
