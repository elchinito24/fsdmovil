import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class WorkspacesScreen extends StatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  State<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends State<WorkspacesScreen> {
  bool loading = true;
  String? errorMessage;
  List<dynamic> workspaces = [];

  @override
  void initState() {
    super.initState();
    loadWorkspaces();
  }

  Future<void> loadWorkspaces() async {
    try {
      final data = await ApiService.getWorkspaces();

      if (!mounted) return;

      setState(() {
        workspaces = data;
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

  Future<void> _goToCreateWorkspace() async {
    await context.push('/create-workspace');

    if (!mounted) return;

    setState(() {
      loading = true;
    });
    await loadWorkspaces();
  }

  Future<void> _goToWorkspaceDetail(int workspaceId) async {
    await context.push('/workspace/$workspaceId');

    if (!mounted) return;

    setState(() {
      loading = true;
    });
    await loadWorkspaces();
  }

  Future<void> _deleteWorkspace(dynamic workspace) async {
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
                'Eliminar espacio de trabajo',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: Text(
                '¿Seguro que quieres eliminar "${workspace['name']}"? Esta acción no se puede deshacer.',
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

    final previous = List<dynamic>.from(workspaces);

    setState(() {
      workspaces.removeWhere((w) => w['id'] == workspace['id']);
    });

    try {
      await ApiService.deleteWorkspace(workspace['id']);
      ApiService.cacheDeletedWorkspace(
          (workspace['name'] ?? '').toString(), workspace['id'] as int);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Workspace eliminado correctamente'),
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
        workspaces = previous;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar workspace: $e'),
          backgroundColor: fsdPink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.workspaces,
      eyebrow: 'Resumen',
      titleWhite: 'Tus ',
      titlePink: 'espacios de trabajo',
      description: 'Administra tus proyectos activos y entornos colaborativos.',
      action: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _goToCreateWorkspace,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Nuevo espacio de trabajo',
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
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
          ? _WorkspacesErrorState(
              message: errorMessage!,
              onRetry: () {
                setState(() {
                  loading = true;
                });
                loadWorkspaces();
              },
            )
          : RefreshIndicator(
              color: fsdPink,
              onRefresh: loadWorkspaces,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  if (workspaces.isEmpty) ...[
                    const _EmptyWorkspacesState(),
                    const SizedBox(height: 16),
                    _CreateWorkspaceTile(onTap: _goToCreateWorkspace),
                  ] else ...[
                    Column(
                      children: [
                        ...workspaces.asMap().entries.map((entry) {
                          final workspace = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _WorkspaceCard(
                              workspace: workspace,
                              onTap: () =>
                                  _goToWorkspaceDetail(workspace['id'] as int),
                              onDelete: () => _deleteWorkspace(workspace),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final dynamic workspace;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WorkspaceCard({
    required this.workspace,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = workspace['name']?.toString().trim().isNotEmpty == true
        ? workspace['name'].toString()
        : 'Workspace';
    final description =
        workspace['description']?.toString().trim().isNotEmpty == true
        ? workspace['description'].toString()
        : 'Sin descripción';
    final members = workspace['member_count']?.toString() ?? '0';
    final projects = workspace['project_count']?.toString() ?? '0';

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x55E8365D), width: 1.1),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: fsdPink.withOpacity(0.08),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_rounded,
                      color: fsdPink,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'open') onTap();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(
                              Icons.open_in_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Abrir',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: fsdPink,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text('Eliminar', style: TextStyle(color: fsdPink)),
                          ],
                        ),
                      ),
                    ],
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
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: fsdTextGrey,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$members miembro${members == '1' ? '' : 's'}',
                    style: const TextStyle(
                      color: fsdTextGrey,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.description_outlined,
                    color: fsdTextGrey,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$projects proyecto${projects == '1' ? '' : 's'}',
                    style: const TextStyle(
                      color: fsdTextGrey,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
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

class _CreateWorkspaceTile extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateWorkspaceTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1.2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: fsdTextGrey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Crear nuevo espacio de trabajo',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
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

class _EmptyWorkspacesState extends StatelessWidget {
  const _EmptyWorkspacesState();

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
          const Icon(Icons.workspaces_outlined, color: fsdPink, size: 44),
          const SizedBox(height: 14),
          Text(
            'No hay espacios de trabajo todavía',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Crea tu primer espacio para comenzar a organizar proyectos y documentos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _WorkspacesErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _WorkspacesErrorState({required this.message, required this.onRetry});

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
            'No pudimos cargar los workspaces',
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
