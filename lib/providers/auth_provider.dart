import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsdmovil/services/auth_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userEmail;

  const AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    required this.userEmail,
  });

  factory AuthState.initial() {
    return const AuthState(
      isAuthenticated: false,
      isLoading: false,
      userEmail: null,
    );
  }

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userEmail,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userEmail: userEmail ?? this.userEmail,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial()) {
    _restore();
  }

  Future<void> _restore() async {
    final ok = await AuthService.restoreSession();
    state = state.copyWith(
      isAuthenticated: ok,
      userEmail: AuthService.userEmail,
    );
  }

  Future<String?> login(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true);

      await AuthService.login(email: email, password: password);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        userEmail: AuthService.userEmail,
      );

      return null;
    } catch (e) {
      state = state.copyWith(isAuthenticated: false, isLoading: false);
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      await AuthService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        passwordConfirm: passwordConfirm,
      );

      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = state.copyWith(
      isAuthenticated: false,
      userEmail: null,
      isLoading: false,
    );
  }
}
