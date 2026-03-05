import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/services/api_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthNotifier extends StateNotifier<AuthStatus> {
  AuthNotifier() : super(AuthStatus.unknown);

  Future<void> checkToken() async {
    final token = await AuthService.getSavedToken();
    if (token != null) {
      ApiService.setAuthToken(token);
      state = AuthStatus.authenticated;
    } else {
      state = AuthStatus.unauthenticated;
    }
  }

  Future<bool> login(String email, String password) async {
    final token = await AuthService.login(email, password);
    if (token != null) {
      state = AuthStatus.authenticated;
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = AuthStatus.unauthenticated;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthStatus>(
  (ref) => AuthNotifier(),
);
