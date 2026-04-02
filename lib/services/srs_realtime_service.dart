import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fsdmovil/config/app_config.dart';
import 'package:fsdmovil/services/auth_service.dart';

class PresenceUser {
  final int id;
  final String email;
  final String name;

  const PresenceUser({
    required this.id,
    required this.email,
    required this.name,
  });

  factory PresenceUser.fromJson(Map<String, dynamic> json) {
    final first = (json['first_name'] ?? '').toString().trim();
    final last = (json['last_name'] ?? '').toString().trim();
    final fullName = '$first $last'.trim();

    return PresenceUser(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      email: (json['email'] ?? '').toString(),
      name: fullName.isNotEmpty
          ? fullName
          : (json['email'] ?? 'Usuario').toString(),
    );
  }
}

class FieldPresence {
  final PresenceUser user;
  final String path;
  final String label;
  final String mode;
  final String timestamp;

  const FieldPresence({
    required this.user,
    required this.path,
    required this.label,
    required this.mode,
    required this.timestamp,
  });

  factory FieldPresence.fromJson(Map<String, dynamic> json) {
    return FieldPresence(
      user: PresenceUser.fromJson(
        Map<String, dynamic>.from(json['user'] ?? {}),
      ),
      path: (json['path'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      mode: (json['mode'] ?? 'form').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
    );
  }
}

class CollaborationInitialPayload {
  final int? projectId;
  final Map<String, dynamic> srsData;
  final String? updatedAt;
  final PresenceUser? updatedBy;
  final List<PresenceUser> connectedUsers;

  const CollaborationInitialPayload({
    required this.projectId,
    required this.srsData,
    required this.updatedAt,
    required this.updatedBy,
    required this.connectedUsers,
  });
}

class CollaborationSyncPayload {
  final Map<String, dynamic> srsData;
  final String? updatedAt;
  final PresenceUser? updatedBy;

  const CollaborationSyncPayload({
    required this.srsData,
    required this.updatedAt,
    required this.updatedBy,
  });
}

class CollaborationConflictPayload {
  final String? detail;
  final String? serverUpdatedAt;
  final Map<String, dynamic> serverSrsData;
  final PresenceUser? updatedBy;

  const CollaborationConflictPayload({
    required this.detail,
    required this.serverUpdatedAt,
    required this.serverSrsData,
    required this.updatedBy,
  });
}

typedef OnSessionJoined = void Function(CollaborationInitialPayload payload);
typedef OnSync = void Function(CollaborationSyncPayload payload);
typedef OnConflict = void Function(CollaborationConflictPayload payload);
typedef OnPresenceJoin = void Function(PresenceUser user);
typedef OnPresenceLeave = void Function(int userId);
typedef OnFieldFocus = void Function(FieldPresence presence);
typedef OnFieldBlur = void Function(int userId, String path, String mode);
typedef OnOpen = void Function();
typedef OnClose = void Function();
typedef OnError = void Function(String message);

class SrsRealtimeService {
  final int projectId;
  final OnSessionJoined? onSessionJoined;
  final OnSync? onSync;
  final OnConflict? onConflict;
  final OnPresenceJoin? onPresenceJoin;
  final OnPresenceLeave? onPresenceLeave;
  final OnFieldFocus? onFieldFocus;
  final OnFieldBlur? onFieldBlur;
  final OnOpen? onOpen;
  final OnClose? onClose;
  final OnError? onError;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _retryCount = 0;
  final int _maxRetry = 6;

  SrsRealtimeService({
    required this.projectId,
    this.onSessionJoined,
    this.onSync,
    this.onConflict,
    this.onPresenceJoin,
    this.onPresenceLeave,
    this.onFieldFocus,
    this.onFieldBlur,
    this.onOpen,
    this.onClose,
    this.onError,
  });

  bool get isConnected => _socket?.readyState == WebSocket.open;

  Future<void> connect() async {
    if (_disposed) return;

    if (_socket != null &&
        (_socket!.readyState == WebSocket.open ||
            _socket!.readyState == WebSocket.connecting)) {
      return;
    }

    String? token = AuthService.accessToken;
    if (token == null || token.isEmpty) {
      token = await AuthService.refreshAccessToken();
    }

    if (token == null || token.isEmpty) {
      onError?.call('No hay sesión activa para colaboración en tiempo real.');
      return;
    }

    final wsBase = _buildWsBase();
    final uri =
        '$wsBase/ws/projects/$projectId/srs/?token=${Uri.encodeQueryComponent(token)}';

    try {
      _socket = await WebSocket.connect(uri);
      _retryCount = 0;
      onOpen?.call();

      _subscription = _socket!.listen(
        _handleRawMessage,
        onError: (_) {
          if (_disposed) return;
          onError?.call('Error en la conexión colaborativa.');
        },
        onDone: () async {
          final closeCode = _socket?.closeCode;
          await _cleanupSocket();

          if (_disposed) return;

          onClose?.call();

          if (closeCode == 4401) {
            final refreshed = await AuthService.refreshAccessToken();
            if (refreshed != null && refreshed.isNotEmpty) {
              await connect();
              return;
            }
            onError?.call('Tu sesión expiró para colaboración en tiempo real.');
            return;
          }

          if (closeCode == 4403) {
            onError?.call(
              'No tienes permisos para colaborar en este proyecto.',
            );
            return;
          }

          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (_) {
      onError?.call('No se pudo conectar al WebSocket colaborativo.');
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      await _socket?.close();
    } catch (_) {}

    await _cleanupSocket();
  }

  void sendSrsUpdate({
    required Map<String, dynamic> srsData,
    String? baseUpdatedAt,
  }) {
    _send({
      'type': 'srs.update',
      'payload': {'srs_data': srsData, 'base_updated_at': baseUpdatedAt},
    });
  }

  void sendFieldFocus({
    required String path,
    required String label,
    String mode = 'form',
  }) {
    _send({
      'type': 'presence.field_focus',
      'payload': {'path': path, 'label': label, 'mode': mode},
    });
  }

  void sendFieldBlur({required String path, String mode = 'form'}) {
    _send({
      'type': 'presence.field_blur',
      'payload': {'path': path, 'mode': mode},
    });
  }

  void _send(Map<String, dynamic> data) {
    if (!isConnected) return;
    _socket?.add(jsonEncode(data));
  }

  Future<void> _cleanupSocket() async {
    await _subscription?.cancel();
    _subscription = null;
    _socket = null;
  }

  void _scheduleReconnect() {
    if (_retryCount >= _maxRetry) {
      onError?.call(
        'La conexión colaborativa se cerró y no se pudo reconectar.',
      );
      return;
    }

    final delaySeconds = (1 << _retryCount).clamp(1, 10);
    _retryCount += 1;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_disposed) return;
      connect();
    });
  }

  void _handleRawMessage(dynamic raw) {
    if (raw == null) return;

    Map<String, dynamic> message;
    try {
      message = Map<String, dynamic>.from(jsonDecode(raw.toString()));
    } catch (_) {
      return;
    }

    final type = (message['type'] ?? '').toString();
    final payload = Map<String, dynamic>.from(message['payload'] ?? {});

    switch (type) {
      case 'session.joined':
        final usersRaw = List<dynamic>.from(payload['connected_users'] ?? []);
        final users = usersRaw
            .map((e) => PresenceUser.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        onSessionJoined?.call(
          CollaborationInitialPayload(
            projectId: payload['project_id'] is int
                ? payload['project_id'] as int
                : int.tryParse(payload['project_id']?.toString() ?? ''),
            srsData: Map<String, dynamic>.from(payload['srs_data'] ?? {}),
            updatedAt: payload['updated_at']?.toString(),
            updatedBy: payload['updated_by'] == null
                ? null
                : PresenceUser.fromJson(
                    Map<String, dynamic>.from(payload['updated_by']),
                  ),
            connectedUsers: users,
          ),
        );
        break;

      case 'srs.synced':
        onSync?.call(
          CollaborationSyncPayload(
            srsData: Map<String, dynamic>.from(payload['srs_data'] ?? {}),
            updatedAt: payload['updated_at']?.toString(),
            updatedBy: payload['updated_by'] == null
                ? null
                : PresenceUser.fromJson(
                    Map<String, dynamic>.from(payload['updated_by']),
                  ),
          ),
        );
        break;

      case 'srs.conflict':
        onConflict?.call(
          CollaborationConflictPayload(
            detail: payload['detail']?.toString(),
            serverUpdatedAt: payload['server_updated_at']?.toString(),
            serverSrsData: Map<String, dynamic>.from(
              payload['server_srs_data'] ?? {},
            ),
            updatedBy: payload['updated_by'] == null
                ? null
                : PresenceUser.fromJson(
                    Map<String, dynamic>.from(payload['updated_by']),
                  ),
          ),
        );
        break;

      case 'presence.join':
        final user = payload['user'];
        if (user is Map<String, dynamic>) {
          onPresenceJoin?.call(PresenceUser.fromJson(user));
        }
        break;

      case 'presence.leave':
        final userId = payload['user_id'] is int
            ? payload['user_id'] as int
            : int.tryParse(payload['user_id']?.toString() ?? '') ?? 0;
        onPresenceLeave?.call(userId);
        break;

      case 'presence.field_focus':
        onFieldFocus?.call(FieldPresence.fromJson(payload));
        break;

      case 'presence.field_blur':
        final userId = payload['user_id'] is int
            ? payload['user_id'] as int
            : int.tryParse(payload['user_id']?.toString() ?? '') ?? 0;
        onFieldBlur?.call(
          userId,
          (payload['path'] ?? '').toString(),
          (payload['mode'] ?? 'form').toString(),
        );
        break;

      case 'error':
        onError?.call((payload['detail'] ?? 'Error colaborativo').toString());
        break;

      default:
        break;
    }
  }

  String _buildWsBase() {
    final api = AppConfig.baseUrl.trim();
    final uri = Uri.parse(api);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';

    var path = uri.path;
    if (path.endsWith('/api/v1')) {
      path = path.substring(0, path.length - '/api/v1'.length);
    } else if (path.endsWith('/api/v1/')) {
      path = path.substring(0, path.length - '/api/v1/'.length);
    } else if (path.endsWith('/api')) {
      path = path.substring(0, path.length - '/api'.length);
    } else if (path.endsWith('/api/')) {
      path = path.substring(0, path.length - '/api/'.length);
    }

    final normalizedPath = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;

    return '$scheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}$normalizedPath';
  }
}
