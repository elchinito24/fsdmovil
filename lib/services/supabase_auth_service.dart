import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fsdmovil/config/app_config.dart';

/// Maneja la autenticación OAuth social via Supabase (Google, GitHub, Microsoft).
/// El token resultante se intercambia con el backend Django via POST /auth/social/exchange/
class SupabaseAuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static bool get _isInitialized =>
      AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty;

  /// Abre el navegador para autenticarse con el proveedor indicado.
  /// Retorna el access_token de Supabase cuando el usuario completa el flujo.
  /// Lanza Exception si el usuario cancela o hay timeout.
  static Future<String> signInWithProvider(OAuthProvider provider) async {
    if (!_isInitialized) {
      throw Exception(
        'El login social no está disponible. Inicia la app con --dart-define=SUPABASE_URL=... y --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    // Cerrar sesión previa para forzar un flujo OAuth fresco
    try { await _client.auth.signOut(); } catch (_) {}

    final completer = Completer<String>();
    late StreamSubscription<AuthState> sub;

    sub = _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn &&
          data.session?.accessToken != null) {
        if (!completer.isCompleted) {
          completer.complete(data.session!.accessToken);
        }
        sub.cancel();
      }
    });

    await _client.auth.signInWithOAuth(
      provider,
      redirectTo: AppConfig.supabaseRedirectUrl,
    );

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        sub.cancel();
        throw Exception('El inicio de sesión fue cancelado o expiró.');
      },
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
