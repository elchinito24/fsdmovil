import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/models/project.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Project> projects = [];
  bool loading = true;
  String? errorMessage;

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
        projects = data.map<Project>((json) => Project.fromJson(json)).toList();
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

  Future<void> refreshProjects() async {
    setState(() => errorMessage = null);
    await loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mis Proyectos',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _pink,
        foregroundColor: Colors.white,
        onPressed: () async {
          await context.push('/create-project');
          if (!mounted) return;
          setState(() => loading = true);
          await loadProjects();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Proyecto'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.85, 0.85),
            radius: 0.9,
            colors: [Color(0x1FE8365D), Colors.transparent],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: loading
              ? const Center(child: CircularProgressIndicator(color: _pink))
              : errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: _borderColor),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: _pink,
                                size: 42,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No se pudieron cargar los proyectos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _textGrey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  setState(() => loading = true);
                                  await loadProjects();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _pink,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: _pink,
                      onRefresh: refreshProjects,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                        children: [
                          const Text(
                            'OVERVIEW',
                            style: TextStyle(
                              color: _pink,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Your ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Projects',
                                  style: TextStyle(
                                    color: _pink,
                                    fontSize: 42,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tienes ${projects.length} proyecto${projects.length == 1 ? '' : 's'} disponible${projects.length == 1 ? '' : 's'}.',
                            style: const TextStyle(
                              color: _textGrey,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 26),
                          if (projects.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: _borderColor),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.folder_open_outlined,
                                    color: _pink,
                                    size: 44,
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'No hay proyectos todavía',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Crea tu primer proyecto para empezar a trabajar en el SRS.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _textGrey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...projects.map(
                              (project) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(23),
                                    child: Dismissible(
                                    key: ValueKey(project.id),
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
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          title: const Text(
                                            'Eliminar proyecto',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          content: Text(
                                            '¿Seguro que quieres eliminar "${project.name}"? Esta acción no se puede deshacer.',
                                            style: const TextStyle(
                                              color: _textGrey,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text(
                                                'Cancelar',
                                                style: TextStyle(
                                                    color: _textGrey),
                                              ),
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
                                      setState(() {
                                        projects.removeWhere(
                                            (p) => p.id == project.id);
                                      });
                                      try {
                                        await ApiService.deleteProject(
                                            project.id);
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Error al eliminar: $e'),
                                            backgroundColor: _pink,
                                          ),
                                        );
                                        setState(() => projects.add(project));
                                      }
                                    },
                                    child: _ProjectCard(
                                      project: project,
                                      onTap: () => context
                                          .push('/editor/${project.id}'),
                                    ),
                                  ),
                                  ),
                                ),
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

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        color: _cardBg,

        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF232532),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: _pink,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Versión ${project.version}',
                    style: const TextStyle(color: _textGrey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
