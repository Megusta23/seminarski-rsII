final class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static void validate() {
    if (apiBaseUrl.trim().isEmpty) {
      throw StateError(
        'API_BASE_URL is missing. Start Flutter with '
        '--dart-define=API_BASE_URL=http://<host>:5001.',
      );
    }
  }
}
