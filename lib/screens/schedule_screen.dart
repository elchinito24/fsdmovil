import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _projects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.schedule,
      eyebrow: 'Cronograma',
      titleWhite: 'Cronograma ',
      titlePink: 'de actividades',
      description:
          'Selecciona un proyecto para visualizar su diagrama de Gantt.',
      onRefresh: _loadProjects,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: fsdPink)),
      );
    }

    if (_error != null) {
      return _ErrorState(
        message: _error!,
        onRetry: _loadProjects,
      );
    }

    if (_projects.isEmpty) {
      return const _EmptyState();
    }

    return _ProjectList(
      projects: _projects,
      onTap: (id, name, code) {
        context.push(
          '/schedule/$id',
          extra: {'name': name, 'code': code},
        );
      },
    );
  }
}

// ─── Project list ─────────────────────────────────────────────────────────────

class _ProjectList extends StatelessWidget {
  final List<dynamic> projects;
  final void Function(int id, String name, String code) onTap;

  const _ProjectList({required this.projects, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROYECTOS',
          style: TextStyle(
            color: fsdPink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        ...projects.map((p) {
          final id = (p['id'] as num).toInt();
          final name = (p['name'] ?? '').toString();
          final code = (p['code'] ?? '').toString();
          final description = (p['description'] ?? '').toString();
          final taskCount = (p['task_count'] ?? p['tasks_count'] ?? 0) as num;

          return _ProjectCard(
            id: id,
            name: name,
            code: code,
            description: description,
            taskCount: taskCount.toInt(),
            onTap: () => onTap(id, name, code),
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── Project card ─────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final int id;
  final String name;
  final String code;
  final String description;
  final int taskCount;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.taskCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? fsdCardBg : Colors.white;
    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);
    final subColor = isDark ? fsdTextGrey : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fsdPink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: fsdPink,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (code.isNotEmpty)
                    Text(
                      code,
                      style: const TextStyle(
                        color: fsdPink,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  if (code.isNotEmpty) const SizedBox(height: 2),
                  Text(
                    name.isNotEmpty ? name : 'Proyecto $id',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Arrow
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: fsdTextGrey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: fsdPink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 34,
                color: fsdPink,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Sin proyectos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No hay proyectos disponibles\npara mostrar cronogramas.',
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
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: fsdPink),
            const SizedBox(height: 14),
            const Text(
              'Error al cargar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: fsdTextGrey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: fsdPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
