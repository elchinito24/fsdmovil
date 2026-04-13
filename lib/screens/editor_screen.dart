import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/services/srs_realtime_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _cardBg = Color(0xFF191B24);
const _fieldBg = Color(0xFF1E2030);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class _FieldSpec {
  final String key;
  final String label;
  final String hint;
  final int maxLines;
  final String path;

  const _FieldSpec({
    required this.key,
    required this.label,
    required this.hint,
    required this.path,
    this.maxLines = 1,
  });
}

class EditorScreen extends StatefulWidget {
  final int projectId;

  const EditorScreen({super.key, required this.projectId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String selectedSection = 'portada';
  bool loading = true;
  bool saving = false;
  String? errorMessage;

  Map<String, dynamic>? fullResponse;
  Map<String, dynamic>? srs;
  String? serverUpdatedAt;

  bool _connected = false;
  bool _syncing = false;
  bool _applyingRemote = false;
  String? _lastRealtimeMessage;
  String? _conflictMessage;

  SrsRealtimeService? _realtimeService;
  Timer? _debounceTimer;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<int, PresenceUser> _connectedUsers = {};
  final Map<int, FieldPresence> _fieldPresenceByUser = {};

  final List<Map<String, String>> sections = const [
    {'value': 'portada', 'label': '1. Portada'},
    {'value': 'introduccion', 'label': '2. Introducción'},
    {'value': 'descripcion', 'label': '3. Descripción General'},
    {'value': 'requisitos', 'label': '4. Requisitos Específicos'},
  ];

  late final Map<String, List<_FieldSpec>> sectionSpecs;

  @override
  void initState() {
    super.initState();
    _buildSpecs();
    _initializeFields();
    loadSrs();
  }

  void _buildSpecs() {
    sectionSpecs = {
      'portada': const [
        _FieldSpec(
          key: 'projectName',
          label: 'Nombre del Proyecto',
          hint: 'Ingrese nombre del proyecto',
          path: 'metadata.projectName',
        ),
        _FieldSpec(
          key: 'projectCode',
          label: 'Código del Proyecto',
          hint: 'Ingrese código del proyecto',
          path: 'metadata.projectCode',
        ),
        _FieldSpec(
          key: 'version',
          label: 'Versión',
          hint: 'Ingrese versión',
          path: 'metadata.version',
        ),
        _FieldSpec(
          key: 'date',
          label: 'Fecha',
          hint: 'dd/mm/aaaa',
          path: 'metadata.createdAt',
        ),
        _FieldSpec(
          key: 'author',
          label: 'Autor(es)',
          hint: 'Ingrese autor(es)',
          path: 'metadata.owner',
        ),
        _FieldSpec(
          key: 'organization',
          label: 'Organización',
          hint: 'Ingrese organización',
          path: 'metadata.organization',
        ),
      ],
      'introduccion': const [
        _FieldSpec(
          key: 'purpose',
          label: 'Propósito',
          hint: 'Ingrese el propósito',
          path: 'introduction.purpose',
          maxLines: 4,
        ),
        _FieldSpec(
          key: 'scope',
          label: 'Alcance',
          hint: 'Ingrese el alcance',
          path: 'introduction.scope',
          maxLines: 4,
        ),
        _FieldSpec(
          key: 'overview',
          label: 'Visión General',
          hint: 'Ingrese la visión general',
          path: 'introduction.overview',
          maxLines: 4,
        ),
        _FieldSpec(
          key: 'references',
          label: 'Referencias',
          hint: 'Una referencia por línea',
          path: 'introduction.references',
          maxLines: 5,
        ),
        _FieldSpec(
          key: 'definitions',
          label: 'Definiciones, Acrónimos y Abreviaturas',
          hint: 'Formato: Término: Definición',
          path: 'introduction.definitions',
          maxLines: 6,
        ),
      ],
      'descripcion': const [
        _FieldSpec(
          key: 'productPerspective',
          label: 'Perspectiva del Producto',
          hint: 'Ingrese la perspectiva del producto',
          path: 'overallDescription.productPerspective',
          maxLines: 4,
        ),
        _FieldSpec(
          key: 'productFunctions',
          label: 'Funciones del Producto',
          hint: 'Ingrese las funciones del producto',
          path: 'overallDescription.productFunctions',
          maxLines: 4,
        ),
        _FieldSpec(
          key: 'userClasses',
          label: 'Clases de Usuario',
          hint: 'Formato: id | nombre | descripción | características',
          path: 'overallDescription.userClasses',
          maxLines: 6,
        ),
        _FieldSpec(
          key: 'operatingEnvironment',
          label: 'Entorno Operativo',
          hint: 'Ingrese el entorno operativo',
          path: 'overallDescription.operatingEnvironment',
          maxLines: 4,
        ),
        _FieldSpec(
          key: 'constraints',
          label: 'Restricciones',
          hint: 'Ingrese restricciones',
          path: 'overallDescription.constraints',
          maxLines: 4,
        ),
        _FieldSpec(
          key: 'assumptions',
          label: 'Suposiciones y Dependencias',
          hint: 'Ingrese suposiciones y dependencias',
          path: 'overallDescription.assumptions',
          maxLines: 4,
        ),
      ],
      'requisitos': const [
        _FieldSpec(
          key: 'externalInterfaces',
          label: 'Interfaces Externas',
          hint: 'Ingrese las interfaces externas',
          path: 'specificRequirements.externalInterfaces',
          maxLines: 4,
        ),
        _FieldSpec(
          key: 'functionalRequirements',
          label: 'Requisitos Funcionales',
          hint: 'Un requisito por línea',
          path: 'specificRequirements.functionalRequirements',
          maxLines: 6,
        ),
        _FieldSpec(
          key: 'nonFunctionalRequirements',
          label: 'Requisitos No Funcionales',
          hint: 'Un requisito por línea',
          path: 'specificRequirements.nonFunctionalRequirements',
          maxLines: 6,
        ),
        _FieldSpec(
          key: 'businessRules',
          label: 'Reglas de Negocio',
          hint: 'Una regla por línea',
          path: 'specificRequirements.businessRules',
          maxLines: 6,
        ),
        _FieldSpec(
          key: 'useCases',
          label: 'Casos de Uso',
          hint: 'Un caso de uso por línea',
          path: 'specificRequirements.useCases',
          maxLines: 6,
        ),
      ],
    };
  }

  void _initializeFields() {
    for (final specs in sectionSpecs.values) {
      for (final field in specs) {
        final controller = TextEditingController();
        final focusNode = FocusNode();

        controller.addListener(() {
          if (_applyingRemote) return;
          _scheduleRealtimeSync();
        });

        focusNode.addListener(() {
          if (_realtimeService == null) return;

          if (focusNode.hasFocus) {
            _realtimeService!.sendFieldFocus(
              path: field.path,
              label: field.label,
            );
          } else {
            _realtimeService!.sendFieldBlur(path: field.path);
          }
        });

        _controllers[field.key] = controller;
        _focusNodes[field.key] = focusNode;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _realtimeService?.disconnect();

    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }

    super.dispose();
  }

  Future<void> loadSrs() async {
    try {
      final data = await ApiService.getProjectSrs(widget.projectId);
      final srsData = Map<String, dynamic>.from(data['srs_data'] ?? {});

      _applySrsDataToControllers(srsData);

      setState(() {
        fullResponse = data;
        srs = srsData;
        loading = false;
        errorMessage = null;
      });

      await _connectRealtime();
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

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
        setState(() {
          _connected = false;
        });
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _lastRealtimeMessage = message;
        });
      },
      onSessionJoined: (payload) {
        if (!mounted) return;
        _applyingRemote = true;
        _applySrsDataToControllers(payload.srsData);
        _applyingRemote = false;

        setState(() {
          srs = payload.srsData;
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
        _applyingRemote = true;
        _applySrsDataToControllers(payload.srsData);
        _applyingRemote = false;

        setState(() {
          srs = payload.srsData;
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
        setState(() {
          _syncing = false;
          _conflictMessage =
              payload.detail ??
              'Hubo un conflicto porque el documento cambió en el servidor.';
          _lastRealtimeMessage = _conflictMessage;
        });

        _showConflictDialog(
          serverSrsData: payload.serverSrsData,
          serverUpdatedAt: payload.serverUpdatedAt,
          updatedBy: payload.updatedBy?.name,
        );
      },
      onPresenceJoin: (user) {
        if (!mounted) return;
        setState(() {
          _connectedUsers[user.id] = user;
        });
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

        setState(() {
          _connectedUsers[presence.user.id] = presence.user;
          _fieldPresenceByUser[presence.user.id] = presence;
        });
      },
      onFieldBlur: (userId, path, mode) {
        if (!mounted) return;
        setState(() {
          _fieldPresenceByUser.remove(userId);
        });
      },
    );

    await _realtimeService!.connect();
  }

  void _applySrsDataToControllers(Map<String, dynamic> srsData) {
    final metadata = Map<String, dynamic>.from(srsData['metadata'] ?? {});
    final introduction = Map<String, dynamic>.from(
      srsData['introduction'] ?? {},
    );
    final overallDescription = Map<String, dynamic>.from(
      srsData['overallDescription'] ?? {},
    );
    final specificRequirements = Map<String, dynamic>.from(
      srsData['specificRequirements'] ?? {},
    );

    _setText('projectName', _safeText(metadata['projectName']));
    _setText(
      'projectCode',
      _safeText(
        metadata['projectCode'],
        fallback: _safeText(fullResponse?['project_code']),
      ),
    );
    _setText(
      'version',
      _safeText(
        metadata['version'],
        fallback: _safeText(
          srsData['version'],
          fallback: _safeText(fullResponse?['version'], fallback: '1.0'),
        ),
      ),
    );
    _setText('date', _safeText(metadata['createdAt']));
    _setText('author', _safeText(metadata['owner']));
    _setText('organization', _safeText(metadata['organization']));

    _setText('purpose', _safeText(introduction['purpose']));
    _setText('scope', _safeText(introduction['scope']));
    _setText('overview', _safeText(introduction['overview']));
    _setText(
      'references',
      _listToMultiline(List.from(introduction['references'] ?? [])),
    );
    _setText(
      'definitions',
      _definitionsToText(List.from(introduction['definitions'] ?? [])),
    );

    _setText(
      'productPerspective',
      _safeText(overallDescription['productPerspective']),
    );
    _setText(
      'productFunctions',
      _safeText(overallDescription['productFunctions']),
    );
    _setText(
      'userClasses',
      _userClassesToText(List.from(overallDescription['userClasses'] ?? [])),
    );
    _setText(
      'operatingEnvironment',
      _safeText(overallDescription['operatingEnvironment']),
    );
    _setText('constraints', _safeText(overallDescription['constraints']));
    _setText('assumptions', _safeText(overallDescription['assumptions']));

    _setText(
      'externalInterfaces',
      _safeText(specificRequirements['externalInterfaces']),
    );
    _setText(
      'functionalRequirements',
      _listToMultiline(
        List.from(specificRequirements['functionalRequirements'] ?? []),
      ),
    );
    _setText(
      'nonFunctionalRequirements',
      _listToMultiline(
        List.from(specificRequirements['nonFunctionalRequirements'] ?? []),
      ),
    );
    _setText(
      'businessRules',
      _listToMultiline(List.from(specificRequirements['businessRules'] ?? [])),
    );
    _setText(
      'useCases',
      _listToMultiline(List.from(specificRequirements['useCases'] ?? [])),
    );
  }

  void _setText(String key, String value) {
    final controller = _controllers[key];
    if (controller == null) return;
    if (controller.text == value) return;
    controller.text = value;
  }

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _listToMultiline(List items) {
    if (items.isEmpty) return '';
    return items.map((e) => e.toString()).join('\n');
  }

  List<String> _multilineToList(String value) {
    return value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _definitionsToText(List items) {
    if (items.isEmpty) return '';
    return items
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final term = _safeText(data['term']);
          final definition = _safeText(data['definition']);
          return '$term: $definition';
        })
        .join('\n');
  }

  List<Map<String, dynamic>> _textToDefinitions(String value) {
    final lines = value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return lines.map((line) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        final term = parts.first.trim();
        final definition = parts.sublist(1).join(':').trim();
        return {'term': term, 'definition': definition};
      }
      return {'term': line, 'definition': ''};
    }).toList();
  }

  String _userClassesToText(List items) {
    if (items.isEmpty) return '';
    return items
        .map((item) {
          final data = Map<String, dynamic>.from(item);
          final id = _safeText(data['id']);
          final name = _safeText(data['name']);
          final description = _safeText(data['description']);
          final characteristics = _safeText(data['characteristics']);
          return '$id | $name | $description | $characteristics';
        })
        .join('\n');
  }

  List<Map<String, dynamic>> _textToUserClasses(String value) {
    final lines = value
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return lines.map((line) {
      final parts = line.split('|').map((e) => e.trim()).toList();
      return {
        'id': parts.isNotEmpty ? parts[0] : '',
        'name': parts.length > 1 ? parts[1] : '',
        'description': parts.length > 2 ? parts[2] : '',
        'characteristics': parts.length > 3 ? parts[3] : '',
      };
    }).toList();
  }

  Map<String, dynamic> _buildSrsFromControllers() {
    return {
      'metadata': {
        'projectName': _controllers['projectName']!.text.trim(),
        'projectCode': _controllers['projectCode']!.text.trim(),
        'version': _controllers['version']!.text.trim(),
        'createdAt': _controllers['date']!.text.trim(),
        'owner': _controllers['author']!.text.trim(),
        'organization': _controllers['organization']!.text.trim(),
      },
      'introduction': {
        'purpose': _controllers['purpose']!.text.trim(),
        'scope': _controllers['scope']!.text.trim(),
        'overview': _controllers['overview']!.text.trim(),
        'references': _multilineToList(_controllers['references']!.text.trim()),
        'definitions': _textToDefinitions(
          _controllers['definitions']!.text.trim(),
        ),
      },
      'overallDescription': {
        'productPerspective': _controllers['productPerspective']!.text.trim(),
        'productFunctions': _controllers['productFunctions']!.text.trim(),
        'userClasses': _textToUserClasses(
          _controllers['userClasses']!.text.trim(),
        ),
        'operatingEnvironment': _controllers['operatingEnvironment']!.text
            .trim(),
        'constraints': _controllers['constraints']!.text.trim(),
        'assumptions': _controllers['assumptions']!.text.trim(),
      },
      'specificRequirements': {
        'externalInterfaces': _controllers['externalInterfaces']!.text.trim(),
        'functionalRequirements': _multilineToList(
          _controllers['functionalRequirements']!.text.trim(),
        ),
        'nonFunctionalRequirements': _multilineToList(
          _controllers['nonFunctionalRequirements']!.text.trim(),
        ),
        'businessRules': _multilineToList(
          _controllers['businessRules']!.text.trim(),
        ),
        'useCases': _multilineToList(_controllers['useCases']!.text.trim()),
      },
    };
  }

  void _scheduleRealtimeSync() {
    if (_applyingRemote) return;
    if (_realtimeService == null || !_realtimeService!.isConnected) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      final updatedSrs = _buildSrsFromControllers();
      setState(() {
        _syncing = true;
        srs = updatedSrs;
      });

      _realtimeService!.sendSrsUpdate(
        srsData: updatedSrs,
        baseUpdatedAt: serverUpdatedAt,
      );
    });
  }

  Future<void> saveChanges() async {
    try {
      setState(() {
        saving = true;
      });

      final updatedSrs = _buildSrsFromControllers();

      await ApiService.updateProjectSrs(widget.projectId, {
        'srs_data': updatedSrs,
      });

      setState(() {
        srs = updatedSrs;
        _lastRealtimeMessage = 'Cambios guardados manualmente';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios guardados correctamente'),
          backgroundColor: _pink,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: _pink),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        saving = false;
      });
    }
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
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
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
            );
          },
        ) ??
        false;

    if (!useServer) return;

    _applyingRemote = true;
    _applySrsDataToControllers(serverSrsData);
    _applyingRemote = false;

    setState(() {
      srs = serverSrsData;
      this.serverUpdatedAt = serverUpdatedAt;
      _conflictMessage = null;
      _lastRealtimeMessage = 'Se cargó la versión más reciente del servidor';
    });
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
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
  }

  Widget buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Colors.white,
      ),
    );
  }

  Widget buildSingleField(_FieldSpec field) {
    final controller = _controllers[field.key]!;
    final focusNode = _focusNodes[field.key]!;

    final activePresence = _fieldPresenceByUser.values.where(
      (p) => p.path == field.path,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(field.label),
        const SizedBox(height: 10),
        if (activePresence.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activePresence.map((presence) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x22E8365D),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x55E8365D)),
                ),
                child: Text(
                  '${presence.user.name} está aquí',
                  style: const TextStyle(
                    color: _pink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: field.maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: inputDecoration(field.hint),
        ),
      ],
    );
  }

  List<_FieldSpec> get _currentFields => sectionSpecs[selectedSection] ?? [];

  @override
  Widget build(BuildContext context) {
    final connectedUsers = _connectedUsers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      backgroundColor: _darkBg,
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
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Editor colaborativo SRS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: saving ? null : saveChanges,
                          icon: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(saving ? 'Guardando...' : 'Guardar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pink,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      children: [
                        _RealtimeStatusCard(
                          connected: _connected,
                          syncing: _syncing,
                          lastMessage: _lastRealtimeMessage,
                          conflictMessage: _conflictMessage,
                          connectedUsers: connectedUsers,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: sections.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final section = sections[index];
                              final isSelected =
                                  selectedSection == section['value'];

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                    selectedSection = section['value']!;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0x33E8365D)
                                        : _cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? _pink : _borderColor,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      section['label']!,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : _textGrey,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sectionTitle(selectedSection),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Los cambios se sincronizan automáticamente cuando estás conectado.',
                                style: TextStyle(
                                  color: _textGrey,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ..._buildCurrentSectionFields(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _sectionTitle(String sectionValue) {
    switch (sectionValue) {
      case 'portada':
        return 'Portada';
      case 'introduccion':
        return 'Introducción';
      case 'descripcion':
        return 'Descripción General';
      case 'requisitos':
        return 'Requisitos Específicos';
      default:
        return 'Sección';
    }
  }

  List<Widget> _buildCurrentSectionFields() {
    final widgets = <Widget>[];
    final fields = _currentFields;

    for (var i = 0; i < fields.length; i++) {
      widgets.add(buildSingleField(fields[i]));
      if (i != fields.length - 1) {
        widgets.add(const SizedBox(height: 18));
      }
    }

    return widgets;
  }
}

class _RealtimeStatusCard extends StatelessWidget {
  final bool connected;
  final bool syncing;
  final String? lastMessage;
  final String? conflictMessage;
  final List<PresenceUser> connectedUsers;

  const _RealtimeStatusCard({
    required this.connected,
    required this.syncing,
    required this.lastMessage,
    required this.conflictMessage,
    required this.connectedUsers,
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
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
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
          const Text(
            'Usuarios conectados',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
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
              children: connectedUsers.map((user) {
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
