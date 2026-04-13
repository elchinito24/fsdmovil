import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool loading = true;
  String? errorMessage;
  List<dynamic> projects = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final data = await ApiService.getProjects();

      if (!mounted) return;

      final sorted = List<dynamic>.from(data);
      sorted.sort((a, b) {
        final aDate = DateTime.tryParse((a['updated_at'] ?? '').toString());
        final bDate = DateTime.tryParse((b['updated_at'] ?? '').toString());

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      setState(() {
        projects = sorted;
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

  Future<void> _openEditor(int projectId) async {
    await context.push('/editor/$projectId');

    if (!mounted) return;
    setState(() => loading = true);
    await loadHistory();
  }

  Future<void> _openPreview(int projectId) async {
    await context.push('/preview/$projectId');

    if (!mounted) return;
    setState(() => loading = true);
    await loadHistory();
  }

  List<dynamic> get filteredHistory {
    final query = searchQuery.trim().toLowerCase();

    return projects.where((project) {
      final name = (project['name'] ?? '').toString().toLowerCase();
      final code = (project['code'] ?? '').toString().toLowerCase();
      final workspace = (project['workspace_name'] ?? '')
          .toString()
          .toLowerCase();
      final version = (project['current_version'] ?? project['version'] ?? '')
          .toString()
          .toLowerCase();

      return query.isEmpty ||
          name.contains(query) ||
          code.contains(query) ||
          workspace.contains(query) ||
          version.contains(query);
    }).toList();
  }

  String _formatVersion(dynamic project) {
    final value = project['current_version'] ?? project['version'];
    if (value == null || value.toString().trim().isEmpty) return 'v1.0';
    return 'v$value';
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
        return const Color(0xFFFFA94D);
      case 'approved':
        return const Color(0xFF1BC47D);
      case 'completed':
        return const Color(0xFF1BC47D);
      default:
        return Colors.white70;
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return const Color(0x332C7BFF);
      case 'in_progress':
        return const Color(0x33FFC857);
      case 'review':
        return const Color(0x33FFA94D);
      case 'approved':
        return const Color(0x331BC47D);
      case 'completed':
        return const Color(0x331BC47D);
      default:
        return const Color(0x22FFFFFF);
    }
  }

  String _formatDate(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return 'Sin fecha';

    try {
      final date = DateTime.parse(value).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year • $hour:$minute';
    } catch (_) {
      return value;
    }
  }

  int _parseProgress(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.clamp(0, 100);
    if (value is double) return value.round().clamp(0, 100);
    return int.tryParse(value.toString())?.clamp(0, 100) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredHistory;

    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.history,
      eyebrow: 'Seguimiento',
      titleWhite: 'Cambios e ',
      titlePink: 'historial',
      description:
          'Consulta las últimas actualizaciones de tus documentos y proyectos SRS.',
      child: loading
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: fsdPink)),
            )
          : errorMessage != null
          ? _HistoryErrorState(
              message: errorMessage!,
              onRetry: () {
                setState(() => loading = true);
                loadHistory();
              },
            )
          : RefreshIndicator(
              color: fsdPink,
              onRefresh: loadHistory,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _HistorySearchBar(
                    currentValue: searchQuery,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (projects.isEmpty)
                    const _EmptyHistoryState()
                  else if (items.isEmpty)
                    const _NoHistoryResultsState()
                  else
                    Column(
                      children: items.map((project) {
                        final status = (project['status'] ?? '').toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _HistoryCard(
                            project: project,
                            statusLabel: _formatStatusLabel(status),
                            statusTextColor: _statusTextColor(status),
                            statusBgColor: _statusBgColor(status),
                            versionLabel: _formatVersion(project),
                            updatedAtLabel: _formatDate(project['updated_at']),
                            progressValue: _parseProgress(project['progress']),
                            onOpenEditor: () =>
                                _openEditor(project['id'] as int),
                            onOpenPreview: () =>
                                _openPreview(project['id'] as int),
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

class _HistorySearchBar extends StatelessWidget {
  final String currentValue;
  final ValueChanged<String> onChanged;

  const _HistorySearchBar({
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: TextField(
        onChanged: onChanged,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: const InputDecoration(
          hintText: 'Buscar por proyecto, código, versión o workspace...',
          hintStyle: TextStyle(color: fsdTextGrey),
          prefixIcon: Icon(Icons.search_rounded, color: fsdTextGrey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final dynamic project;
  final String statusLabel;
  final Color statusTextColor;
  final Color statusBgColor;
  final String versionLabel;
  final String updatedAtLabel;
  final int progressValue;
  final VoidCallback onOpenEditor;
  final VoidCallback onOpenPreview;

  const _HistoryCard({
    required this.project,
    required this.statusLabel,
    required this.statusTextColor,
    required this.statusBgColor,
    required this.versionLabel,
    required this.updatedAtLabel,
    required this.progressValue,
    required this.onOpenEditor,
    required this.onOpenPreview,
  });

  @override
  Widget build(BuildContext context) {
    final name = project['name']?.toString().trim().isNotEmpty == true
        ? project['name'].toString()
        : 'Proyecto sin nombre';

    final code = project['code']?.toString().trim().isNotEmpty == true
        ? project['code'].toString()
        : 'Sin código';

    final workspaceName =
        project['workspace_name']?.toString().trim().isNotEmpty == true
        ? project['workspace_name'].toString()
        : 'Sin workspace';

    final description =
        project['description']?.toString().trim().isNotEmpty == true
        ? project['description'].toString()
        : 'Sin descripción';

    return Container(
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
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0x22E8365D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: fsdPink,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
            const SizedBox(height: 12),
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
                _HistoryChip(
                  icon: Icons.tag_rounded,
                  label: code,
                  color: fsdPink,
                ),
                _HistoryChip(icon: Icons.layers_outlined, label: workspaceName),
                _HistoryChip(icon: Icons.article_outlined, label: versionLabel),
                _HistoryChip(icon: Icons.update_rounded, label: updatedAtLabel),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Progreso actual',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progressValue / 100,
                minHeight: 9,
                backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(fsdPink),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$progressValue%',
              style: const TextStyle(
                color: fsdTextGrey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenEditor,
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text('Abrir editor'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    label: const Text('Ver cambios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fsdPink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _HistoryChip({required this.icon, required this.label, this.color});

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
            constraints: const BoxConstraints(maxWidth: 165),
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

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

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
          const Icon(Icons.history_rounded, color: fsdPink, size: 44),
          const SizedBox(height: 14),
          Text(
            'No hay historial todavía',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Cuando tus proyectos tengan actividad, aquí aparecerán sus cambios más recientes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NoHistoryResultsState extends StatelessWidget {
  const _NoHistoryResultsState();

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
            'No hay resultados en el historial',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Prueba buscando con otro nombre, código, versión o workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HistoryErrorState({required this.message, required this.onRetry});

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
            'No pudimos cargar el historial',
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
