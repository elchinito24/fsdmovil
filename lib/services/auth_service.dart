import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fsdmovil/services/api_service.dart';

class AuthService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userEmailKey = 'user_email';

  static SharedPreferences? _prefs;

  static String? _accessToken;
  static String? _refreshToken;
  static String? _userEmail;

  static String? get userEmail => _userEmail;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    _accessToken = _prefs?.getString(_accessTokenKey);
    _refreshToken = _prefs?.getString(_refreshTokenKey);
    _userEmail = _prefs?.getString(_userEmailKey);

    if (_accessToken != null && _accessToken!.isNotEmpty) {
      ApiService.setAuthToken(_accessToken!);
    }
  }

  static String _extractMessage(DioException e, String defaultMsg) {
    final body = e.response?.data;
    if (body is Map) {
      // Django devuelve {"detail": "..."} o {"non_field_errors": ["..."]}
      if (body['detail'] != null) return body['detail'].toString();
      if (body['non_field_errors'] is List && (body['non_field_errors'] as List).isNotEmpty) {
        return (body['non_field_errors'] as List).first.toString();
      }
      // Primer campo con error
      for (final value in body.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String) return value;
      }
    }
    return defaultMsg;
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
      final userEmail = user['email']?.toString() ?? email;

      if (access == null || refresh == null) {
        throw Exception('El backend no devolvió tokens válidos.');
      }

      _accessToken = access;
      _refreshToken = refresh;
      _userEmail = userEmail;

      await _prefs?.setString(_accessTokenKey, access);
      await _prefs?.setString(_refreshTokenKey, refresh);
      await _prefs?.setString(_userEmailKey, userEmail);

      ApiService.setAuthToken(access);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 400) {
        throw Exception('Correo o contraseña incorrectos.');
      }
      throw Exception(_extractMessage(e, 'No se pudo iniciar sesión. Intenta nuevamente.'));
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
      throw Exception(_extractMessage(e, 'Error al registrar. Intenta nuevamente.'));
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

  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _userEmail = null;

    ApiService.clearAuthToken();

    await _prefs?.remove(_accessTokenKey);
    await _prefs?.remove(_refreshTokenKey);
    await _prefs?.remove(_userEmailKey);
  }
}
