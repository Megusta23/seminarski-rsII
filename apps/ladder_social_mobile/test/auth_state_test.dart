import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_state.dart';

void main() {
  test('mobile auth state exposes authenticated session', () {
    final AuthSession session = _session(roles: <String>['User']);

    final MobileAuthState state = MobileAuthState.authenticated(session);

    expect(state.isAuthenticated, isTrue);
    expect(state.isBusy, isFalse);
    expect(state.session?.email, 'mobile@example.com');
  });

  test('mobile auth state resolves backend field errors case-insensitively', () {
    const MobileAuthState state = MobileAuthState.unauthenticated(
      validationErrors: <String, List<String>>{
        'Email': <String>['Enter a valid email address.'],
      },
    );

    expect(state.fieldError('email'), 'Enter a valid email address.');
  });
}

AuthSession _session({required List<String> roles}) => AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 19, 12),
      refreshTokenExpiresAtUtc: DateTime.utc(2026, 9, 2, 12),
      userId: '1d5b546a-432a-43e6-9da5-8b86a438f45a',
      email: 'mobile@example.com',
      displayName: 'Mobile User',
      roles: roles,
    );
