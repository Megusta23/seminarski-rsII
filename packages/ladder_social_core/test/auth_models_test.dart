import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('AuthSession parses token dates and administrator role', () {
    final AuthSession session = AuthSession.fromJson(<String, dynamic>{
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'accessTokenExpiresAtUtc': '2026-08-19T12:00:00Z',
      'refreshTokenExpiresAtUtc': '2026-09-02T12:00:00Z',
      'userId': 'c18b9441-1438-4d03-bf0e-c4f2a2d4fd47',
      'email': 'admin@laddersocial.local',
      'displayName': 'Ladder Admin',
      'roles': <String>['Admin'],
    });

    expect(session.accessToken, 'access-token');
    expect(session.accessTokenExpiresAtUtc, DateTime.utc(2026, 8, 19, 12));
    expect(session.refreshTokenExpiresAtUtc, DateTime.utc(2026, 9, 2, 12));
    expect(session.isAdmin, isTrue);
  });

  test('AuthSession rejects a response without an access token', () {
    expect(
      () => AuthSession.fromJson(<String, dynamic>{
        'refreshToken': 'refresh-token',
        'accessTokenExpiresAtUtc': '2026-08-19T12:00:00Z',
        'refreshTokenExpiresAtUtc': '2026-09-02T12:00:00Z',
        'userId': 'c18b9441-1438-4d03-bf0e-c4f2a2d4fd47',
        'email': 'user@example.com',
        'displayName': 'Test User',
        'roles': <String>['User'],
      }),
      throwsFormatException,
    );
  });

  test('CurrentProfile parses optional values', () {
    final CurrentProfile profile = CurrentProfile.fromJson(<String, dynamic>{
      'userId': 'c18b9441-1438-4d03-bf0e-c4f2a2d4fd47',
      'email': 'user@example.com',
      'displayName': 'Test User',
      'firstName': 'Test',
      'lastName': 'User',
      'bio': null,
      'avatarUrl': null,
      'cityId': null,
      'cityName': null,
      'dateOfBirth': '2000-05-10',
      'roles': <String>['User'],
    });

    expect(profile.dateOfBirth, DateTime(2000, 5, 10));
    expect(profile.cityName, isNull);
    expect(profile.roles, <String>['User']);
  });
}
