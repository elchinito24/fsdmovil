import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/supabase_auth_service.dart';

class AuthService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userEmailKey = 'user_email';
  static const _userIdKey = 'user_id';
  static const _firstNameKey = 'first_name';
  static const _lastNameKey = 'last_name';

  static SharedPreferences? _prefs;

  static String? _accessToken;
  static String? _refreshToken;
  static String? _userEmail;
  static int? _userId;
  static String? _firstName;
  static String? _lastName;

  static String? get userEmail => _userEmail;
  static int? get userId => _userId;
  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;
  static String? get firstName => _firstName;
  static String? get lastName => _lastName;

  static String get displayName {
    final full = '${_firstName ?? ''} ${_lastName ?? ''}'.trim();
    if (full.isNotEmpty) return full;
    if (_userEmail != null && _userEmail!.trim().isNotEmpty) return _userEmail!;
    return 'Usuario';
  }

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    _accessToken = _prefs?.getString(_accessTokenKey);
    _refreshToken = _prefs?.getString(_refreshTokenKey);
    _userEmail = _prefs?.getString(_userEmailKey);
    _userId = _prefs?.getInt(_userIdKey);
    _firstName = _prefs?.getString(_firstNameKey);
    _lastName = _prefs?.getString(_lastNameKey);

    if (_accessToken != null && _accessToken!.isNotEmpty) {
      ApiService.setAuthToken(_accessToken!);
    }

    ApiService.setupAuthInterceptor(
      onRefreshToken: refreshAccessToken,
      onLogout: logout,
    );
  }

  static String _extractMessage(DioException e, String defaultMsg) {
    final body = e.response?.data;
    if (body is Map) {
      if (body['detail'] != null) return body['detail'].toString();
      if (body['non_field_errors'] is List &&
          (body['non_field_errors'] as List).isNotEmpty) {
        return (body['non_field_errors'] as List).first.toString();
      }
      for (final value in body.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }
    return defaultMsg;
  }

  static Future<void> _saveUserData(Map<String, dynamic> user) async {
    _userEmail = user['email']?.toString();
    final idValue = user['id'];
    _userId = idValue is int
        ? idValue
        : int.tryParse(idValue?.toString() ?? '');
    _firstName = user['first_name']?.toString();
    _lastName = user['last_name']?.toString();

    if (_userEmail != null) {
      await _prefs?.setString(_userEmailKey, _userEmail!);
    }
    if (_userId != null) {
      await _prefs?.setInt(_userIdKey, _userId!);
    }
    if (_firstName != null) {
      await _prefs?.setString(_firstNameKey, _firstName!);
    }
    if (_lastName != null) {
      await _prefs?.setString(_lastNameKey, _lastName!);
    }
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService.plainDio.post(
        '/auth/login/',
        data: {'email': email, 'password': password},
      );

      final data = Map<String, dynamic>.from(response.data);

      final access = data['access']?.toString();
      final refresh = data['refresh']?.toString();
      final user = Map<String, dynamic>.from(data['user'] ?? {});

      if (access == null || refresh == null) {
        throw Exception('El backend no devolvió tokens válidos.');
      }

      _accessToken = access;
      _refreshToken = refresh;

      await _prefs?.setString(_accessTokenKey, access);
      await _prefs?.setString(_refreshTokenKey, refresh);

      await _saveUserData(user);

      ApiService.setAuthToken(access);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) {
        throw Exception('Correo o contraseña incorrectos.');
      }
      throw Exception(
        _extractMessage(e, 'No se pudo iniciar sesión. Intenta nuevamente.'),
      );
    }
  }

  static Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      await ApiService.plainDio.post(
        '/auth/register/',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
          'password_confirm': passwordConfirm,
        },
      );
    } on DioException catch (e) {
      throw Exception(
        _extractMessage(e, 'Error al registrar. Intenta nuevamente.'),
      );
    }
  }

  /// Login social via Supabase OAuth (Google, GitHub, Microsoft).
  /// 1. Abre el navegador → Supabase devuelve access_token
  /// 2. Se intercambia en /auth/social/exchange/ → Django devuelve {access, refresh, user}
  static Future<void> socialLogin(OAuthProvider provider) async {
    final supabaseToken = await SupabaseAuthService.signInWithProvider(provider);

    try {
      final response = await ApiService.plainDio.post(
        '/auth/social/exchange/',
        data: {'supabase_token': supabaseToken},
      );

      final data = Map<String, dynamic>.from(response.data);
      final access = data['access']?.toString();
      final refresh = data['refresh']?.toString();
      final user = Map<String, dynamic>.from(data['user'] ?? {});

      if (access == null || refresh == null) {
        throw Exception('El servidor no devolvió tokens válidos.');
      }

      _accessToken = access;
      _refreshToken = refresh;

      await _prefs?.setString(_accessTokenKey, access);
      await _prefs?.setString(_refreshTokenKey, refresh);

      await _saveUserData(user);
      ApiService.setAuthToken(access);
    } on DioException catch (e) {
      throw Exception(
        _extractMessage(e, 'No se pudo completar el inicio de sesión social.'),
      );
    }
  }

  static Future<bool> restoreSession() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      ApiService.setAuthToken(_accessToken!);
      return true;
    }
    return false;
  }

  static bool get hasSession =>
      _accessToken != null &&
      _accessToken!.isNotEmpty &&
      _refreshToken != null &&
      _refreshToken!.isNotEmpty;

  static Future<String?> refreshAccessToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return null;

    try {
      final response = await ApiService.plainDio.post(
        '/auth/token/refresh/',
        data: {'refresh': _refreshToken},
      );

      final data = Map<String, dynamic>.from(response.data);
      final newAccess = data['access']?.toString();
      final newRefresh = data['refresh']?.toString();

      if (newAccess == null || newAccess.isEmpty) {
        return null;
      }

      _accessToken = newAccess;
      await _prefs?.setString(_accessTokenKey, newAccess);
      ApiService.setAuthToken(newAccess);

      if (newRefresh != null && newRefresh.isNotEmpty) {
        _refreshToken = newRefresh;
        await _prefs?.setString(_refreshTokenKey, newRefresh);
      }

      return newAccess;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await ApiService.dio.get('/auth/me/');
      final data = Map<String, dynamic>.from(response.data);
      await _saveUserData(data);
      return data;
    } on DioException catch (e) {
      throw Exception(
        _extractMessage(e, 'No se pudo obtener la información de la cuenta.'),
      );
    }
  }

  static Future<Map<String, dynamic>> updateMe({
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await ApiService.dio.patch(
        '/auth/me/',
        data: {'first_name': firstName.trim(), 'last_name': lastName.trim()},
      );
      final data = Map<String, dynamic>.from(response.data);
      await _saveUserData(data);
      return data;
    } on DioException catch (e) {
      throw Exception(_extractMessage(e, 'No se pudo actualizar el perfil.'));
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await ApiService.dio.post(
        '/auth/change-password/',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );
    } on DioException catch (e) {
      throw Exception(
        _extractMessage(e, 'No se pudo actualizar la contraseña.'),
      );
    }
  }

  static Future<void> deleteAccount() async {
    try {
      await ApiService.dio.delete('/auth/delete-account/');
    } on DioException catch (e) {
      throw Exception(_extractMessage(e, 'No se pudo eliminar la cuenta.'));
    }
  }

  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _userEmail = null;
    _userId = null;
    _firstName = null;
    _lastName = null;

    ApiService.clearAuthToken();

    // Cerrar sesión de Supabase también para limpiar la sesión OAuth
    try {
      await SupabaseAuthService.signOut();
    } catch (_) {}

    // Asegurar que _prefs esté inicializado antes de limpiar
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_accessTokenKey);
    await _prefs!.remove(_refreshTokenKey);
    await _prefs!.remove(_userEmailKey);
    await _prefs!.remove(_userIdKey);
    await _prefs!.remove(_firstNameKey);
    await _prefs!.remove(_lastNameKey);
  }
}
