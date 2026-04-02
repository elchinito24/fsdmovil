import 'package:flutter/foundation.dart';

class AppConfig {
  // Local: --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  // Producción: --dart-define=API_BASE_URL=https://tu-servidor.com/api/v1
  static String get baseUrl {
    if (kIsWeb) {
      return const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000/api/v1',
      );
    }
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.0.16:8000/api/v1',
    );
  }

  // Supabase OAuth (login social: Google, GitHub, Microsoft)
  // Pasar via: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Scheme para redirigir de vuelta a la app tras OAuth
  static const String supabaseRedirectUrl = 'fsdmovil://login-callback';

  static const int connectTimeout = 10;
  static const int receiveTimeout = 10;
}
