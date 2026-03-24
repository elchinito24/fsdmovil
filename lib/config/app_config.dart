import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000/api/v1',
      );
    }

    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://172.17.4.127:8000/api/v1',
    );
  }

  static const int connectTimeout = 10;
  static const int receiveTimeout = 10;
}
