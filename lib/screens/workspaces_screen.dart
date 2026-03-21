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
              backgroundColor: fsdCardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Eliminar espacio de trabajo',
                style: TextStyle(
                  color: Colors.white,
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
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: workspaces.length + 1,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.18,
                          ),
                      itemBuilder: (context, index) {
                        if (index == workspaces.length) {
                          return _CreateWorkspaceTile(
                            onTap: _goToCreateWorkspace,
                          );
                        }

                        final workspace = workspaces[index];

                        return _WorkspaceCard(
                          workspace: workspace,
                          onTap: () =>
                              _goToWorkspaceDetail(workspace['id'] as int),
                          onDelete: () => _deleteWorkspace(workspace),
                        );
                      },
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF171922), Color(0xFF13151D)],
          ),
          boxShadow: [
            BoxShadow(
              color: fsdPink.withOpacity(0.08),
              blurRadius: 28,
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
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: const Color(0xFF232532),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.folder_rounded,
                      color: fsdPink,
                      size: 30,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    color: const Color(0xFF1B1E28),
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
              const SizedBox(height: 18),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
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
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    color: fsdTextGrey,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$members miembro${members == '1' ? '' : 's'}',
                    style: const TextStyle(
                      color: fsdTextGrey,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 18),
                  const Icon(
                    Icons.description_outlined,
                    color: fsdTextGrey,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$projects proyecto${projects == '1' ? '' : 's'}',
                    style: const TextStyle(
                      color: fsdTextGrey,
                      fontSize: 13.5,
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
        height: 265,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: const Color(0xFF3A3D48),
            width: 1.2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          color: const Color(0xFF13151D),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF21242D),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.16),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: fsdTextGrey,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Crear nuevo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Configura un nuevo espacio de trabajo para tu equipo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fsdTextGrey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
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
        color: fsdCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fsdBorderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.workspaces_outlined, color: fsdPink, size: 44),
          SizedBox(height: 14),
          Text(
            'No hay espacios de trabajo todavía',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
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
        color: fsdCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: fsdBorderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: fsdPink, size: 48),
          const SizedBox(height: 14),
          const Text(
            'No pudimos cargar los workspaces',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
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
