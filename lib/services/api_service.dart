import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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

  /// Cierra y recrea el adaptador HTTP de Dio.
  /// Llamar cuando la app regresa del background para evitar
  /// conexiones TCP muertas del pool que se quedan colgadas.
  static void resetConnections() {
    _dio.httpClientAdapter = IOHttpClientAdapter();
    _plainDio.httpClientAdapter = IOHttpClientAdapter();
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

  static Future<Map<String, dynamic>> getProject(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener proyecto: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener proyecto: $e');
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

  static Future<void> deleteWorkspace(int workspaceId) async {
    try {
      await _dio.delete('/workspaces/$workspaceId/');
    } on DioException catch (e) {
      throw Exception(
        'Error al eliminar workspace: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al eliminar workspace: $e');
    }
  }

  static Future<void> deleteProject(int projectId) async {
    try {
      await _dio.delete('/projects/$projectId/');
    } on DioException catch (e) {
      throw Exception(
        'Error al eliminar proyecto: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al eliminar proyecto: $e');
    }
  }

  // ── Soft-delete reactivation helpers ─────────────────────────────────────
  // Because the backend soft-deletes via is_active=false, a record with the
  // same name/slug still occupies the unique constraint.
  // We try two strategies in order:
  //   1. Session cache (fastest, same-session deletes)
  //   2. API search by name (works cross-session)
  static final Map<String, int> _deletedWorkspaces = {};
  static final Map<String, int> _deletedProjects = {};

  static void cacheDeletedWorkspace(String name, int id) =>
      _deletedWorkspaces[name.toLowerCase().trim()] = id;

  static void cacheDeletedProject(String name, int id) =>
      _deletedProjects[name.toLowerCase().trim()] = id;

  static int? findDeletedWorkspace(String name) =>
      _deletedWorkspaces[name.toLowerCase().trim()];

  static int? findDeletedProject(String name) =>
      _deletedProjects[name.toLowerCase().trim()];

  /// Searches the workspace list for an inactive workspace by name.
  /// Tries common DRF query params. Returns the id or null if not found.
  static Future<int?> findInactiveWorkspaceByName(String name) async {
    final key = name.toLowerCase().trim();
    // 1. session cache
    final cached = _deletedWorkspaces[key];
    if (cached != null) return cached;
    // 2. fetch all (or search) – try ?search=, fallback to full list
    try {
      final List<dynamic> results = [];
      for (final params in [
        {'search': name, 'is_active': 'false'},
        {'search': name},
        {'is_active': 'false'},
        <String, dynamic>{},
      ]) {
        try {
          final r = await _dio.get('/workspaces/', queryParameters: params);
          final data = r.data;
          final items = data is Map ? (data['results'] ?? []) : (data ?? []);
          results.addAll(items as List);
          if (results.isNotEmpty) break;
        } catch (_) {}
      }
      for (final w in results) {
        if (w is Map &&
            (w['name'] ?? '').toString().toLowerCase().trim() == key) {
          final isActive = w['is_active'];
          if (isActive == false || isActive == 'false') {
            return w['id'] as int?;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Searches the project list for an inactive project by name.
  static Future<int?> findInactiveProjectByName(String name) async {
    final key = name.toLowerCase().trim();
    final cached = _deletedProjects[key];
    if (cached != null) return cached;
    try {
      final List<dynamic> results = [];
      for (final params in [
        {'search': name, 'is_active': 'false'},
        {'search': name},
        {'is_active': 'false'},
        <String, dynamic>{},
      ]) {
        try {
          final r = await _dio.get('/projects/', queryParameters: params);
          final data = r.data;
          final items = data is Map ? (data['results'] ?? []) : (data ?? []);
          results.addAll(items as List);
          if (results.isNotEmpty) break;
        } catch (_) {}
      }
      for (final p in results) {
        if (p is Map &&
            (p['name'] ?? '').toString().toLowerCase().trim() == key) {
          final isActive = p['is_active'];
          if (isActive == false || isActive == 'false') {
            return p['id'] as int?;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> partialUpdateWorkspace(
    int workspaceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response =
          await _dio.patch('/workspaces/$workspaceId/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_parseApiError(e, 'Error al actualizar workspace'));
    } catch (e) {
      throw Exception('Error al actualizar workspace: $e');
    }
  }

  /// Parses Django REST Framework validation error responses into a readable string.
  /// DRF returns errors as Map<field, List<String>> or {detail: String}.
  static String _parseApiError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final parts = <String>[];
      data.forEach((key, value) {
        if (value is List) {
          parts.add(value.map((v) => v.toString()).join(', '));
        } else {
          parts.add(value.toString());
        }
      });
      if (parts.isNotEmpty) return parts.join(' | ');
    }
    if (data is String && data.isNotEmpty) return data;
    return e.message ?? fallback;
  }

  static Future<Map<String, dynamic>> createProject(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/projects/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(_parseApiError(e, 'Error al crear proyecto'));
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
      throw Exception(_parseApiError(e, 'Error al crear workspace'));
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

  static Future<List<dynamic>> getWorkspaceMembers(int workspaceId) async {
    try {
      final response = await _dio.get('/workspaces/$workspaceId/members/');

      if (response.data is List) {
        return List<dynamic>.from(response.data);
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener miembros: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener miembros: $e');
    }
  }

  static Future<Map<String, dynamic>> inviteWorkspaceMember({
    required int workspaceId,
    required String email,
    required String role,
  }) async {
    try {
      final response = await _dio.post(
        '/workspaces/$workspaceId/invite/',
        data: {'email': email.trim().toLowerCase(), 'role': role},
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al invitar miembro: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al invitar miembro: $e');
    }
  }

  static Future<List<dynamic>> getWorkspaceInvitations(int workspaceId) async {
    try {
      final response = await _dio.get('/workspaces/$workspaceId/invitations/');

      if (response.data is List) {
        return List<dynamic>.from(response.data);
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener invitaciones: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener invitaciones: $e');
    }
  }

  static Future<void> cancelWorkspaceInvitation({
    required int workspaceId,
    required int invitationId,
  }) async {
    try {
      await _dio.delete(
        '/workspaces/$workspaceId/invitations/$invitationId/cancel/',
      );
    } on DioException catch (e) {
      throw Exception(
        'Error al cancelar invitación: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al cancelar invitación: $e');
    }
  }

  static Future<Map<String, dynamic>> updateWorkspaceMemberRole({
    required int workspaceId,
    required int memberId,
    required String role,
  }) async {
    try {
      final response = await _dio.patch(
        '/workspaces/$workspaceId/members/$memberId/',
        data: {'role': role},
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al actualizar rol: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al actualizar rol: $e');
    }
  }

  static Future<void> removeWorkspaceMember({
    required int workspaceId,
    required int memberId,
  }) async {
    try {
      await _dio.delete('/workspaces/$workspaceId/members/$memberId/');
    } on DioException catch (e) {
      throw Exception(
        'Error al eliminar miembro: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al eliminar miembro: $e');
    }
  }

  static Future<Map<String, dynamic>> acceptWorkspaceInvitation(
    int invitationId,
  ) async {
    try {
      final response = await _dio.patch(
        '/workspaces/invitations/$invitationId/accept/',
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al aceptar invitación: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al aceptar invitación: $e');
    }
  }

  static Future<Map<String, dynamic>> declineWorkspaceInvitation(
    int invitationId,
  ) async {
    try {
      final response = await _dio.patch(
        '/workspaces/invitations/$invitationId/decline/',
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al rechazar invitación: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al rechazar invitación: $e');
    }
  }

  static Future<List<dynamic>> getNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _dio.get(
        '/notifications/',
        queryParameters: unreadOnly ? {'unread': 'true'} : null,
      );

      if (response.data is Map<String, dynamic>) {
        return List<dynamic>.from(response.data['results'] ?? []);
      }

      if (response.data is List) {
        return List<dynamic>.from(response.data);
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener notificaciones: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener notificaciones: $e');
    }
  }

  static Future<int> getUnreadNotificationsCount() async {
    try {
      final response = await _dio.get('/notifications/unread_count/');
      return int.tryParse(response.data['unread_count']?.toString() ?? '0') ??
          0;
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener conteo de notificaciones: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener conteo de notificaciones: $e');
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(
    int notificationId,
  ) async {
    try {
      final response = await _dio.patch(
        '/notifications/$notificationId/read/',
        data: {},
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al marcar notificación como leída: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al marcar notificación como leída: $e');
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      final response = await _dio.post('/notifications/read_all/', data: {});
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al marcar todas como leídas: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al marcar todas como leídas: $e');
    }
  }

  static Future<Map<String, dynamic>> processMeetingAudio({
    required int projectId,
    required File audioFile,
  }) async {
    try {
      final fileName = audioFile.path.split('/').last;

      final formData = FormData.fromMap({
        'project_id': projectId,
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post('/meetings/process/', data: formData);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al procesar reunión: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al procesar reunión: $e');
    }
  }

  static Future<Map<String, dynamic>> saveMeetingResult({
    required int projectId,
    required String transcript,
    required String summary,
    required List<String> functionalRequirements,
    required List<String> nonFunctionalRequirements,
    required List<String> tasks,
    String? audioFileName,
  }) async {
    try {
      final response = await _dio.post(
        '/meetings/save/',
        data: {
          'project_id': projectId,
          'transcript': transcript,
          'summary': summary,
          'functional_requirements': functionalRequirements,
          'non_functional_requirements': nonFunctionalRequirements,
          'tasks': tasks,
          'audio_file_name': audioFileName,
        },
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al guardar resultado de reunión: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al guardar resultado de reunión: $e');
    }
  }

  static Future<Map<String, dynamic>> createTeamMeeting({
    required int workspaceId,
    required int projectId,
    String title = '',
    bool recordingEnabled = true,
  }) async {
    try {
      final response = await _dio.post(
        '/team-meetings/',
        data: {
          'workspace_id': workspaceId,
          'project_id': projectId,
          'title': title,
          'recording_enabled': recordingEnabled,
        },
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al crear reunión de equipo: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al crear reunión de equipo: $e');
    }
  }

  static Future<List<dynamic>> getActiveTeamMeetings({
    int? workspaceId,
    int? projectId,
  }) async {
    try {
      final query = <String, dynamic>{};

      if (workspaceId != null) query['workspace_id'] = workspaceId;
      if (projectId != null) query['project_id'] = projectId;

      final response = await _dio.get(
        '/team-meetings/active/',
        queryParameters: query.isEmpty ? null : query,
      );

      return List<dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener reuniones activas: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener reuniones activas: $e');
    }
  }

  static Future<Map<String, dynamic>> getTeamMeetingDetail(
    int sessionId,
  ) async {
    try {
      final response = await _dio.get('/team-meetings/$sessionId/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener detalle de reunión: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener detalle de reunión: $e');
    }
  }

  static Future<Map<String, dynamic>> getTeamMeetingJoinToken(
    int sessionId,
  ) async {
    try {
      final response = await _dio.post('/team-meetings/$sessionId/join-token/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener token de reunión: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener token de reunión: $e');
    }
  }

  static Future<void> connectTeamMeetingParticipant(int sessionId) async {
    try {
      await _dio.post('/team-meetings/$sessionId/connect/');
    } on DioException catch (e) {
      throw Exception(
        'Error al marcar participante conectado: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al marcar participante conectado: $e');
    }
  }

  static Future<void> disconnectTeamMeetingParticipant(int sessionId) async {
    try {
      await _dio.post('/team-meetings/$sessionId/disconnect/');
    } on DioException catch (e) {
      throw Exception(
        'Error al marcar participante desconectado: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al marcar participante desconectado: $e');
    }
  }

  static Future<Map<String, dynamic>> endTeamMeeting(int sessionId) async {
    try {
      final response = await _dio.post(
        '/team-meetings/$sessionId/end/',
        options: Options(
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al finalizar reunión: ${_extractErrorMessage(e.response?.data ?? e.message)}',
      );
    } catch (e) {
      throw Exception('Error al finalizar reunión: $e');
    }
  }

  static Future<Map<String, dynamic>> getTeamMeetingDocumentPreview(
    int sessionId,
  ) async {
    try {
      final response = await _dio.get(
        '/team-meetings/$sessionId/document-preview/',
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener vista previa del documento: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener vista previa del documento: $e');
    }
  }

  static String _extractErrorMessage(dynamic errorData) {
    if (errorData == null) {
      return 'No se recibió detalle del error.';
    }

    if (errorData is Map<String, dynamic>) {
      if (errorData['detail'] != null) {
        return errorData['detail'].toString();
      }
      return errorData.toString();
    }

    return errorData.toString();
  }

  static Future<Map<String, dynamic>> processTeamMeetingAi(
    int sessionId,
  ) async {
    try {
      final response = await _dio.post(
        '/team-meetings/$sessionId/process-ai/',
        options: Options(
          receiveTimeout: const Duration(seconds: 180),
          sendTimeout: const Duration(seconds: 180),
        ),
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al procesar reunión con IA: ${_extractErrorMessage(e.response?.data ?? e.message)}',
      );
    } catch (e) {
      throw Exception('Error al procesar reunión con IA: $e');
    }
  }

  static Future<Map<String, dynamic>> applyTeamMeetingAiToSrs({
    required int sessionId,
    required String summary,
    required String transcript,
    required List<String> functionalRequirements,
    required List<String> nonFunctionalRequirements,
    required List<String> tasks,
  }) async {
    try {
      final response = await _dio.post(
        '/team-meetings/$sessionId/apply-ai/',
        data: {
          'summary': summary,
          'transcript': transcript,
          'functional_requirements': functionalRequirements,
          'non_functional_requirements': nonFunctionalRequirements,
          'tasks': tasks,
        },
      );

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al aplicar resultados al SRS: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al aplicar resultados al SRS: $e');
    }
  }

  // ─── AI ──────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getAiProviders() async {
    try {
      final response = await _dio.get('/ai/providers/');
      if (response.data is List) return List<dynamic>.from(response.data);
      return List<dynamic>.from(response.data['results'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener proveedores IA: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener proveedores IA: $e');
    }
  }

  static Future<Map<String, dynamic>> getAiSettings() async {
    try {
      final response = await _dio.get('/ai/settings/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener configuración IA: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener configuración IA: $e');
    }
  }

  static Future<Map<String, dynamic>> updateAiSettings(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/ai/settings/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al actualizar configuración IA: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al actualizar configuración IA: $e');
    }
  }

  static Future<void> deleteAiProviderKey(String provider) async {
    try {
      await _dio.delete('/ai/settings/keys/$provider/');
    } on DioException catch (e) {
      throw Exception(
        'Error al eliminar clave IA: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al eliminar clave IA: $e');
    }
  }

  static Future<Map<String, dynamic>> validateAiKey(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/ai/validate-key/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al validar clave IA: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al validar clave IA: $e');
    }
  }

  // ─── Projects (extended) ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateProject(
    int projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/projects/$projectId/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al actualizar proyecto: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al actualizar proyecto: $e');
    }
  }

  static Future<Map<String, dynamic>> partialUpdateProject(
    int projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch('/projects/$projectId/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al actualizar proyecto: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al actualizar proyecto: $e');
    }
  }

  static Future<Map<String, dynamic>> aiGenerateFullSrs(
    int projectId, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(
        '/projects/$projectId/ai-generate-full/',
        data: data ?? {},
        options: Options(
          receiveTimeout: const Duration(seconds: 180),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al generar SRS completo con IA: ${_extractErrorMessage(e.response?.data ?? e.message)}',
      );
    } catch (e) {
      throw Exception('Error al generar SRS completo con IA: $e');
    }
  }

  static Future<Map<String, dynamic>> aiGenerateSrsSection(
    int projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/projects/$projectId/ai-generate/',
        data: data,
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al generar sección con IA: ${_extractErrorMessage(e.response?.data ?? e.message)}',
      );
    } catch (e) {
      throw Exception('Error al generar sección con IA: $e');
    }
  }

  static Future<List<dynamic>> getProjectAiHistory(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/ai-history/');
      if (response.data is List) return List<dynamic>.from(response.data);
      return List<dynamic>.from(response.data['results'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener historial IA: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener historial IA: $e');
    }
  }

  static Future<List<dynamic>> getProjectChangelog(
    int projectId, {
    String? since,
    String? until,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (since != null) query['since'] = since;
      if (until != null) query['until'] = until;

      final response = await _dio.get(
        '/projects/$projectId/changelog/',
        queryParameters: query.isEmpty ? null : query,
      );
      if (response.data is List) return List<dynamic>.from(response.data);
      return List<dynamic>.from(response.data['results'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener changelog: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener changelog: $e');
    }
  }

  static Future<List<dynamic>> getProjectComments(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/comments/');
      if (response.data is List) return List<dynamic>.from(response.data);
      return List<dynamic>.from(response.data['results'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener comentarios: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener comentarios: $e');
    }
  }

  static Future<Map<String, dynamic>> createProjectComment(
    int projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/projects/$projectId/comments/',
        data: data,
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al crear comentario: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al crear comentario: $e');
    }
  }

  static Future<Map<String, dynamic>> duplicateProject(int projectId) async {
    try {
      final response = await _dio.post('/projects/$projectId/duplicate/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al duplicar proyecto: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al duplicar proyecto: $e');
    }
  }

  static Future<Map<String, dynamic>> getProjectPreview(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/preview/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener vista previa: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener vista previa: $e');
    }
  }

  static Future<Map<String, dynamic>> updateSrsSection(
    int projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch(
        '/projects/$projectId/srs/section/',
        data: data,
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al actualizar sección SRS: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al actualizar sección SRS: $e');
    }
  }

  static Future<Map<String, dynamic>> uploadProjectImage(
    int projectId,
    File imageFile,
  ) async {
    try {
      final fileName = imageFile.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });
      final response = await _dio.post(
        '/projects/$projectId/upload-image/',
        data: formData,
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al subir imagen: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  static Future<List<dynamic>> getProjectVersions(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/versions/');
      if (response.data is List) return List<dynamic>.from(response.data);
      return List<dynamic>.from(response.data['results'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener versiones: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener versiones: $e');
    }
  }

  static Future<Map<String, dynamic>> createProjectVersion(
    int projectId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/projects/$projectId/versions/',
        data: data,
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al crear versión: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al crear versión: $e');
    }
  }

  static Future<Map<String, dynamic>> getProjectVersion(
    int projectId,
    int versionId,
  ) async {
    try {
      final response = await _dio.get(
        '/projects/$projectId/versions/$versionId/',
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener versión: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener versión: $e');
    }
  }

  // ─── Diagrams ────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getDiagrams() async {
    try {
      final response = await _dio.get('/diagrams/');
      if (response.data is List) return List<dynamic>.from(response.data);
      return List<dynamic>.from(response.data['results'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener diagramas: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener diagramas: $e');
    }
  }

  static Future<Map<String, dynamic>> getDiagram(int id) async {
    try {
      final response = await _dio.get('/diagrams/$id/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener diagrama: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener diagrama: $e');
    }
  }

  static Future<Map<String, dynamic>> createDiagram(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/diagrams/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al crear diagrama: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al crear diagrama: $e');
    }
  }

  static Future<Map<String, dynamic>> patchDiagram(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.patch('/diagrams/$id/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al actualizar diagrama: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al actualizar diagrama: $e');
    }
  }

  static Future<void> deleteDiagram(int id) async {
    try {
      await _dio.delete('/diagrams/$id/');
    } on DioException catch (e) {
      throw Exception(
        'Error al eliminar diagrama: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al eliminar diagrama: $e');
    }
  }

  // ─── Documents ───────────────────────────────────────────────────────────

  static Future<List<dynamic>> getDocuments({
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        '/documents/',
        queryParameters: queryParameters,
      );
      if (response.data is List) return List<dynamic>.from(response.data);
      return List<dynamic>.from(response.data['results'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener documentos: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener documentos: $e');
    }
  }

  static Future<Map<String, dynamic>> getDocument(int documentId) async {
    try {
      final response = await _dio.get('/documents/$documentId/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener documento: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener documento: $e');
    }
  }

  // ─── Workspaces (extended) ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateWorkspace(
    int workspaceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put('/workspaces/$workspaceId/', data: data);
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al actualizar workspace: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al actualizar workspace: $e');
    }
  }

  // ─── Templates ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getDefaultTemplate() async {
    try {
      final response = await _dio.get('/templates/default/');
      return Map<String, dynamic>.from(response.data);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> getTemplateById(int templateId) async {
    try {
      final response = await _dio.get('/templates/$templateId/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener plantilla: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener plantilla: $e');
    }
  }

  static Future<Map<String, dynamic>> getTemplateFormConfig(
    int templateId,
  ) async {
    try {
      final response = await _dio.get('/templates/$templateId/form-config/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener configuración de formulario: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener configuración de formulario: $e');
    }
  }

  static Future<Map<String, dynamic>> generateTemplateDirect(
    int templateId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post(
        '/templates/$templateId/generate-direct/',
        data: data,
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al generar desde plantilla: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al generar desde plantilla: $e');
    }
  }

  static Future<Map<String, dynamic>> getTemplateSchema(
    int templateId,
  ) async {
    try {
      final response = await _dio.get('/templates/$templateId/schema/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener esquema de plantilla: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener esquema de plantilla: $e');
    }
  }

  // ─── Auth – users ─────────────────────────────────────────────────────────

  static Future<List<dynamic>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '/auth/users/search/',
        queryParameters: {'q': query},
      );
      if (response.data is List) return List<dynamic>.from(response.data);
      return List<dynamic>.from(response.data['results'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        'Error al buscar usuarios: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al buscar usuarios: $e');
    }
  }

  // ─── Public workspace page ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPublicWorkspacePage({
    required String userHandle,
    required String workspaceSlug,
  }) async {
    try {
      final response = await _dio.get('/u/$userHandle/$workspaceSlug/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener página pública: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener página pública: $e');
    }
  }

  // ─── Notifications (extended) ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotification(
    int notificationId,
  ) async {
    try {
      final response = await _dio.get('/notifications/$notificationId/');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      throw Exception(
        'Error al obtener notificación: ${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception('Error al obtener notificación: $e');
    }
  }
}
