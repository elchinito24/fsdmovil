import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
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

  static final Dio _plainDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: Duration(seconds: AppConfig.connectTimeout),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeout),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static Dio get dio => _dio;
  static Dio get plainDio => _plainDio;

  static bool _interceptorConfigured = false;
  static Future<String?> Function()? _refreshTokenHandler;
  static Future<void> Function()? _logoutHandler;

  static void setupAuthInterceptor({
    required Future<String?> Function() onRefreshToken,
    required Future<void> Function() onLogout,
  }) {
    _refreshTokenHandler = onRefreshToken;
    _logoutHandler = onLogout;

    if (_interceptorConfigured) return;
    _interceptorConfigured = true;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final request = error.requestOptions;
          final statusCode = error.response?.statusCode;

          final isUnauthorized = statusCode == 401;
          final isRefreshCall = request.path.contains('/auth/token/refresh/');
          final isLoginCall = request.path.contains('/auth/login/');
          final alreadyRetried = request.extra['retried'] == true;

          if (isUnauthorized &&
              !isRefreshCall &&
              !isLoginCall &&
              !alreadyRetried &&
              _refreshTokenHandler != null) {
            final newToken = await _refreshTokenHandler!.call();

            if (newToken != null && newToken.isNotEmpty) {
              request.headers['Authorization'] = 'Bearer $newToken';
              request.extra['retried'] = true;

              final clonedResponse = await _dio.fetch(request);
              return handler.resolve(clonedResponse);
            } else {
              if (_logoutHandler != null) {
                await _logoutHandler!.call();
              }
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  static void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  static void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  static Future<List<dynamic>> getProjects() async {
    try {
      final response = await _dio.get('/projects/');
      return response.data['results'] ?? [];
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener proyectos: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener proyectos: $e');
    }
  }

  static Future<Map<String, dynamic>> getProjectSrs(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/srs/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception('Error al obtener SRS: ${e.response?.data ?? e.message}');
    } catch (e) {
      throw Exception('Error al obtener SRS: $e');
    }
  }

  static Future<void> updateProjectSrs(
    int projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _dio.put('/projects/$projectId/srs/', data: data);
    } on DioException catch (e) {
      throw Exception('Error al guardar SRS: ${e.response?.data ?? e.message}');
    } catch (e) {
      throw Exception('Error al guardar SRS: $e');
    }
  }

  static Future<List<dynamic>> getProjectDocuments(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/documents/');
      final data = response.data;

      if (data is List) return data;
      if (data is Map<String, dynamic>) {
        if (data['results'] is List) return data['results'];
        if (data['documents'] is List) return data['documents'];
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener documentos: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener documentos: $e');
    }
  }

  static Future<String> downloadDocument({
    required int documentId,
    required String fileName,
  }) async {
    try {
      final response = await _dio.get(
        '/documents/$documentId/download/',
        options: Options(responseType: ResponseType.bytes),
      );

      final directory = await getApplicationDocumentsDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${directory.path}/$safeName';

      final file = File(filePath);
      await file.writeAsBytes(List<int>.from(response.data));

      return filePath;
    } on DioException catch (e) {
      throw Exception(
        'Error al descargar documento: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al descargar documento: $e');
    }
  }

  static Future<void> generateProjectDocument(int projectId) async {
    try {
      await _dio.post('/projects/$projectId/generate/');
    } on DioException catch (e) {
      throw Exception(
        'Error al generar documento: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al generar documento: $e');
    }
  }

  static Future<List<dynamic>> getWorkspaces() async {
    try {
      final response = await _dio.get('/workspaces/');
      return response.data['results'] ?? [];
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener workspaces: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener workspaces: $e');
    }
  }

  static Future<List<dynamic>> getTemplates() async {
    try {
      final response = await _dio.get('/templates/');
      return response.data['results'] ?? [];
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener templates: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener templates: $e');
    }
  }

  static Future<Map<String, dynamic>> createProject(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/projects/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al crear proyecto: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al crear proyecto: $e');
    }
  }

  static Future<Map<String, dynamic>> createWorkspace(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/workspaces/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al crear workspace: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al crear workspace: $e');
    }
  }

  static Future<Map<String, dynamic>> getWorkspaceById(int workspaceId) async {
    try {
      final response = await _dio.get('/workspaces/$workspaceId/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener workspace: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener workspace: $e');
    }
  }

  static Future<List<dynamic>> getProjectsByWorkspace(int workspaceId) async {
    try {
      final response = await _dio.get(
        '/projects/',
        queryParameters: {'workspace': workspaceId},
      );

      if (response.data is Map<String, dynamic>) {
        return response.data['results'] ?? [];
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener proyectos del workspace: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener proyectos del workspace: $e');
    }
  }
}
