import 'package:ladder_social_core/ladder_social_core.dart';

enum MobileAuthStatus {
  checking,
  unauthenticated,
  busy,
  authenticated,
}

final class MobileAuthState {
  const MobileAuthState({
    required this.status,
    this.session,
    this.errorMessage,
    this.validationErrors = const <String, List<String>>{},
  });

  const MobileAuthState.checking()
      : this(status: MobileAuthStatus.checking);

  const MobileAuthState.unauthenticated({
    String? errorMessage,
    Map<String, List<String>> validationErrors =
        const <String, List<String>>{},
  }) : this(
          status: MobileAuthStatus.unauthenticated,
          errorMessage: errorMessage,
          validationErrors: validationErrors,
        );

  const MobileAuthState.busy({AuthSession? session})
      : this(status: MobileAuthStatus.busy, session: session);

  const MobileAuthState.authenticated(
    AuthSession session, {
    String? errorMessage,
    Map<String, List<String>> validationErrors =
        const <String, List<String>>{},
  }) : this(
          status: MobileAuthStatus.authenticated,
          session: session,
          errorMessage: errorMessage,
          validationErrors: validationErrors,
        );

  final MobileAuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
  final Map<String, List<String>> validationErrors;

  bool get isBusy => status == MobileAuthStatus.busy;
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
