import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool loading = true;
  String? errorMessage;
  List<dynamic> projects = [];
  String searchQuery = '';
  String selectedStatus = 'Todos';

  final List<String> statusOptions = const [
    'Todos',
    'draft',
    'in_progress',
    'review',
    'approved',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    try {
      final data = await ApiService.getProjects();

      if (!mounted) return;

      setState(() {
        projects = data;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _goToCreateProject() async {
    await context.push('/create-project');

    if (!mounted) return;

    setState(() {
      loading = true;
    });
    await loadProjects();
  }

  Future<void> _openEditor(int projectId) async {
    await context.push('/editor/$projectId');

    if (!mounted) return;

    setState(() {
      loading = true;
    });
    await loadProjects();
  }

  Future<void> _openPreview(int projectId) async {
    await context.push('/preview/$projectId');

    if (!mounted) return;

    setState(() {
      loading = true;
    });
    await loadProjects();
  }

  Future<void> _deleteProject(dynamic project) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Eliminar proyecto',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                '¿Seguro que quieres eliminar "${project['name']}"? Esta acción no se puede deshacer.',
                style: const TextStyle(color: fsdTextGrey, height: 1.45),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: fsdTextGrey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: fsdPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    final previous = List<dynamic>.from(projects);

    setState(() {
      projects.removeWhere((p) => p['id'] == project['id']);
    });

    try {
      await ApiService.deleteProject(project['id']);
      ApiService.cacheDeletedProject(
          (project['name'] ?? '').toString(), project['id'] as int);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Proyecto eliminado correctamente'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        projects = previous;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar proyecto: $e'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  List<dynamic> get filteredProjects {
    return projects.where((project) {
      final name = (project['name'] ?? '').toString().toLowerCase();
      final code = (project['code'] ?? '').toString().toLowerCase();
      final description = (project['description'] ?? '')
          .toString()
          .toLowerCase();
      final query = searchQuery.trim().toLowerCase();

      final matchesQuery =
          query.isEmpty ||
          name.contains(query) ||
          code.contains(query) ||
          description.contains(query);

      final rawStatus = (project['status'] ?? '').toString().toLowerCase();
      final matchesStatus =
          selectedStatus == 'Todos' ||
          rawStatus == selectedStatus.toLowerCase();

      return matchesQuery && matchesStatus;
    }).toList();
  }

  String _formatStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Borrador';
      case 'in_progress':
        return 'En progreso';
      case 'review':
        return 'En revisión';
      case 'approved':
        return 'Aprobado';
      case 'completed':
        return 'Completado';
      default:
        return status.isEmpty ? 'Sin estado' : status;
    }
  }

  Color _statusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0xFF55A6FF);
      case 'in_progress':
        return const Color(0xFFFFC857);
      case 'review':
        return const Color(0xFFFFC857);
      case 'approved':
        return const Color(0xFF1BC47D);
      case 'completed':
        return const Color(0xFF1BC47D);
      default:
        return fsdTextGrey;
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0x332C7BFF);
      case 'in_progress':
        return const Color(0x33FFC857);
      case 'review':
        return const Color(0x33FFC857);
      case 'approved':
        return const Color(0x331BC47D);
      case 'completed':
        return const Color(0x331BC47D);
      default:
        return const Color(0x22FFFFFF);
    }
  }

  String _formatVersion(dynamic project) {
    final value = project['current_version'] ?? project['version'];
    if (value == null) return 'v1.0';
    return 'v$value';
  }

  String _formatOwner(dynamic project) {
    final owner = project['owner_name']?.toString();
    if (owner != null && owner.trim().isNotEmpty) return owner;
    return 'Sin propietario';
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return 'Sin fecha';

    try {
      final date = DateTime.parse(raw).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleProjects = filteredProjects;

    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.projects,
      eyebrow: '',
      titleWhite: 'Proyectos ',
      titlePink: 'activos',
      description:
          'Monitorea el avance de documentación y los aportes del equipo.',
      action: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _goToCreateProject,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Nuevo proyecto',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: fsdPink,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: fsdPink)),
            )
          : errorMessage != null
          ? _ProjectsErrorState(
              message: errorMessage!,
              onRetry: () {
                setState(() {
                  loading = true;
                });
                loadProjects();
              },
            )
          : RefreshIndicator(
              color: fsdPink,
              onRefresh: loadProjects,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 20),
                  _ProjectsSearchAndFilter(
                    currentValue: searchQuery,
                    selectedStatus: selectedStatus,
                    statusOptions: statusOptions,
                    onSearchChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                    onStatusChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  if (projects.isEmpty)
                    const _EmptyProjectsState()
                  else if (visibleProjects.isEmpty)
                    const _NoSearchResultsState()
                  else
                    Column(
                      children: visibleProjects.map((project) {
                        final status = (project['status'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ProjectCard(
                            project: project,
                            statusLabel: _formatStatusLabel(status),
                            statusTextColor: _statusTextColor(status),
                            statusBgColor: _statusBgColor(status),
                            versionLabel: _formatVersion(project),
                            ownerLabel: _formatOwner(project),
                            updatedAtLabel: _formatDate(project['updated_at']),
                            onOpenEditor: () =>
                                _openEditor(project['id'] as int),
                            onOpenPreview: () =>
                                _openPreview(project['id'] as int),
                            onDelete: () => _deleteProject(project),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ProjectsSearchAndFilter extends StatelessWidget {
  final String currentValue;
  final String selectedStatus;
  final List<String> statusOptions;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;

  const _ProjectsSearchAndFilter({
    required this.currentValue,
    required this.selectedStatus,
    required this.statusOptions,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  String _statusLabel(String value) {
    switch (value) {
      case 'Todos':
        return 'Todos';
      case 'draft':
        return 'Borrador';
      case 'in_progress':
        return 'En progreso';
      case 'review':
        return 'En revisión';
      case 'approved':
        return 'Aprobado';
      case 'completed':
        return 'Completado';
      default:
        return value;
    }
  }

  Widget _searchField(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: TextField(
          onChanged: onSearchChanged,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Buscar proyectos...',
            hintStyle: const TextStyle(color: fsdTextGrey),
            prefixIcon: const Icon(Icons.search_rounded, color: fsdTextGrey),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      );

  Widget _filterDropdown(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedStatus,
            dropdownColor: Theme.of(context).colorScheme.surface,
            iconEnabledColor: Theme.of(context).colorScheme.onSurface,
            isExpanded: true,
            itemHeight: 50,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            items: statusOptions.map((status) {
              return DropdownMenuItem<String>(
                value: status,
                child: Text(_statusLabel(status)),
              );
            }).toList(),
            onChanged: onStatusChanged,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(flex: 3, child: _searchField(context)),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _filterDropdown(context)),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final dynamic project;
  final String statusLabel;
  final Color statusTextColor;
  final Color statusBgColor;
  final String versionLabel;
  final String ownerLabel;
  final String updatedAtLabel;
  final VoidCallback onOpenEditor;
  final VoidCallback onOpenPreview;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.statusLabel,
    required this.statusTextColor,
    required this.statusBgColor,
    required this.versionLabel,
    required this.ownerLabel,
    required this.updatedAtLabel,
    required this.onOpenEditor,
    required this.onOpenPreview,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = project['name']?.toString().trim().isNotEmpty == true
        ? project['name'].toString()
        : 'Proyecto sin nombre';

    final code = project['code']?.toString().trim().isNotEmpty == true
        ? project['code'].toString()
        : 'Sin código';

    final description =
        project['description']?.toString().trim().isNotEmpty == true
        ? project['description'].toString()
        : 'Sin descripción';

    final workspaceName =
        project['workspace_name']?.toString().trim().isNotEmpty == true
        ? project['workspace_name'].toString()
        : 'Sin workspace';

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onOpenEditor,
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: fsdPink.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'editor') onOpenEditor();
                      if (value == 'preview') onOpenPreview();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) {
                      final fg = Theme.of(context).colorScheme.onSurface;
                      return [
                        PopupMenuItem(
                          value: 'editor',
                          child: Row(
                            children: [
                              Icon(Icons.edit_note_rounded, color: fg, size: 18),
                              const SizedBox(width: 10),
                              Text('Abrir editor', style: TextStyle(color: fg)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'preview',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, color: fg, size: 18),
                              const SizedBox(width: 10),
                              Text('Vista previa', style: TextStyle(color: fg)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: fsdPink, size: 18),
                              SizedBox(width: 10),
                              Text('Eliminar', style: TextStyle(color: fsdPink)),
                            ],
                          ),
                        ),
                      ];
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.more_vert_rounded, color: fsdTextGrey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: fsdTextGrey,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MiniInfoChip(
                    icon: Icons.tag_rounded,
                    label: code,
                    color: fsdPink,
                  ),
                  _MiniInfoChip(
                    icon: Icons.layers_outlined,
                    label: workspaceName,
                  ),
                  _MiniInfoChip(
                    icon: Icons.person_outline_rounded,
                    label: ownerLabel,
                  ),
                  _MiniInfoChip(
                    icon: Icons.history_rounded,
                    label: updatedAtLabel,
                  ),
                  _MiniInfoChip(
                    icon: Icons.article_outlined,
                    label: versionLabel,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenEditor,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('Editar SRS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(0, 50),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onOpenPreview,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Vista previa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: fsdPink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        minimumSize: const Size(0, 50),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MiniInfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? fsdTextGrey;
    final textColor = color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 155),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: fsdPink, size: 44),
          const SizedBox(height: 14),
          Text(
            'No se encontraron proyectos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea tu primer proyecto para empezar a trabajar en tu documentación SRS.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResultsState extends StatelessWidget {
  const _NoSearchResultsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: fsdPink, size: 42),
          const SizedBox(height: 14),
          Text(
            'No hay resultados con esos filtros',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prueba cambiando el texto de búsqueda o selecciona otro estado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ProjectsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProjectsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: fsdPink, size: 48),
          const SizedBox(height: 14),
          Text(
            'No pudimos cargar los proyectos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: fsdTextGrey,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: fsdPink,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
