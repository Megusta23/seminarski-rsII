import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_state.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('administrator session is recognized by shared auth model', () {
    final AuthSession session = _session(roles: <String>['Admin']);
    final AdminAuthState state = AdminAuthState.authenticated(session);

    expect(state.isAuthenticated, isTrue);
    expect(state.session?.isAdmin, isTrue);
  });

  test('regular user is not recognized as administrator', () {
    final AuthSession session = _session(roles: <String>['User']);

    expect(session.isAdmin, isFalse);
  });
}

AuthSession _session({required List<String> roles}) => AuthSession(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAtUtc: DateTime.utc(2026, 8, 19, 12),
      refreshTokenExpiresAtUtc: DateTime.utc(2026, 9, 2, 12),
      userId: '1d5b546a-432a-43e6-9da5-8b86a438f45a',
      email: 'admin@example.com',
      displayName: 'Ladder Admin',
      roles: roles,
    );
