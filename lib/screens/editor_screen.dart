import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/services/srs_realtime_service.dart';
import 'package:fsdmovil/services/srs_word_service.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF252838);
const _fieldBg = Color(0xFF252838);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class EditorScreen extends StatefulWidget {
  final int projectId;

  const EditorScreen({super.key, required this.projectId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // ── Load ──────────────────────────────────────────────────────────────────
  bool loading = true;
  bool saving = false;
  String? errorMessage;

  // ── Editor mode (Formulario / JSON / AI) ─────────────────────────────────
  String _editorMode = 'form'; // 'form' | 'json' | 'ai'

  // ── Ownership ─────────────────────────────────────────────────────────────
  bool _isOwner = true; // assume owner until confirmed otherwise
  String _previousStatus = 'draft'; // status before sending to review

  // ── Document data ─────────────────────────────────────────────────────────
  Map<String, dynamic> _docData = {};
  Map<String, dynamic>? fullResponse;
  String? serverUpdatedAt;
  String? _projectCode;

  // ── Template form config ──────────────────────────────────────────────────
  List<dynamic> _formSections = [];

  // ── Section navigation ────────────────────────────────────────────────────
  String _selectedSectionId = '';

  // ── Realtime ──────────────────────────────────────────────────────────────
  bool _connected = false;
  bool _syncing = false;
  bool _applyingRemote = false;
  String? _lastRealtimeMessage;
  String? _conflictMessage;

  SrsRealtimeService? _realtimeService;
  Timer? _debounceTimer;
  Timer?
  _focusHeartbeat; // re-anuncia el campo activo cada 3s para nuevos usuarios

  // ── Save ──────────────────────────────────────────────────────────────────
  String _saveStatus = 'idle';
  bool _downloading = false;
  bool _saveValidationEnabled = true;
  String? _focusedPath; // campo actualmente enfocado (para enviar blur manual)
  String?
  _focusedLabel; // label del campo enfocado (para re-anunciar al hacer join)

  // ── Presence ──────────────────────────────────────────────────────────────
  final Map<int, PresenceUser> _connectedUsers = {};
  final Map<int, FieldPresence> _fieldPresenceByUser = {};

  // ── Draft (new items not yet committed) ───────────────────────────────────
  final Set<String> _draftObjectPaths = {};
  final Set<String> _draftStringPaths = {};

  // ── Controllers / FocusNodes keyed by dot-path ───────────────────────────
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, FocusNode> _focusNodes = {};

  List<Map<String, String>> get _sections {
    final result = <Map<String, String>>[];
    for (final s in _formSections) {
      result.add({'value': s['id'] as String, 'label': s['title'] as String});
    }
    // Custom sections added by user
    final customIds =
        List<dynamic>.from(_docData['customSectionIds'] as List? ?? []);
    for (final id in customIds) {
      final section = _docData[id] as Map?;
      if (section != null) {
        result.add({
          'value': id as String,
          'label': (section['title'] ?? id) as String,
        });
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    loadSrs();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusHeartbeat?.cancel();
    _realtimeService?.disconnect();
    for (final c in _ctrl.values) c.dispose();
    for (final n in _focusNodes.values) n.dispose();
    super.dispose();
  }

  // ── Path helpers ──────────────────────────────────────────────────────────

  dynamic _getPath(Map<String, dynamic> data, String path) {
    dynamic cur = data;
    for (final p in path.split('.')) {
      if (cur is Map) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  void _setPath(Map<String, dynamic> data, String path, dynamic value) {
    final parts = path.split('.');
    dynamic cur = data;
    for (var i = 0; i < parts.length - 1; i++) {
      if (cur[parts[i]] == null) cur[parts[i]] = <String, dynamic>{};
      cur = cur[parts[i]];
    }
    (cur as Map)[parts.last] = value;
  }

  Map<String, dynamic> _mergeDefaults(
    Map<String, dynamic> data,
    Map<String, dynamic> defaults,
  ) {
    final result = Map<String, dynamic>.from(defaults);
    for (final key in data.keys) {
      if (data[key] is Map && result[key] is Map) {
        result[key] = _mergeDefaults(
          Map<String, dynamic>.from(data[key] as Map),
          Map<String, dynamic>.from(result[key] as Map),
        );
      } else if (data[key] != null) {
        result[key] = data[key];
      }
    }
    return result;
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadSrs() async {
    try {
      final results = await Future.wait([
        ApiService.getProjectSrs(widget.projectId),
        ApiService.getProject(widget.projectId),
      ]);

      final srsResponse = results[0] as Map<String, dynamic>;
      final projectData = results[1] as Map<String, dynamic>;

      final template = Map<String, dynamic>.from(
        projectData['template'] as Map? ?? {},
      );

      final formConfig = Map<String, dynamic>.from(
        template['form_config'] ?? {},
      );
      final formSections = List<dynamic>.from(formConfig['sections'] ?? []);
      final defaultData = Map<String, dynamic>.from(
        template['default_data'] ?? _fallbackDefaultData(),
      );

      final rawSrsData = Map<String, dynamic>.from(
        srsResponse['srs_data'] ?? {},
      );
      final docData = _mergeDefaults(rawSrsData, defaultData);

      final metaMap = Map<String, dynamic>.from(
        docData['metadata'] as Map? ?? {},
      );
      if ((metaMap['projectName'] as String? ?? '').trim().isEmpty) {
        final name = (projectData['name'] ?? '').toString().trim();
        if (name.isNotEmpty) metaMap['projectName'] = name;
      }
      if ((metaMap['projectCode'] as String? ?? '').trim().isEmpty) {
        final code =
            (projectData['code'] ??
                    projectData['projectCode'] ??
                    projectData['project_code'] ??
                    '')
                .toString()
                .trim();
        if (code.isNotEmpty) metaMap['projectCode'] = code;
      }
      if ((metaMap['description'] as String? ?? '').trim().isEmpty) {
        final desc = (projectData['description'] ?? '').toString().trim();
        if (desc.isNotEmpty) metaMap['description'] = desc;
      }
      docData['metadata'] = metaMap;

      final rawCode =
          (projectData['code'] ??
                  projectData['projectCode'] ??
                  projectData['project_code'] ??
                  srsResponse['code'] ??
                  srsResponse['projectCode'] ??
                  srsResponse['project_code'])
              ?.toString()
              .trim();

      _initControllersForSections(docData, formSections);

      final pName = (projectData['name'] ?? '').toString().trim();
      final pCode =
          (projectData['code'] ??
                  projectData['projectCode'] ??
                  projectData['project_code'] ??
                  '')
              .toString()
              .trim();
      final pDesc = (projectData['description'] ?? '').toString().trim();

      for (final entry in _ctrl.entries) {
        if (entry.value.text.trim().isNotEmpty) continue;
        final p = entry.key;
        if ((p.endsWith('.projectName') ||
                p == 'projectName' ||
                p == 'metadata.projectName') &&
            pName.isNotEmpty) {
          entry.value.text = pName;
          _setPath(docData, p, pName);
        } else if ((p.endsWith('.projectCode') ||
                p == 'projectCode' ||
                p == 'metadata.projectCode') &&
            pCode.isNotEmpty) {
          entry.value.text = pCode;
          _setPath(docData, p, pCode);
        } else if (p.toLowerCase().contains('description') &&
            pDesc.isNotEmpty) {
          entry.value.text = pDesc;
          _setPath(docData, p, pDesc);
        }
      }

      final ownerField = projectData['owner'];
      final ownerEmail =
          (ownerField is Map ? ownerField['email'] : ownerField)
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';
      final currentEmail = (AuthService.userEmail ?? '').trim().toLowerCase();
      final isOwner = ownerEmail.isNotEmpty && ownerEmail == currentEmail;

      final rawStatus = (projectData['status'] ?? 'draft').toString().trim();

      final isNewSrs =
          rawSrsData.isEmpty ||
          (_getPath(
                    Map<String, dynamic>.from(srsResponse['srs_data'] ?? {}),
                    'metadata.projectName',
                  )?.toString() ??
                  '')
              .trim()
              .isEmpty;

      setState(() {
        _docData = docData;
        _formSections = formSections;
        _selectedSectionId = formSections.isNotEmpty
            ? (formSections.first['id'] as String)
            : '';
        fullResponse = srsResponse;
        serverUpdatedAt = srsResponse['updated_at']?.toString();
        _projectCode = (rawCode != null && rawCode.isNotEmpty) ? rawCode : null;
        _isOwner = isOwner;
        _previousStatus = rawStatus == 'review' ? 'in_progress' : rawStatus;
        loading = false;
        errorMessage = null;
      });

      if (isNewSrs) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            final saved = await ApiService.updateProjectSrs(widget.projectId, {
              'srs_data': _docData,
            });

            if (!mounted) return;

            final savedSrs = Map<String, dynamic>.from(
              saved['srs_data'] ?? _docData,
            );

            _applyingRemote = true;
            _applyDocData(savedSrs);
            _applyingRemote = false;

            setState(() {
              fullResponse = {...?fullResponse, ...saved};
              serverUpdatedAt =
                  saved['updated_at']?.toString() ?? serverUpdatedAt;
              _lastRealtimeMessage = 'Documento inicial guardado';
            });
          } catch (_) {}
        });
      }

      await _connectRealtime();
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  Map<String, dynamic> _fallbackDefaultData() => {
    'metadata': {
      'projectName': '',
      'projectCode': '',
      'version': '1.0',
      'owner': '',
      'organization': '',
      'createdAt': '',
      'status': 'draft',
    },
    'teamMembers': [],
    'revisionHistory': [],
    'approvalHistory': [],
    'introduction': {
      'purpose': '',
      'scope': '',
      'definitions': [],
      'references': [],
      'overview': '',
    },
    'overallDescription': {
      'productPerspective': '',
      'productFunctions': '',
      'userClasses': [],
      'operatingEnvironment': '',
      'constraints': '',
      'assumptions': '',
    },
    'requirements': {'functional': [], 'nonFunctional': []},
    'externalInterfaces': {
      'user': '',
      'hardware': '',
      'software': '',
      'communications': '',
    },
    'appendices': [],
  };

  void _initControllersForSections(
    Map<String, dynamic> docData,
    List<dynamic> formSections,
  ) {
    for (final c in _ctrl.values) c.dispose();
    _ctrl.clear();
    for (final section in formSections) {
      for (final sub in (section['subsections'] as List? ?? [])) {
        final type = sub['type'] as String?;
        if (type == 'array') continue;
        for (final field in (sub['fields'] as List? ?? [])) {
          final path = field['path'] as String?;
          final fieldType = field['type'] as String? ?? 'text';
          if (path == null || fieldType == 'select') continue;
          final value = _getPath(docData, path)?.toString() ?? '';
          final c = TextEditingController(text: value);
          final capturedPath = path;
          c.addListener(() {
            if (_applyingRemote) return;
            _setPath(_docData, capturedPath, c.text);
            _scheduleRealtimeSync();
          });
          _ctrl[path] = c;
        }
      }
    }
  }

  void _applyDocData(Map<String, dynamic> newData) {
    _docData = newData;
    for (final entry in _ctrl.entries) {
      final newVal = _getPath(newData, entry.key)?.toString() ?? '';
      if (entry.value.text != newVal) entry.value.text = newVal;
    }
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  Future<void> _connectRealtime() async {
    _realtimeService?.disconnect();

    _realtimeService = SrsRealtimeService(
      projectId: widget.projectId,
      onOpen: () {
        if (!mounted) return;
        setState(() {
          _connected = true;
          _lastRealtimeMessage = 'Colaboración en tiempo real conectada';
        });
      },
      onClose: () {
        if (!mounted) return;
        setState(() => _connected = false);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => _lastRealtimeMessage = message);
      },
      onSessionJoined: (payload) {
        if (!mounted) return;
        _applyingRemote = true;
        _applyDocData(Map<String, dynamic>.from(payload.srsData));
        _applyingRemote = false;
        setState(() {
          serverUpdatedAt = payload.updatedAt;
          _connectedUsers
            ..clear()
            ..addEntries(payload.connectedUsers.map((u) => MapEntry(u.id, u)));
          _lastRealtimeMessage =
              'Sesión colaborativa iniciada con ${payload.connectedUsers.length} usuario(s)';
        });
      },
      onSync: (payload) {
        if (!mounted) return;
        // Cancela el debounce pendiente para que el próximo envío
        // use el nuevo base_updated_at y no genere conflicto.
        _debounceTimer?.cancel();
        _applyingRemote = true;
        _applyDocData(Map<String, dynamic>.from(payload.srsData));
        _applyingRemote = false;
        setState(() {
          serverUpdatedAt = payload.updatedAt;
          _syncing = false;
          _conflictMessage = null;
          _lastRealtimeMessage = payload.updatedBy != null
              ? 'Actualizado por ${payload.updatedBy!.name}'
              : 'Documento sincronizado';
        });
      },
      onConflict: (payload) {
        if (!mounted) return;
        // Resuelve el conflicto automáticamente: acepta la versión del
        // servidor y actualiza la base para que el próximo envío sea válido.
        _debounceTimer?.cancel();
        _applyingRemote = true;
        _applyDocData(Map<String, dynamic>.from(payload.serverSrsData));
        _applyingRemote = false;
        setState(() {
          _syncing = false;
          serverUpdatedAt = payload.serverUpdatedAt;
          _conflictMessage = null;
          _lastRealtimeMessage = payload.updatedBy != null
              ? 'Sincronizado con cambios de ${payload.updatedBy!.name}'
              : 'Documento sincronizado';
        });
      },
      onPresenceJoin: (user) {
        if (!mounted) return;
        setState(() => _connectedUsers[user.id] = user);
        // Re-anuncia el campo activo al nuevo usuario para que vea quién lo ocupa
        if (_focusedPath != null) {
          _realtimeService?.sendFieldFocus(
            path: _focusedPath!,
            label: _focusedLabel ?? _focusedPath!,
          );
        }
      },
      onPresenceLeave: (userId) {
        if (!mounted) return;
        setState(() {
          _connectedUsers.remove(userId);
          _fieldPresenceByUser.remove(userId);
        });
      },
      onFieldFocus: (presence) {
        if (!mounted) return;
        final myId = AuthService.userId;
        if (myId != null && myId == presence.user.id) return;

        // Race condition: si tenemos el mismo campo activo, cedemos — el otro llegó primero
        if (_focusedPath != null && _focusedPath == presence.path) {
          _focusHeartbeat?.cancel();
          _realtimeService?.sendFieldBlur(path: _focusedPath!);
          _focusedPath = null;
          _focusedLabel = null;
          FocusScope.of(context).unfocus();
        }

        setState(() {
          _connectedUsers[presence.user.id] = presence.user;
          _fieldPresenceByUser[presence.user.id] = presence;
        });
      },
      onFieldBlur: (userId, path, mode) {
        if (!mounted) return;
        setState(() => _fieldPresenceByUser.remove(userId));
      },
    );

    await _realtimeService!.connect();
  }

  void _scheduleRealtimeSync() {
    if (_applyingRemote) return;
    if (_realtimeService == null || !_realtimeService!.isConnected) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1200), () {
      setState(() => _syncing = true);
      _realtimeService!.sendSrsUpdate(
        srsData: _docData,
        baseUpdatedAt: serverUpdatedAt,
      );
    });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> saveChanges() async {
    if (_focusedPath != null) {
      _focusHeartbeat?.cancel();
      _realtimeService?.sendFieldBlur(path: _focusedPath!);
      _focusedPath = null;
      _focusedLabel = null;
    }

    FocusScope.of(context).unfocus();

    if (_saveValidationEnabled) {
      final projectName = (_getPath(_docData, 'metadata.projectName') ?? '')
          .toString()
          .trim();

      if (projectName.isEmpty) {
        if (!mounted) return;
        setState(() => _saveStatus = 'error');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El nombre del proyecto es obligatorio'),
            backgroundColor: _pink,
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _saveStatus = 'idle');
        });
        return;
      }
    }

    setState(() {
      saving = true;
      _saveStatus = 'saving';
    });

    try {
      final response = await ApiService.updateProjectSrs(widget.projectId, {
        'srs_data': _docData,
      });

      if (!mounted) return;

      final savedSrs = Map<String, dynamic>.from(
        response['srs_data'] ?? _docData,
      );

      _applyingRemote = true;
      _applyDocData(savedSrs);
      _applyingRemote = false;

      setState(() {
        fullResponse = {...?fullResponse, ...response};
        serverUpdatedAt = response['updated_at']?.toString() ?? serverUpdatedAt;
        _saveStatus = 'saved';
        _lastRealtimeMessage = 'Cambios guardados manualmente';
        _conflictMessage = null;
        _syncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios guardados correctamente'),
          backgroundColor: Color(0xFF1BC47D),
        ),
      );

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _saveStatus = 'idle');
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saveStatus = 'error';
        _syncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: _pink,
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _saveStatus = 'idle');
      });
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }
  // ── Send for review (non-owners) ──────────────────────────────────────────

  Future<void> sendForReview() async {
    if (saving) return;

    // Confirm with user.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Enviar a revisión',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Tus cambios se guardarán como una versión nueva y el dueño del proyecto podrá aceptarlos o rechazarlos. ¿Continuar?',
          style: TextStyle(color: _textGrey, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      saving = true;
      _saveStatus = 'saving';
    });

    try {
      // 1. Save a named version snapshot so the owner can restore it if rejected.
      await ApiService.createProjectVersion(widget.projectId, {
        'srs_data': _docData,
        'label': 'Revisión pendiente',
        'created_by_email': AuthService.userEmail ?? '',
      });

      // 2. Write the new SRS data live.
      await ApiService.updateProjectSrs(widget.projectId, {
        'srs_data': _docData,
      });

      // 3. Mark the project as "in review".
      await ApiService.partialUpdateProject(widget.projectId, {
        'status': 'review',
      });

      if (!mounted) return;
      setState(() {
        _saveStatus = 'saved';
        _lastRealtimeMessage = 'Enviado a revisión';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios enviados a revisión'),
          backgroundColor: Color(0xFF1BC47D),
        ),
      );
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _saveStatus = 'idle');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveStatus = 'error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar: $e'), backgroundColor: _pink),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _saveStatus = 'idle');
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _downloadDocx() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final data = fullResponse != null
          ? {...fullResponse!, 'srs_data': _docData}
          : {'srs_data': _docData};
      await SrsWordService.generateAndOpen(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar documento: $e'),
          backgroundColor: _pink,
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Widget _buildSaveButton() {
    Color color;
    String label;
    Widget iconWidget;

    if (_saveStatus == 'saving') {
      color = const Color(0xFF55A6FF);
      label = _isOwner ? 'Guardando' : 'Enviando';
      iconWidget = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    } else if (_saveStatus == 'saved') {
      color = const Color(0xFF1BC47D);
      label = _isOwner ? 'Guardado' : 'Enviado';
      iconWidget = const Icon(
        Icons.check_circle_outline_rounded,
        size: 16,
        color: Color(0xFF1BC47D),
      );
    } else if (_saveStatus == 'error') {
      color = _pink;
      label = 'Error';
      iconWidget = const Icon(
        Icons.error_outline_rounded,
        size: 16,
        color: _pink,
      );
    } else if (_isOwner) {
      color = Theme.of(context).colorScheme.onSurface;
      label = 'Guardar';
      iconWidget = const Icon(
        Icons.save_outlined,
        size: 16,
        color: Colors.white,
      );
    } else {
      color = _pink;
      label = 'Enviar revisión';
      iconWidget = const Icon(Icons.send_rounded, size: 16, color: _pink);
    }

    return TextButton.icon(
      onPressed: saving
          ? null
          : _isOwner
          ? saveChanges
          : sendForReview,
      icon: iconWidget,
      label: Text(
        label,
        style: TextStyle(
          color: saving ? _textGrey : color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Future<void> _showConflictDialog({
    required Map<String, dynamic> serverSrsData,
    required String? serverUpdatedAt,
    required String? updatedBy,
  }) async {
    if (!mounted) return;

    final useServer =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'Conflicto detectado',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              updatedBy == null || updatedBy.isEmpty
                  ? 'Otro cambio llegó desde el servidor antes de que se aplicara tu edición. ¿Quieres cargar la versión más reciente?'
                  : '$updatedBy cambió el documento antes de que se aplicara tu edición. ¿Quieres cargar la versión más reciente?',
              style: const TextStyle(color: _textGrey, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Mantener mi vista',
                  style: TextStyle(color: _textGrey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cargar servidor'),
              ),
            ],
          ),
        ) ??
        false;

    if (!useServer) return;

    _applyingRemote = true;
    _applyDocData(serverSrsData);
    _applyingRemote = false;

    setState(() {
      this.serverUpdatedAt = serverUpdatedAt;
      _conflictMessage = null;
      _lastRealtimeMessage = 'Se cargó la versión más reciente del servidor';
    });
  }

  // ── Decorations ───────────────────────────────────────────────────────────

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textGrey),
    filled: true,
    fillColor: _fieldBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _pink, width: 1.5),
    ),
  );

  // ── Dynamic field renderer ────────────────────────────────────────────────

  Widget _buildField(Map<String, dynamic> fieldConfig) {
    final path = (fieldConfig['path'] ?? fieldConfig['id']) as String;
    final type = fieldConfig['type'] as String? ?? 'text';
    final label = fieldConfig['label'] as String? ?? path;
    final hint = fieldConfig['placeholder'] as String? ?? '';
    final isRequired = fieldConfig['required'] as bool? ?? false;
    final rows = fieldConfig['rows'] as int? ?? 1;

    final labelWidget = Text(
      label + (isRequired ? ' *' : ''),
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );

    if (type == 'select') {
      final options = List<Map<String, dynamic>>.from(
        fieldConfig['options'] as List? ?? [],
      );
      final currentValue = _getPath(_docData, path)?.toString();
      final validValue = options.any((o) => o['value'] == currentValue)
          ? currentValue
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelWidget,
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: validValue,
                isExpanded: true,
                dropdownColor: Theme.of(context).colorScheme.surface,
                iconEnabledColor: _textGrey,
                hint: Text(
                  hint.isEmpty ? 'Seleccionar...' : hint,
                  style: const TextStyle(color: _textGrey),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: options
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt['value'] as String,
                        child: Text(opt['label'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _setPath(_docData, path, val));
                    _scheduleRealtimeSync();
                  }
                },
              ),
            ),
          ),
        ],
      );
    }

    final controller = _ctrl.putIfAbsent(path, () {
      final c = TextEditingController(
        text: _getPath(_docData, path)?.toString() ?? '',
      );
      final capturedPath = path;
      c.addListener(() {
        if (_applyingRemote) return;
        _setPath(_docData, capturedPath, c.text);
        _scheduleRealtimeSync();
      });
      return c;
    });

    // FocusNode: fuente de verdad para focus/blur — no depende de onTap/onEditingComplete
    final focusNode = _focusNodes.putIfAbsent(path, () {
      final node = FocusNode();
      node.addListener(() {
        if (!mounted) return;
        if (node.hasFocus) {
          _focusedPath = path;
          _focusedLabel = label;
          _realtimeService?.sendFieldFocus(path: path, label: label);
          _focusHeartbeat?.cancel();
          _focusHeartbeat = Timer.periodic(
            const Duration(seconds: 3),
            (_) => _realtimeService?.sendFieldFocus(path: path, label: label),
          );
        } else {
          _focusHeartbeat?.cancel();
          if (_focusedPath == path) {
            _focusedPath = null;
            _focusedLabel = null;
          }
          _realtimeService?.sendFieldBlur(path: path);
        }
      });
      return node;
    });

    final maxLines = (type == 'textarea') ? (rows > 1 ? rows : 4) : 1;
    final keyboardType = (type == 'email')
        ? TextInputType.emailAddress
        : TextInputType.text;

    final activePresence = _fieldPresenceByUser.values
        .where((p) => p.path == path)
        .toList();
    final isTakenByOther = activePresence.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWidget,
        const SizedBox(height: 10),
        Opacity(
          opacity: isTakenByOther ? 0.45 : 1.0,
          child: IgnorePointer(
            ignoring: isTakenByOther,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: _dec(hint.isEmpty ? label : hint),
            ),
          ),
        ),
        if (isTakenByOther) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: activePresence
                .map(
                  (p) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_rounded,
                        size: 11,
                        color: _textGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${p.user.name} está modificando este campo',
                        style: const TextStyle(
                          color: _textGrey,
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // ── Confirm delete dialog ─────────────────────────────────────────────────

  Future<bool> _confirmDelete(BuildContext ctx, String itemName) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (dCtx) => AlertDialog(
            backgroundColor: Theme.of(dCtx).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'Confirmar eliminación',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              '¿Seguro que deseas eliminar "$itemName"? Esta acción no se puede deshacer.',
              style: const TextStyle(color: _textGrey, height: 1.45),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: _textGrey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Object-array subsection ───────────────────────────────────────────────

  Widget _buildObjectArraySubsection(Map<String, dynamic> sub) {
    final title = sub['title'] as String? ?? '';
    final path = sub['path'] as String;
    final itemFields = List<Map<String, dynamic>>.from(
      sub['itemFields'] as List? ?? [],
    );
    final titleClean = title.replaceAll(RegExp(r'^[\d\.]+ ?'), '');
    final addLabel = 'Agregar ${titleClean.toLowerCase()}';
    final items = List<dynamic>.from(_getPath(_docData, path) as List? ?? []);
    final hasDraft = _draftObjectPaths.contains(path);

    Map<String, dynamic> emptyItem() {
      final e = <String, dynamic>{};
      for (final f in itemFields) e[f['id'] as String] = '';
      // Auto-generate requirement ID based on existing count
      if (e.containsKey('id')) {
        if (path == 'requirements.functional') {
          final next = (items.length + 1).toString().padLeft(3, '0');
          e['id'] = 'RF-$next';
        } else if (path == 'requirements.nonFunctional') {
          final next = (items.length + 1).toString().padLeft(3, '0');
          e['id'] = 'RNF-$next';
        }
      }
      return e;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleClean.toUpperCase(),
          style: const TextStyle(
            color: _textGrey,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(items.length, (i) {
          final item = Map<String, dynamic>.from(items[i] as Map? ?? {});
          final isBusy = _fieldPresenceByUser.values.any(
            (p) => p.path.startsWith('$path.$i.'),
          );
          return _ObjectArrayItemCard(
            key: ValueKey('$path.$i.${items.length}'),
            item: item,
            itemFields: itemFields,
            index: i,
            pathPrefix: '$path.$i',
            fieldPresenceByUser: _fieldPresenceByUser,
            isDraft: false,
            isBusy: isBusy,
            onFocus: (presencePath, label) {
              _focusedPath = presencePath;
              _focusedLabel = label;
              _realtimeService?.sendFieldFocus(
                path: presencePath,
                label: label,
              );
              _focusHeartbeat?.cancel();
              _focusHeartbeat = Timer.periodic(
                const Duration(seconds: 3),
                (_) => _realtimeService?.sendFieldFocus(
                  path: presencePath,
                  label: label,
                ),
              );
            },
            onBlur: (presencePath) {
              _focusHeartbeat?.cancel();
              if (_focusedPath == presencePath) {
                _focusedPath = null;
                _focusedLabel = null;
              }
              _realtimeService?.sendFieldBlur(path: presencePath);
            },
            onChanged: (updated) {
              setState(() {
                final list = List<dynamic>.from(
                  _getPath(_docData, path) as List? ?? [],
                );
                list[i] = updated;
                _setPath(_docData, path, list);
              });
              _scheduleRealtimeSync();
            },
            onRemove: () async {
              final itemTitle =
                  item['titulo']?.toString() ??
                  item['nombre']?.toString() ??
                  item['name']?.toString() ??
                  'elemento ${i + 1}';
              final confirm = await _confirmDelete(context, itemTitle);
              if (!confirm || !mounted) return;
              setState(() {
                final list = List<dynamic>.from(
                  _getPath(_docData, path) as List? ?? [],
                );
                list.removeAt(i);
                _setPath(_docData, path, list);
              });
              _scheduleRealtimeSync();
            },
          );
        }),
        if (hasDraft)
          _ObjectArrayItemCard(
            key: ValueKey('$path.draft'),
            item: emptyItem(),
            itemFields: itemFields,
            index: items.length,
            pathPrefix: '$path.${items.length}',
            fieldPresenceByUser: <int, FieldPresence>{},
            isDraft: true,
            isBusy: false,
            onFocus: (_, __) {},
            onBlur: (_) {},
            onChanged: (_) {},
            onRemove: () async {},
            onConfirm: (data) {
              setState(() {
                final list = List<dynamic>.from(
                  _getPath(_docData, path) as List? ?? [],
                );
                list.add(data);
                _setPath(_docData, path, list);
                _draftObjectPaths.remove(path);
              });
              _scheduleRealtimeSync();
            },
            onCancel: () {
              setState(() => _draftObjectPaths.remove(path));
            },
          ),
        if (!hasDraft)
          _buildAddButton(addLabel, () {
            setState(() => _draftObjectPaths.add(path));
          }),
      ],
    );
  }

  // ── String-array subsection ───────────────────────────────────────────────

  Widget _buildStringArraySubsection(Map<String, dynamic> sub) {
    final title = sub['title'] as String? ?? '';
    final path = sub['path'] as String;
    final itemLabel = sub['itemLabel'] as String? ?? 'Elemento';
    final titleClean = title.replaceAll(RegExp(r'^[\d\.]+ ?'), '');
    final items = List<dynamic>.from(_getPath(_docData, path) as List? ?? []);
    final hasDraft = _draftStringPaths.contains(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleClean.toUpperCase(),
          style: const TextStyle(
            color: _textGrey,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(items.length, (i) {
          final ctrlKey = '$path.__str__$i';
          final presencePath = '$path.$i';
          final fieldLabel = '$itemLabel ${i + 1}';

          final c = _ctrl.putIfAbsent(ctrlKey, () {
            final ctrl = TextEditingController(text: items[i].toString());
            ctrl.addListener(() {
              if (_applyingRemote) return;
              final list = List<dynamic>.from(
                _getPath(_docData, path) as List? ?? [],
              );
              if (i < list.length) list[i] = ctrl.text;
              _setPath(_docData, path, list);
              _scheduleRealtimeSync();
            });
            return ctrl;
          });

          final focusNode = _focusNodes.putIfAbsent(ctrlKey, () {
            final node = FocusNode();
            node.addListener(() {
              if (!mounted) return;
              if (node.hasFocus) {
                _focusedPath = presencePath;
                _focusedLabel = fieldLabel;
                _realtimeService?.sendFieldFocus(
                  path: presencePath,
                  label: fieldLabel,
                );
                _focusHeartbeat?.cancel();
                _focusHeartbeat = Timer.periodic(
                  const Duration(seconds: 3),
                  (_) => _realtimeService?.sendFieldFocus(
                    path: presencePath,
                    label: fieldLabel,
                  ),
                );
              } else {
                _focusHeartbeat?.cancel();
                if (_focusedPath == presencePath) {
                  _focusedPath = null;
                  _focusedLabel = null;
                }
                _realtimeService?.sendFieldBlur(path: presencePath);
              }
            });
            return node;
          });

          final activePresence = _fieldPresenceByUser.values
              .where((p) => p.path == presencePath)
              .toList();
          final isTakenByOther = activePresence.isNotEmpty;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity: isTakenByOther ? 0.45 : 1.0,
                        child: IgnorePointer(
                          ignoring: isTakenByOther,
                          child: TextField(
                            controller: c,
                            focusNode: focusNode,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            decoration: _dec(fieldLabel),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isTakenByOther)
                      Tooltip(
                        message: 'Alguien está editando este elemento',
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: _textGrey,
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () async {
                          final confirm = await _confirmDelete(
                            context,
                            fieldLabel,
                          );
                          if (!confirm || !mounted) return;
                          _focusNodes['$path.__str__$i']?.dispose();
                          _focusNodes.remove('$path.__str__$i');
                          _ctrl['$path.__str__$i']?.dispose();
                          _ctrl.remove('$path.__str__$i');
                          for (var j = i + 1; j < items.length; j++) {
                            final oldKey = '$path.__str__$j';
                            final newKey = '$path.__str__${j - 1}';
                            final movedCtrl = _ctrl.remove(oldKey);
                            if (movedCtrl != null) _ctrl[newKey] = movedCtrl;
                            final movedNode = _focusNodes.remove(oldKey);
                            if (movedNode != null)
                              _focusNodes[newKey] = movedNode;
                          }
                          setState(() {
                            final list = List<dynamic>.from(
                              _getPath(_docData, path) as List? ?? [],
                            );
                            list.removeAt(i);
                            _setPath(_docData, path, list);
                          });
                          _scheduleRealtimeSync();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: _textGrey,
                          ),
                        ),
                      ),
                  ],
                ),
                if (isTakenByOther) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: activePresence
                        .map(
                          (p) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit_rounded,
                                size: 11,
                                color: _textGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${p.user.name} está modificando este campo',
                                style: const TextStyle(
                                  color: _textGrey,
                                  fontSize: 11.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          );
        }),
        if (hasDraft)
          Builder(
            builder: (ctx) {
              final draftKey = '$path.__draft__';
              final draftCtrl = _ctrl.putIfAbsent(
                draftKey,
                () => TextEditingController(),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: draftCtrl,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dec('$itemLabel nuevo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _ctrl['$path.__draft__']?.dispose();
                          _ctrl.remove('$path.__draft__');
                          setState(() => _draftStringPaths.remove(path));
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _fieldBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _borderColor),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: _textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final val = (_ctrl['$path.__draft__']?.text ?? '')
                            .trim();
                        _ctrl['$path.__draft__']?.dispose();
                        _ctrl.remove('$path.__draft__');
                        setState(() {
                          _draftStringPaths.remove(path);
                          if (val.isNotEmpty) {
                            final list = List<dynamic>.from(
                              _getPath(_docData, path) as List? ?? [],
                            );
                            list.add(val);
                            _setPath(_docData, path, list);
                          }
                        });
                        if (val.isNotEmpty) _scheduleRealtimeSync();
                      },
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Guardar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          )
        else
          _buildAddButton('Agregar ${itemLabel.toLowerCase()}', () {
            setState(() => _draftStringPaths.add(path));
          }),
      ],
    );
  }

  // ── Add button ────────────────────────────────────────────────────────────

  Widget _buildAddButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0x1AE8365D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x55E8365D)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: _pink),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _pink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section content builder ───────────────────────────────────────────────

  Widget _buildSectionContent() {
    if (_selectedSectionId == '_usuarios') return _buildUsuariosSection();
    if (_selectedSectionId == '_configuracion') {
      return _buildConfiguracionSection();
    }
    if (_selectedSectionId.startsWith('custom_')) {
      return _buildCustomSectionContent(_selectedSectionId);
    }

    final sectionConfig = _formSections.cast<Map>().firstWhere(
      (s) => s['id'] == _selectedSectionId,
      orElse: () => <String, dynamic>{},
    );
    if (sectionConfig.isEmpty) return const SizedBox();

    final subsections = List<dynamic>.from(
      sectionConfig['subsections'] as List? ?? [],
    );
    final widgets = <Widget>[];

    for (var i = 0; i < subsections.length; i++) {
      final sub = Map<String, dynamic>.from(subsections[i] as Map);
      final type = sub['type'] as String?;

      if (i > 0) {
        widgets.add(const SizedBox(height: 24));
        widgets.add(Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 1));
        widgets.add(const SizedBox(height: 20));
      }

      if (type == 'array') {
        final itemType = sub['itemType'] as String?;
        widgets.add(
          itemType == 'string'
              ? _buildStringArraySubsection(sub)
              : _buildObjectArraySubsection(sub),
        );
      } else {
        final subTitle = sub['title'] as String? ?? '';
        final fields = List<Map<String, dynamic>>.from(
          sub['fields'] as List? ?? [],
        );
        widgets.add(
          Text(
            subTitle.toUpperCase(),
            style: const TextStyle(
              color: _textGrey,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 12));
        for (var j = 0; j < fields.length; j++) {
          widgets.add(_buildField(fields[j]));
          if (j < fields.length - 1) widgets.add(const SizedBox(height: 16));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // ── Custom section renderer ───────────────────────────────────────────────

  Widget _buildCustomSectionContent(String sectionId) {
    final section =
        Map<String, dynamic>.from(_docData[sectionId] as Map? ?? {});
    final title = (section['title'] ?? sectionId) as String;
    final subIds =
        List<dynamic>.from(section['subsectionIds'] as List? ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                final confirmed = await _confirmDelete(context, title);
                if (!confirmed) return;
                setState(() {
                  final ids = List<dynamic>.from(
                      _docData['customSectionIds'] as List? ?? []);
                  ids.remove(sectionId);
                  _docData['customSectionIds'] = ids;
                  // Clean up controllers for all subsections
                  final sec = Map<String, dynamic>.from(
                      _docData[sectionId] as Map? ?? {});
                  for (final subId
                      in List<dynamic>.from(
                          sec['subsectionIds'] as List? ?? [])) {
                    _ctrl.remove('$sectionId.$subId.content')?.dispose();
                    _focusNodes
                        .remove('$sectionId.$subId.content')
                        ?.dispose();
                  }
                  _docData.remove(sectionId);
                  _selectedSectionId = _sections.isNotEmpty
                      ? _sections.first['value']!
                      : '';
                });
                _scheduleRealtimeSync();
              },
              child: const Icon(Icons.delete_outline_rounded,
                  color: _textGrey, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Subsections ─────────────────────────────────────────────
        if (subIds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Aún no hay subsecciones. Agrega una para comenzar.',
              style: const TextStyle(
                  color: _textGrey, fontSize: 13, height: 1.4),
            ),
          ),

        for (var i = 0; i < subIds.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: 20),
            Divider(color: Theme.of(context).colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 20),
          ],
          _buildCustomSubsection(sectionId, subIds[i] as String),
        ],

        const SizedBox(height: 20),
        // ── Add subsection button ───────────────────────────────────
        _buildAddButton('Agregar subsección', () {
          _showAddSubsectionDialog(sectionId);
        }),
      ],
    );
  }

  Widget _buildCustomSubsection(String sectionId, String subId) {
    final section =
        Map<String, dynamic>.from(_docData[sectionId] as Map? ?? {});
    final sub =
        Map<String, dynamic>.from(section[subId] as Map? ?? {});
    final subTitle = (sub['title'] ?? subId) as String;
    final contentPath = '$sectionId.$subId.content';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                final confirmed =
                    await _confirmDelete(context, subTitle);
                if (!confirmed) return;
                setState(() {
                  final sec = Map<String, dynamic>.from(
                      _docData[sectionId] as Map? ?? {});
                  final ids = List<dynamic>.from(
                      sec['subsectionIds'] as List? ?? []);
                  ids.remove(subId);
                  sec['subsectionIds'] = ids;
                  sec.remove(subId);
                  _docData[sectionId] = sec;
                  _ctrl.remove(contentPath)?.dispose();
                  _focusNodes.remove(contentPath)?.dispose();
                });
                _scheduleRealtimeSync();
              },
              child: const Icon(Icons.delete_outline_rounded,
                  color: _textGrey, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildField({
          'path': contentPath,
          'label': 'Contenido',
          'type': 'textarea',
          'rows': 4,
          'placeholder': 'Escribe el contenido...',
        }),
      ],
    );
  }

  void _showAddSubsectionDialog(String sectionId) {
    final titleCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              const Icon(Icons.add_box_outlined, color: _pink, size: 22),
              const SizedBox(width: 10),
              Text(
                'Nueva subsección',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dale un título a esta subsección.',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                cursorColor: _pink,
                decoration: InputDecoration(
                  hintText: 'Ej: Objetivo, Alcance...',
                  hintStyle: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontSize: 14),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _pink, width: 1.5),
                  ),
                ),
                onSubmitted: (_) =>
                    _submitNewSubsection(ctx, sectionId, titleCtrl),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  _submitNewSubsection(ctx, sectionId, titleCtrl),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Agregar',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }

  void _submitNewSubsection(
      BuildContext ctx, String sectionId, TextEditingController titleCtrl) {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final subId = 'sub_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      final sec = Map<String, dynamic>.from(
          _docData[sectionId] as Map? ?? {});
      final ids =
          List<dynamic>.from(sec['subsectionIds'] as List? ?? []);
      ids.add(subId);
      sec['subsectionIds'] = ids;
      sec[subId] = {'title': title, 'content': ''};
      _docData[sectionId] = sec;
    });
    _scheduleRealtimeSync();
    Navigator.pop(ctx);
  }

  // ── Add section dialog ────────────────────────────────────────────────────

  void _showAddSectionDialog() {
    final titleCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              const Icon(Icons.post_add_rounded, color: _pink, size: 22),
              const SizedBox(width: 10),
              Text(
                'Nueva sección',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dale un nombre a tu sección personalizada.',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 13,
                    height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                cursorColor: _pink,
                decoration: InputDecoration(
                  hintText: 'Ej: Glosario, Restricciones...',
                  hintStyle: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontSize: 14),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: _pink, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _submitNewSection(ctx, titleCtrl),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              onPressed: () => _submitNewSection(ctx, titleCtrl),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Crear',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }

  void _submitNewSection(
      BuildContext ctx, TextEditingController titleCtrl) {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final id =
        'custom_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      final ids = List<dynamic>.from(
          _docData['customSectionIds'] as List? ?? []);
      ids.add(id);
      _docData['customSectionIds'] = ids;
      _docData[id] = {'title': title, 'description': ''};
      _selectedSectionId = id;
    });
    _scheduleRealtimeSync();
    Navigator.pop(ctx);
  }

  // ── Usuarios section ──────────────────────────────────────────────────────

  Widget _buildUsuariosSection() {
    final users = _connectedUsers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visualiza los usuarios con acceso y su rol en este documento.',
          style: TextStyle(color: _textGrey, height: 1.45),
        ),
        const SizedBox(height: 16),
        if (users.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_off_outlined, color: _textGrey, size: 18),
                SizedBox(width: 10),
                Text(
                  'Solo tú tienes esta sesión abierta',
                  style: TextStyle(color: _textGrey, fontSize: 13.5),
                ),
              ],
            ),
          )
        else
          ...users.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _fieldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _pink.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: _pink.withOpacity(0.4)),
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: _pink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Activo en esta sesión',
                            style: TextStyle(color: _textGrey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x22E8365D),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x55E8365D)),
                      ),
                      child: const Text(
                        'EDITOR',
                        style: TextStyle(
                          color: _pink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Configuración section ─────────────────────────────────────────────────

  Widget _buildConfiguracionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personaliza el comportamiento del editor para este documento.',
          style: TextStyle(color: _textGrey, height: 1.45),
        ),
        const SizedBox(height: 20),
        const Text(
          'GUARDADO',
          style: TextStyle(
            color: _textGrey,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validación al guardar',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _saveValidationEnabled
                          ? 'GUARDAR mostrará error si hay campos obligatorios vacíos. El autoguardado nunca valida.'
                          : 'La validación está desactivada. Se guardará sin verificar campos.',
                      style: const TextStyle(
                        color: _textGrey,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: _saveValidationEnabled,
                activeColor: _pink,
                onChanged: (val) =>
                    setState(() => _saveValidationEnabled = val),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final connectedUsers = _connectedUsers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final sections = _sections;

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _pink))
            : errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _borderColor)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          color: _cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: _borderColor),
                          ),
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                          ),
                          onSelected: (value) {
                            if (value == 'preview') {
                              context.push('/preview/${widget.projectId}');
                            } else if (value == 'download') {
                              _downloadDocx();
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'preview',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Vista previa',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'download',
                              enabled: !_downloading,
                              child: Row(
                                children: [
                                  _downloading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _pink,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.download_outlined,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _downloading
                                        ? 'Generando...'
                                        : 'Descargar DOCX',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // ── Secondary controls bar ───────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _borderColor)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _EditorModeTab(
                            label: 'FORMULARIO',
                            active: _editorMode == 'form',
                            onTap: () => setState(() => _editorMode = 'form'),
                          ),
                          const SizedBox(width: 4),
                          _EditorModeTab(
                            label: 'JSON',
                            active: _editorMode == 'json',
                            onTap: () => setState(() => _editorMode = 'json'),
                          ),
                          const SizedBox(width: 4),
                          _EditorModeTab(
                            label: 'AI',
                            icon: Icons.auto_awesome_rounded,
                            active: _editorMode == 'ai',
                            onTap: () => setState(() => _editorMode = 'ai'),
                          ),
                          const SizedBox(width: 12),
                          ...connectedUsers.take(3).map((u) {
                            final initials = u.name.isNotEmpty
                                ? u.name.trim()[0].toUpperCase()
                                : '?';
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Tooltip(
                                message: u.name,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _pink,
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (_focusedPath != null) {
                          _focusHeartbeat?.cancel();
                          _realtimeService?.sendFieldBlur(path: _focusedPath!);
                          _focusedPath = null;
                          _focusedLabel = null;
                        }
                        FocusScope.of(context).unfocus();
                      },
                      behavior: HitTestBehavior.translucent,
                      child: _editorMode == 'json'
                          ? _JsonView(data: _docData)
                          : _editorMode == 'ai'
                          ? _AiView(
                              projectId: widget.projectId,
                              onApplied: () async {
                                setState(() => loading = true);
                                await loadSrs();
                              },
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                28,
                              ),
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedSectionId.isNotEmpty
                                          ? _selectedSectionId
                                          : null,
                                      isExpanded: true,
                                      dropdownColor: _cardBg,
                                      iconEnabledColor: _textGrey,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      items: sections
                                          .map(
                                            (s) => DropdownMenuItem<String>(
                                              value: s['value'],
                                              child: Text(s['label']!),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _selectedSectionId = val,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: _cardBg,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: _buildSectionContent(),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Object array item card ────────────────────────────────────────────────────

class _ObjectArrayItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> itemFields;
  final int index;
  final String pathPrefix;
  final Map<int, FieldPresence> fieldPresenceByUser;
  final void Function(String path, String label) onFocus;
  final void Function(String path) onBlur;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final Future<void> Function() onRemove;
  final bool isDraft;
  final bool isBusy;
  final void Function(Map<String, dynamic>)? onConfirm;
  final VoidCallback? onCancel;

  const _ObjectArrayItemCard({
    super.key,
    required this.item,
    required this.itemFields,
    required this.index,
    required this.pathPrefix,
    required this.fieldPresenceByUser,
    required this.onFocus,
    required this.onBlur,
    required this.onChanged,
    required this.onRemove,
    this.isDraft = false,
    this.isBusy = false,
    this.onConfirm,
    this.onCancel,
  });

  @override
  State<_ObjectArrayItemCard> createState() => _ObjectArrayItemCardState();
}

class _ObjectArrayItemCardState extends State<_ObjectArrayItemCard> {
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, FocusNode> _focusNodes = {};
  late Map<String, dynamic> _localData;

  @override
  void initState() {
    super.initState();
    _localData = Map<String, dynamic>.from(widget.item);
    for (final field in widget.itemFields) {
      final fid = field['id'] as String;
      final type = field['type'] as String? ?? 'text';
      if (type == 'select') continue;
      final presencePath = '${widget.pathPrefix}.$fid';
      final label = field['label'] as String? ?? fid;

      final c = TextEditingController(text: _localData[fid]?.toString() ?? '');
      c.addListener(() {
        _localData[fid] = c.text;
        widget.onChanged(Map<String, dynamic>.from(_localData));
      });
      _ctrl[fid] = c;

      final node = FocusNode();
      node.addListener(() {
        if (!mounted) return;
        if (node.hasFocus) {
          widget.onFocus(presencePath, label);
        } else {
          widget.onBlur(presencePath);
        }
      });
      _focusNodes[fid] = node;
    }
  }

  @override
  void didUpdateWidget(covariant _ObjectArrayItemCard old) {
    super.didUpdateWidget(old);
    // Draft items own their local state — never overwrite from parent
    if (widget.isDraft) return;
    // When parent re-syncs data (e.g. remote update), refresh non-focused fields
    if (old.item != widget.item) {
      for (final field in widget.itemFields) {
        final fid = field['id'] as String;
        final type = field['type'] as String? ?? 'text';
        if (type == 'select') {
          _localData[fid] = widget.item[fid];
          continue;
        }
        final node = _focusNodes[fid];
        // Don't overwrite value for the field the user is currently typing in
        if (node != null && node.hasFocus) continue;
        final newVal = widget.item[fid]?.toString() ?? '';
        if (_ctrl[fid]?.text != newVal) {
          _localData[fid] = widget.item[fid];
          _ctrl[fid]?.text = newVal;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    for (final n in _focusNodes.values) n.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textGrey, fontSize: 13),
    filled: true,
    fillColor: _cardBg,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _pink, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDraft ? _pink.withOpacity(0.45) : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.isDraft)
                const Text(
                  'NUEVO',
                  style: TextStyle(
                    color: _pink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                )
              else
                Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    color: _textGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const Spacer(),
              if (widget.isDraft)
                GestureDetector(
                  onTap: widget.onCancel,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _textGrey,
                  ),
                )
              else if (widget.isBusy)
                Tooltip(
                  message: 'Alguien está editando este elemento',
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: _textGrey,
                  ),
                )
              else
                GestureDetector(
                  onTap: () => widget.onRemove(),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _textGrey,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...widget.itemFields.map((field) {
            final fid = field['id'] as String;
            final type = field['type'] as String? ?? 'text';
            final label = field['label'] as String? ?? fid;
            final hint = field['placeholder'] as String? ?? '';
            final rows = field['rows'] as int? ?? 1;
            final presencePath = '${widget.pathPrefix}.$fid';

            final activePresence = widget.fieldPresenceByUser.values
                .where((p) => p.path == presencePath)
                .toList();
            final isTakenByOther = activePresence.isNotEmpty;

            Widget fieldWidget;
            if (type == 'select') {
              final options = List<Map<String, dynamic>>.from(
                field['options'] as List? ?? [],
              );
              final cur = _localData[fid]?.toString();
              final valid = options.any((o) => o['value'] == cur) ? cur : null;
              fieldWidget = Opacity(
                opacity: isTakenByOther ? 0.45 : 1.0,
                child: IgnorePointer(
                  ignoring: isTakenByOther,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: valid,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        iconEnabledColor: _textGrey,
                        hint: const Text(
                          'Seleccionar...',
                          style: TextStyle(color: _textGrey),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        items: options
                            .map(
                              (opt) => DropdownMenuItem<String>(
                                value: opt['value'] as String,
                                child: Text(opt['label'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _localData[fid] = val);
                            widget.onChanged(
                              Map<String, dynamic>.from(_localData),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              );
            } else {
              final maxLines = (type == 'textarea') ? (rows > 1 ? rows : 3) : 1;
              fieldWidget = Opacity(
                opacity: isTakenByOther ? 0.45 : 1.0,
                child: IgnorePointer(
                  ignoring: isTakenByOther,
                  child: TextField(
                    controller: _ctrl[fid],
                    focusNode: _focusNodes[fid],
                    maxLines: maxLines,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _dec(hint.isEmpty ? label : hint),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  fieldWidget,
                  if (isTakenByOther) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: activePresence
                          .map(
                            (p) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 11,
                                  color: _textGrey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${p.user.name} está modificando este campo',
                                  style: const TextStyle(
                                    color: _textGrey,
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
          // Guardar button only shown for draft items
          if (widget.isDraft) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onConfirm?.call(
                  Map<String, dynamic>.from(_localData),
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text(
                  'Guardar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Editor mode tab ───────────────────────────────────────────────────────────

class _EditorModeTab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _EditorModeTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? _pink : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? _pink : _borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: active ? Colors.white : _textGrey),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : _textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── JSON view ─────────────────────────────────────────────────────────────────

class _JsonView extends StatefulWidget {
  final Map<String, dynamic> data;
  const _JsonView({required this.data});

  @override
  State<_JsonView> createState() => _JsonViewState();
}

class _JsonViewState extends State<_JsonView> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _prettyJson(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    _encode(data, buffer, 0);
    return buffer.toString();
  }

  void _encode(dynamic value, StringBuffer buf, int indent) {
    final pad = '  ' * indent;
    if (value is Map) {
      buf.write('{\n');
      final keys = value.keys.toList();
      for (var i = 0; i < keys.length; i++) {
        buf.write('$pad  "${keys[i]}": ');
        _encode(value[keys[i]], buf, indent + 1);
        if (i < keys.length - 1) buf.write(',');
        buf.write('\n');
      }
      buf.write('$pad}');
    } else if (value is List) {
      buf.write('[\n');
      for (var i = 0; i < value.length; i++) {
        buf.write('$pad  ');
        _encode(value[i], buf, indent + 1);
        if (i < value.length - 1) buf.write(',');
        buf.write('\n');
      }
      buf.write('$pad]');
    } else if (value is String) {
      buf.write('"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"');
    } else {
      buf.write('$value');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = _prettyJson(widget.data);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: SelectableText(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              color: cs.onSurface,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ── AI view ───────────────────────────────────────────────────────────────────

class _AiView extends StatefulWidget {
  final int projectId;
  final Future<void> Function() onApplied;

  const _AiView({required this.projectId, required this.onApplied});

  @override
  State<_AiView> createState() => _AiViewState();
}

class _AiViewState extends State<_AiView> {
  bool _loading = false;
  String? _error;
  String? _success;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await ApiService.aiGenerateFullSrs(widget.projectId);
      if (!mounted) return;
      setState(() {
        _success = 'SRS generado correctamente con IA. Recargando...';
        _loading = false;
      });
      await widget.onApplied();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x22E8365D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: _pink,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generación con IA',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Genera el SRS completo automáticamente',
                          style: TextStyle(color: _textGrey, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'La IA analizará la información del proyecto y completará todas las secciones del SRS de forma automática.',
                style: TextStyle(color: _textGrey, fontSize: 13.5, height: 1.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x22E8365D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x55E8365D)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: _pink,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (_success != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x221BC47D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x551BC47D)),
                  ),
                  child: Text(
                    _success!,
                    style: const TextStyle(
                      color: Color(0xFF1BC47D),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Theme.of(context).colorScheme.outlineVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    _loading ? 'Generando...' : 'Generar SRS completo',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RealtimeStatusCard extends StatelessWidget {
  final bool connected;
  final bool syncing;
  final String? lastMessage;
  final String? conflictMessage;
  final List<PresenceUser> connectedUsers;
  final Future<void> Function()? onReconnect;

  const _RealtimeStatusCard({
    required this.connected,
    required this.syncing,
    required this.lastMessage,
    required this.conflictMessage,
    required this.connectedUsers,
    this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = !connected
        ? 'Desconectado'
        : syncing
        ? 'Sincronizando...'
        : 'Conectado en tiempo real';

    final statusColor = !connected
        ? const Color(0xFFFFA94D)
        : syncing
        ? const Color(0xFF55A6FF)
        : const Color(0xFF1BC47D);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              if (!connected && onReconnect != null)
                TextButton.icon(
                  onPressed: () => onReconnect!(),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 15,
                    color: _pink,
                  ),
                  label: const Text(
                    'Reconectar',
                    style: TextStyle(
                      color: _pink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (lastMessage != null && lastMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              lastMessage!,
              style: const TextStyle(
                color: _textGrey,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          if (conflictMessage != null &&
              conflictMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x22E8365D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x55E8365D)),
              ),
              child: Text(
                conflictMessage!,
                style: const TextStyle(
                  color: _pink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Usuarios conectados',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (connectedUsers.isNotEmpty)
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    builder: (_) => _CollaboratorsSheet(users: connectedUsers),
                  ),
                  child: const Text(
                    'Ver todos',
                    style: TextStyle(
                      color: _pink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (connectedUsers.isEmpty)
            const Text(
              'Solo tú en esta sesión por ahora.',
              style: TextStyle(color: _textGrey, fontSize: 13.5),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: connectedUsers.take(4).map((user) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151823),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _CollaboratorsSheet extends StatelessWidget {
  final List<PresenceUser> users;

  const _CollaboratorsSheet({required this.users});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Usuarios en esta sesión',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: _textGrey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${users.length} usuario${users.length == 1 ? '' : 's'} conectado${users.length == 1 ? '' : 's'} ahora mismo',
            style: const TextStyle(color: _textGrey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ...users.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _pink.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: _pink.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: _pink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x22E8365D),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x55E8365D)),
                    ),
                    child: const Text(
                      'Activo',
                      style: TextStyle(
                        color: _pink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
