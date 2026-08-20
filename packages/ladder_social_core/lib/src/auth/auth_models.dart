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
      accessToken: requiredString(json, 'accessToken'),
      refreshToken: requiredString(json, 'refreshToken'),
      accessTokenExpiresAtUtc: requiredDateTime(
        json,
        'accessTokenExpiresAtUtc',
      ),
      refreshTokenExpiresAtUtc: requiredDateTime(
        json,
        'refreshTokenExpiresAtUtc',
      ),
      userId: requiredString(json, 'userId'),
      email: requiredString(json, 'email'),
      displayName: requiredString(json, 'displayName'),
      roles: stringList(json['roles']),
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
      userId: requiredString(json, 'userId'),
      email: requiredString(json, 'email'),
      displayName: requiredString(json, 'displayName'),
      firstName: requiredString(json, 'firstName'),
      lastName: requiredString(json, 'lastName'),
      bio: nullableString(json['bio']),
      avatarUrl: nullableString(json['avatarUrl']),
      cityId: nullableString(json['cityId']),
      cityName: nullableString(json['cityName']),
      dateOfBirth: rawDateOfBirth == null || rawDateOfBirth.isEmpty
          ? null
          : DateTime.parse(rawDateOfBirth),
      roles: stringList(json['roles']),
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
      userId: requiredString(json, 'userId'),
      message: requiredString(json, 'message'),
    );
  }

  final String userId;
  final String message;
}

final class OperationMessage {
  const OperationMessage(this.message);

  factory OperationMessage.fromJson(Map<String, dynamic> json) =>
      OperationMessage(requiredString(json, 'message'));

  final String message;
}

String requiredString(Map<String, dynamic> json, String key) {
  final String? value = json[key]?.toString();
  if (value == null || value.trim().isEmpty) {
    throw FormatException('Server response is missing "$key".');
  }
  return value;
}

DateTime requiredDateTime(Map<String, dynamic> json, String key) {
  final String value = requiredString(json, key);
  return DateTime.parse(value).toUtc();
}

List<String> stringList(Object? value) {
  if (value is! List<dynamic>) {
    return const <String>[];
  }

  return List<String>.unmodifiable(
    value.map((dynamic item) => item.toString()),
  );
}

String? nullableString(Object? value) {
  final String? text = value?.toString();
  return text == null || text.trim().isEmpty ? null : text;
}
