import 'package:ladder_social_core/ladder_social_core.dart';

enum AdminAuthStatus {
  checking,
  unauthenticated,
  busy,
  authenticated,
}

final class AdminAuthState {
  const AdminAuthState({
    required this.status,
    this.session,
    this.errorMessage,
    this.validationErrors = const <String, List<String>>{},
  });

  const AdminAuthState.checking() : this(status: AdminAuthStatus.checking);

  const AdminAuthState.unauthenticated({
    String? errorMessage,
    Map<String, List<String>> validationErrors =
        const <String, List<String>>{},
  }) : this(
          status: AdminAuthStatus.unauthenticated,
          errorMessage: errorMessage,
          validationErrors: validationErrors,
        );

  const AdminAuthState.busy({AuthSession? session})
      : this(status: AdminAuthStatus.busy, session: session);

  const AdminAuthState.authenticated(
    AuthSession session, {
    String? errorMessage,
    Map<String, List<String>> validationErrors =
        const <String, List<String>>{},
  }) : this(
          status: AdminAuthStatus.authenticated,
          session: session,
          errorMessage: errorMessage,
          validationErrors: validationErrors,
        );

  final AdminAuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
  final Map<String, List<String>> validationErrors;

  bool get isBusy => status == AdminAuthStatus.busy;
  bool get isAuthenticated => session != null;

  String? fieldError(String field) {
    final String normalizedField = field.toLowerCase();
    for (final MapEntry<String, List<String>> entry
        in validationErrors.entries) {
      if (entry.key.toLowerCase() == normalizedField && entry.value.isNotEmpty) {
        return entry.value.join('\n');
      }
    }
    return null;
  }
}
