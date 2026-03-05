import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthNotifier extends StateNotifier<AuthStatus> {
  AuthNotifier() : super(AuthStatus.unknown);

  // ─── Session ─────────────────────────────────────────────────────────────

  Future<void> checkToken() async {
    final token = await AuthService.getSavedToken();
    if (token != null) {
      ApiService.setAuthToken(token);
      state = AuthStatus.authenticated;
    } else {
      state = AuthStatus.unauthenticated;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = AuthStatus.unauthenticated;
  }

  // ─── Login ────────────────────────────────────────────────────────────────

  /// Devuelve null si fue exitoso, o un mensaje de error
  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please fill out all fields';
    }
    final token = await AuthService.login(email.trim(), password);
    if (token != null) {
      state = AuthStatus.authenticated;
      return null;
    }
    return 'Credenciales incorrectas';
  }

  // ─── Register ─────────────────────────────────────────────────────────────

  /// Devuelve null si fue exitoso, o un mensaje de error
  Future<String?> register(
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    if (firstName.trim().isEmpty ||
        lastName.trim().isEmpty ||
        email.trim().isEmpty ||
        password.isEmpty) {
      return 'Please fill out all fields';
    }
    final token = await AuthService.register(
      firstName,
      lastName,
      email,
      password,
    );
    if (token != null) {
      state = AuthStatus.authenticated;
      return null;
    }
    return 'Registration failed. Please try again.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthStatus>(
  (ref) => AuthNotifier(),
);
