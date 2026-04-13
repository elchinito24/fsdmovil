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

  static Future<List<dynamic>> getProjectHistory(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/history/');
      final data = Map<String, dynamic>.from(response.data);
      return List<dynamic>.from(data['history'] ?? []);
    } catch (e) {
      throw Exception('Error al cargar historial: $e');
    }
  }
}
