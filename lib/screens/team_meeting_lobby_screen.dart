import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class TeamMeetingLobbyScreen extends StatefulWidget {
  const TeamMeetingLobbyScreen({super.key});

  @override
  State<TeamMeetingLobbyScreen> createState() => _TeamMeetingLobbyScreenState();
}

class _TeamMeetingLobbyScreenState extends State<TeamMeetingLobbyScreen> {
  bool loading = true;
  bool creating = false;
  bool recordingEnabled = true;
  String? errorMessage;

  List<dynamic> workspaces = [];
  List<dynamic> allProjects = [];
  List<dynamic> projects = [];
  List<dynamic> activeMeetings = [];

  String? selectedWorkspaceId;
  String? selectedProjectId;
  String title = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String? _projectWorkspaceId(dynamic project) {
    final candidates = [
      project['workspace'],
      project['workspace_id'],
      project['workspaceId'],
      project['workspace'] is Map ? project['workspace']['id'] : null,
    ];

    for (final candidate in candidates) {
      if (candidate != null) return candidate.toString();
    }
    return null;
  }

  Future<void> _loadInitialData() async {
    try {
      final workspaceData = await ApiService.getWorkspaces();
      final projectData = await ApiService.getProjects();

      if (!mounted) return;

      workspaces = workspaceData;
      allProjects = projectData;

      if (workspaces.isNotEmpty) {
        selectedWorkspaceId = workspaces.first['id'].toString();
      }

      _filterProjectsForWorkspace();
      await _loadActiveMeetings();

      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'No se pudo cargar el lobby de reuniones.';
      });
    }
  }

  void _filterProjectsForWorkspace() {
    projects = allProjects.where((project) {
      return _projectWorkspaceId(project) == selectedWorkspaceId;
    }).toList();

    if (projects.isEmpty) {
      selectedProjectId = null;
    } else {
      final exists = projects.any(
        (p) => p['id'].toString() == selectedProjectId,
      );
      if (!exists) {
        selectedProjectId = projects.first['id'].toString();
      }
    }
  }

  Future<void> _loadActiveMeetings() async {
    try {
      final meetings = await ApiService.getActiveTeamMeetings(
        workspaceId: selectedWorkspaceId != null
            ? int.tryParse(selectedWorkspaceId!)
            : null,
        projectId: selectedProjectId != null
            ? int.tryParse(selectedProjectId!)
            : null,
      );

      if (!mounted) return;

      setState(() {
        activeMeetings = meetings;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        activeMeetings = [];
      });
    }
  }

  Future<void> _createMeeting() async {
    if (selectedWorkspaceId == null || selectedProjectId == null) {
      setState(() {
        errorMessage = 'Selecciona un workspace y un proyecto.';
      });
      return;
    }

    setState(() {
      creating = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.createTeamMeeting(
        workspaceId: int.parse(selectedWorkspaceId!),
        projectId: int.parse(selectedProjectId!),
        title: title.trim(),
        recordingEnabled: recordingEnabled,
      );

      if (!mounted) return;

      final sessionId = result['id'];
      await _loadActiveMeetings();

      if (!mounted) return;
      context.push('/team-meeting-room/$sessionId');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        creating = false;
      });
    }
  }

  void _goHome() {
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goHome();
      },
      child: MainAppShell(
        selectedItem: null,
        eyebrow: 'Reunión de equipo',
        titleWhite: 'Sala de ',
        titlePink: 'reuniones',
        description:
            'Crea una reunión en equipo o únete a una sesión activa del proyecto.',
        showTopNav: false,
        child: loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: CircularProgressIndicator(color: _pink),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Crear reunión',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: selectedProjectId == null
                                  ? null
                                  : () {
                                      context.push(
                                        '/team-meeting-history/${int.parse(selectedProjectId!)}',
                                      );
                                    },
                              icon: const Icon(Icons.history_rounded),
                              label: const Text(
                                'Ver historial de llamadas',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: _borderColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Workspace',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _DropdownBox(
                            value: selectedWorkspaceId,
                            items: workspaces
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e['id'].toString(),
                                    child: Text(
                                      (e['name'] ?? 'Workspace').toString(),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              setState(() {
                                selectedWorkspaceId = value;
                                selectedProjectId = null;
                              });
                              _filterProjectsForWorkspace();
                              setState(() {});
                              await _loadActiveMeetings();
                            },
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Proyecto',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _DropdownBox(
                            value: selectedProjectId,
                            items: projects
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e['id'].toString(),
                                    child: Text(
                                      (e['name'] ?? 'Proyecto').toString(),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: projects.isEmpty
                                ? null
                                : (value) async {
                                    setState(() {
                                      selectedProjectId = value;
                                    });
                                    await _loadActiveMeetings();
                                  },
                          ),
                          if (projects.isEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'No hay proyectos disponibles para el workspace seleccionado.',
                              style: TextStyle(color: _textGrey),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Text(
                            'Título opcional',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            onChanged: (value) => title = value,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Ej. Revisión de requerimientos',
                              hintStyle: const TextStyle(color: _textGrey),
                              filled: true,
                              fillColor: const Color(0xFF1E2030),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: _borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: _borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: _pink),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SwitchListTile(
                            value: recordingEnabled,
                            onChanged: (value) {
                              setState(() {
                                recordingEnabled = value;
                              });
                            },
                            activeColor: _pink,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Grabar para análisis IA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: const Text(
                              'Si activas esta opción, la reunión se grabará para generar resumen, requerimientos y tareas al finalizar.',
                              style: TextStyle(color: _textGrey, height: 1.4),
                            ),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              errorMessage!,
                              style: const TextStyle(color: _pink),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: creating ? null : _createMeeting,
                              icon: const Icon(Icons.video_call_rounded),
                              label: Text(
                                creating ? 'Creando...' : 'Crear reunión',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _pink,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _goHome,
                              icon: const Icon(Icons.home_rounded),
                              label: const Text(
                                'Ir al inicio',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: _borderColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Reuniones activas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (activeMeetings.isEmpty)
                      const _Card(
                        child: Text(
                          'No hay reuniones activas para este filtro.',
                          style: TextStyle(color: _textGrey),
                        ),
                      )
                    else
                      ...activeMeetings.map(
                        (meeting) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MeetingActiveCard(
                            title: (meeting['title'] ?? 'Reunión').toString(),
                            subtitle:
                                '${meeting['project_name'] ?? ''} • ${meeting['workspace_name'] ?? ''}',
                            status: (meeting['status'] ?? '').toString(),
                            onTap: () {
                              context.push(
                                '/team-meeting-room/${meeting['id']}',
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      child: child,
    );
  }
}

class _DropdownBox extends StatelessWidget {
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  const _DropdownBox({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2030),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1B1E28),
          isExpanded: true,
          iconEnabledColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MeetingActiveCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  const _MeetingActiveCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0x22E8365D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.groups_rounded, color: _pink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: _textGrey, height: 1.4),
                    ),
                  ],
                ),
              ),
              Text(
                status,
                style: const TextStyle(
                  color: _pink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
