import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_state.dart';

final class MobileAuthController extends StateNotifier<MobileAuthState> {
  MobileAuthController(this._authRepository)
      : super(const MobileAuthState.checking()) {
    Future<void>.microtask(_restoreSession);
  }

  final AuthRepository _authRepository;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const MobileAuthState.busy();
    try {
      final AuthSession session = await _authRepository.login(
        email: email,
        password: password,
      );
      state = MobileAuthState.authenticated(session);
    } catch (error) {
      state = _failureState(error);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
  }) async {
    state = const MobileAuthState.busy();
    try {
      final AuthSession session = await _authRepository.register(
        email: email,
        password: password,
        confirmPassword: confirmPassword,
        firstName: firstName,
        lastName: lastName,
      );
      state = MobileAuthState.authenticated(session);
    } catch (error) {
      state = _failureState(error);
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final AuthSession? currentSession = state.session;
    if (currentSession == null) {
      state = const MobileAuthState.unauthenticated(
        errorMessage: 'Authentication is required to change your password.',
      );
      return false;
    }

    state = MobileAuthState.busy(session: currentSession);
    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      state = const MobileAuthState.unauthenticated();
      return true;
    } catch (error) {
      final ApiException exception = ApiException.from(error);
      state = MobileAuthState.authenticated(
        currentSession,
        errorMessage: exception.message,
        validationErrors: exception.validationErrors,
      );
      return false;
    }
  }

  Future<void> logout() async {
    final AuthSession? currentSession = state.session;
    state = MobileAuthState.busy(session: currentSession);

    try {
      await _authRepository.logout();
      state = const MobileAuthState.unauthenticated();
    } catch (error) {
      final ApiException exception = ApiException.from(error);
      state = currentSession == null
          ? MobileAuthState.unauthenticated(
              errorMessage: exception.message,
              validationErrors: exception.validationErrors,
            )
          : MobileAuthState.authenticated(
              currentSession,
              errorMessage: exception.message,
            );
    }
  }

  Future<void> handleUnauthorized() async {
    await _authRepository.clearLocalSession();
    state = const MobileAuthState.unauthenticated(
      errorMessage: 'Your session expired. Please sign in again.',
    );
  }

  void clearErrors() {
    if (!state.isBusy && !state.isAuthenticated) {
      state = const MobileAuthState.unauthenticated();
    }
  }

  Future<void> _restoreSession() async {
    try {
      final AuthSession? session = await _authRepository.restoreSession();
      state = session == null
          ? const MobileAuthState.unauthenticated()
          : MobileAuthState.authenticated(session);
    } catch (error) {
      final ApiException exception = ApiException.from(error);
      state = MobileAuthState.unauthenticated(
        errorMessage: exception.message,
        validationErrors: exception.validationErrors,
      );
    }
  }

  MobileAuthState _failureState(Object error) {
    final ApiException exception = ApiException.from(error);
    return MobileAuthState.unauthenticated(
      errorMessage: exception.message,
      validationErrors: exception.validationErrors,
    );
  }
}
