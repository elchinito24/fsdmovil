import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class WorkspaceDetailScreen extends StatefulWidget {
  final int workspaceId;

  const WorkspaceDetailScreen({super.key, required this.workspaceId});

  @override
  State<WorkspaceDetailScreen> createState() => _WorkspaceDetailScreenState();
}

class _WorkspaceDetailScreenState extends State<WorkspaceDetailScreen> {
  bool loading = true;
  String? errorMessage;
  Map<String, dynamic>? workspace;
  List<dynamic> projects = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final ws = await ApiService.getWorkspaceById(widget.workspaceId);
      final pr = await ApiService.getProjectsByWorkspace(widget.workspaceId);

      setState(() {
        workspace = ws;
        projects = pr;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceName = workspace?['name']?.toString() ?? 'Workspace';
    final description =
        workspace?['description']?.toString() ?? 'Sin descripción';
    final memberCount = workspace?['member_count']?.toString() ?? '0';
    final projectCount = workspace?['project_count']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Workspace',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _pink,
        foregroundColor: Colors.white,
        onPressed: () async {
          await context.push('/create-project');
          if (mounted) {
            setState(() {
              loading = true;
            });
            loadData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Proyecto'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.arrow_back_ios_new,
                        color: _textGrey,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Volver a Workspaces',
                        style: TextStyle(color: _textGrey, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  workspaceName,
                  style: const TextStyle(
                    color: _pink,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: _textGrey, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        title: 'Miembros',
                        value: memberCount,
                        subtitle: 'Lista del equipo',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _InfoCard(
                        title: 'Proyectos',
                        value: projectCount,
                        subtitle: 'Dentro del workspace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Proyectos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (projects.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _borderColor),
                    ),
                    child: const Text(
                      'Este workspace no tiene proyectos todavía.',
                      style: TextStyle(color: _textGrey, fontSize: 15),
                    ),
                  )
                else
                  ...projects.map((project) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _borderColor),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: Dismissible(
                            key: ValueKey(project['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 28),
                              color: const Color(0xFF2A0A10),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: _pink,
                                    size: 28,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      color: _pink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: _cardBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text(
                                        'Eliminar proyecto',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      content: Text(
                                        '¿Seguro que quieres eliminar "${project['name']}"? Esta acción no se puede deshacer.',
                                        style: const TextStyle(color: _textGrey),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancelar',
                                              style: TextStyle(color: _textGrey)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _pink,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                            },
                            onDismissed: (_) async {
                              final removed = project;
                              setState(() {
                                projects.removeWhere(
                                    (p) => p['id'] == project['id']);
                              });
                              try {
                                await ApiService.deleteProject(project['id']);
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al eliminar: $e'),
                                    backgroundColor: _pink,
                                  ),
                                );
                                setState(() => projects.add(removed));
                              }
                            },
                            child: _ProjectCard(
                              project: project,
                              onTap: () =>
                                  context.push('/editor/${project['id']}'),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _textGrey,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: _pink,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final dynamic project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = project['name']?.toString() ?? 'Proyecto';
    final description = project['description']?.toString() ?? 'Sin descripción';
    final template =
        project['template_name']?.toString() ?? 'Plantilla no disponible';
    final progress = project['progress']?.toString() ?? '0';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        color: _cardBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: _textGrey, fontSize: 15),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _pink),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                template.toUpperCase(),
                style: const TextStyle(
                  color: _pink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'Progress',
                  style: TextStyle(color: _textGrey, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '$progress%',
                  style: const TextStyle(color: _textGrey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (double.tryParse(progress) ?? 0) / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFF2B2E3B),
                valueColor: const AlwaysStoppedAnimation<Color>(_pink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
