import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  bool loading = true;
  String? errorMessage;
  List<dynamic> projects = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
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

  Future<void> _openPreview(int projectId) async {
    await context.push('/preview/$projectId');

    if (!mounted) return;
    setState(() {
      loading = true;
    });
    await loadDocuments();
  }

  List<dynamic> get filteredDocuments {
    final query = searchQuery.trim().toLowerCase();

    return projects.where((project) {
      final name = (project['name'] ?? '').toString().toLowerCase();
      final code = (project['code'] ?? '').toString().toLowerCase();
      final description = (project['description'] ?? '')
          .toString()
          .toLowerCase();
      final workspace = (project['workspace_name'] ?? '')
          .toString()
          .toLowerCase();

      return query.isEmpty ||
          name.contains(query) ||
          code.contains(query) ||
          description.contains(query) ||
          workspace.contains(query);
    }).toList();
  }

  String _formatVersion(dynamic project) {
    final value = project['current_version'] ?? project['version'];
    if (value == null) return 'v1.0';
    return 'v$value';
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
        return const Color(0x33FFC857);
      case 'approved':
        return const Color(0x331BC47D);
      case 'completed':
        return const Color(0x331BC47D);
      default:
        return const Color(0x22FFFFFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleDocuments = filteredDocuments;

    return MainAppShell(
      selectedItem: TopNavItem.documents,
      eyebrow: 'Documentación',
      titleWhite: 'Todos tus ',
      titlePink: 'documentos',
      description:
          'Consulta, busca y abre los documentos SRS de tus proyectos desde una sola vista.',
      child: loading
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: fsdPink)),
            )
          : errorMessage != null
          ? _DocumentsErrorState(
              message: errorMessage!,
              onRetry: () {
                setState(() {
                  loading = true;
                });
                loadDocuments();
              },
            )
          : RefreshIndicator(
              color: fsdPink,
              onRefresh: loadDocuments,
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  _DocumentsSearchBar(
                    currentValue: searchQuery,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (projects.isEmpty)
                    const _EmptyDocumentsState()
                  else if (visibleDocuments.isEmpty)
                    const _NoDocumentsResultsState()
                  else
                    Column(
                      children: visibleDocuments.map((project) {
                        final status = (project['status'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _DocumentCard(
                            project: project,
                            statusLabel: _formatStatusLabel(status),
                            statusTextColor: _statusTextColor(status),
                            statusBgColor: _statusBgColor(status),
                            versionLabel: _formatVersion(project),
                            updatedAtLabel: _formatDate(project['updated_at']),
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

class _DocumentsSearchBar extends StatelessWidget {
  final String currentValue;
  final ValueChanged<String> onChanged;

  const _DocumentsSearchBar({
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
          hintText: 'Buscar documentos...',
          hintStyle: TextStyle(color: fsdTextGrey),
          prefixIcon: Icon(Icons.search_rounded, color: fsdTextGrey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final dynamic project;
  final String statusLabel;
  final Color statusTextColor;
  final Color statusBgColor;
  final String versionLabel;
  final String updatedAtLabel;
  final VoidCallback onOpenPreview;

  const _DocumentCard({
    required this.project,
    required this.statusLabel,
    required this.statusTextColor,
    required this.statusBgColor,
    required this.versionLabel,
    required this.updatedAtLabel,
    required this.onOpenPreview,
  });

  @override
  Widget build(BuildContext context) {
    final name = project['name']?.toString().trim().isNotEmpty == true
        ? project['name'].toString()
        : 'Documento sin nombre';

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
                    Icons.description_outlined,
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
                  icon: Icons.article_outlined,
                  label: versionLabel,
                ),
                _MiniInfoChip(
                  icon: Icons.history_rounded,
                  label: updatedAtLabel,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpenPreview,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Vista previa'),
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

class _EmptyDocumentsState extends StatelessWidget {
  const _EmptyDocumentsState();

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
          const Icon(Icons.description_outlined, color: fsdPink, size: 44),
          const SizedBox(height: 14),
          Text(
            'No hay documentos todavía',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Cuando tengas proyectos creados, aquí aparecerán sus documentos SRS.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NoDocumentsResultsState extends StatelessWidget {
  const _NoDocumentsResultsState();

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
            'No encontramos documentos con esa búsqueda',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Prueba con otro nombre, código, descripción o workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _DocumentsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DocumentsErrorState({required this.message, required this.onRetry});

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
            'No pudimos cargar los documentos',
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
