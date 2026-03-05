import 'package:dio/dio.dart';
import 'package:fsdmovil/config/app_config.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static Dio get dio => _dio;

  /// Agrega el token JWT a todas las peticiones
  static void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Elimina el token (al cerrar sesión)
  static void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}
