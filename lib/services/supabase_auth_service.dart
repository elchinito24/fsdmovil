import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fsdmovil/config/app_config.dart';

/// Maneja la autenticación OAuth social via Supabase (Google, GitHub, Microsoft).
/// El token resultante se intercambia con el backend Django via POST /auth/social/exchange/
class SupabaseAuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  static bool get _isInitialized =>
      AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty;

  /// Registra un nuevo usuario con email/password en Supabase.
  /// Supabase envía automáticamente un OTP al correo para verificación.
  static Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    if (!_isInitialized) {
      throw Exception(
        'Supabase no está configurado. Inicia la app con --dart-define=SUPABASE_URL=... y --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'first_name': firstName, 'last_name': lastName},
    );
    if (response.user == null) {
      throw Exception('No se pudo crear la cuenta. Intenta nuevamente.');
    }
  }

  /// Verifica el OTP de 6 dígitos enviado al correo tras el signUp.
  /// Retorna el access_token de Supabase si la verificación fue exitosa.
  static Future<String> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      final accessToken = response.session?.accessToken;
      if (accessToken == null) {
        throw Exception('Código inválido o expirado. Solicita uno nuevo.');
      }
      return accessToken;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('expired') || msg.contains('otp')) {
        throw Exception('El código expiró. Presiona "Reenviar" para obtener uno nuevo.');
      }
      if (msg.contains('invalid') || msg.contains('incorrect')) {
        throw Exception('Código incorrecto. Verifica e intenta de nuevo.');
      }
      throw Exception(e.message);
    }
  }

  /// Reenvía el OTP de verificación al correo.
  static Future<void> resendOtp({required String email}) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

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
    AppLifecycleListener? lifecycleListener;

    void cleanup() {
      sub.cancel();
      lifecycleListener?.dispose();
      lifecycleListener = null;
    }

    sub = _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn &&
          data.session?.accessToken != null) {
        if (!completer.isCompleted) {
          completer.complete(data.session!.accessToken);
        }
        cleanup();
      }
    });

    // When the user returns from the browser without completing OAuth,
    // wait a short grace period for a potential deep-link redirect,
    // then cancel if the completer is still pending.
    lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (completer.isCompleted) return;
        Future.delayed(const Duration(seconds: 3), () {
          if (!completer.isCompleted) {
            cleanup();
            completer.completeError(
              Exception('El inicio de sesión fue cancelado.'),
            );
          }
        });
      },
    );

    await _client.auth.signInWithOAuth(
      provider,
      redirectTo: AppConfig.supabaseRedirectUrl,
    );

    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        cleanup();
        throw Exception('El inicio de sesión fue cancelado o expiró.');
      },
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
