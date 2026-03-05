import 'package:fsdmovil/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey = 'auth_token';

  /// Login: devuelve el token si es exitoso
  static Future<String?> login(String email, String password) async {
    final response = await ApiService.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final token = response.data['token'] as String?;
    if (token != null) {
      await _saveToken(token);
      ApiService.setAuthToken(token);
    }
    return token;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    ApiService.clearAuthToken();
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}
