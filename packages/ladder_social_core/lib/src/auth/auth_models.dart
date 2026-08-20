final class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAtUtc,
    required this.refreshTokenExpiresAtUtc,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.roles,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: _requiredString(json, 'accessToken'),
      refreshToken: _requiredString(json, 'refreshToken'),
      accessTokenExpiresAtUtc: _requiredDateTime(
        json,
        'accessTokenExpiresAtUtc',
      ),
      refreshTokenExpiresAtUtc: _requiredDateTime(
        json,
        'refreshTokenExpiresAtUtc',
      ),
      userId: _requiredString(json, 'userId'),
      email: _requiredString(json, 'email'),
      displayName: _requiredString(json, 'displayName'),
      roles: _stringList(json['roles']),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAtUtc;
  final DateTime refreshTokenExpiresAtUtc;
  final String userId;
  final String email;
  final String displayName;
  final List<String> roles;

  bool get isAdmin => roles.contains('Admin');
}

final class CurrentProfile {
  const CurrentProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.roles,
    this.bio,
    this.avatarUrl,
    this.cityId,
    this.cityName,
    this.dateOfBirth,
  });

  factory CurrentProfile.fromJson(Map<String, dynamic> json) {
    final String? rawDateOfBirth = json['dateOfBirth']?.toString();

    return CurrentProfile(
      userId: _requiredString(json, 'userId'),
      email: _requiredString(json, 'email'),
      displayName: _requiredString(json, 'displayName'),
      firstName: _requiredString(json, 'firstName'),
      lastName: _requiredString(json, 'lastName'),
      bio: json['bio']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      cityId: json['cityId']?.toString(),
      cityName: json['cityName']?.toString(),
      dateOfBirth: rawDateOfBirth == null || rawDateOfBirth.isEmpty
          ? null
          : DateTime.parse(rawDateOfBirth),
      roles: _stringList(json['roles']),
    );
  }

  final String userId;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;
  final String? bio;
  final String? avatarUrl;
  final String? cityId;
  final String? cityName;
  final DateTime? dateOfBirth;
  final List<String> roles;
}

final class AdminAccessResult {
  const AdminAccessResult({
    required this.userId,
    required this.message,
  });

  factory AdminAccessResult.fromJson(Map<String, dynamic> json) {
    return AdminAccessResult(
      userId: _requiredString(json, 'userId'),
      message: _requiredString(json, 'message'),
    );
  }

  final String userId;
  final String message;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final String? value = json[key]?.toString();
  if (value == null || value.trim().isEmpty) {
    throw FormatException('Authentication response is missing "$key".');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final String value = _requiredString(json, key);
  return DateTime.parse(value).toUtc();
}

List<String> _stringList(Object? value) {
  if (value is! List<dynamic>) {
    return const <String>[];
  }

  return List<String>.unmodifiable(
    value.map((dynamic item) => item.toString()),
  );
}
