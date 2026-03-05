class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const int connectTimeout = 10;
  static const int receiveTimeout = 10;
}
