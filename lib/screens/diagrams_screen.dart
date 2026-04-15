import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const _diagramTypes = <_DiagramTypeOption>[
  _DiagramTypeOption(value: 'use-case',   label: 'Caso de uso',       icon: Icons.person_outline_rounded),
  _DiagramTypeOption(value: 'sequence',   label: 'Secuencia',          icon: Icons.swap_horizontal_circle_outlined),
  _DiagramTypeOption(value: 'class',      label: 'Clase',              icon: Icons.account_tree_outlined),
  _DiagramTypeOption(value: 'activity',   label: 'Actividad',          icon: Icons.route_outlined),
  _DiagramTypeOption(value: 'er',         label: 'Diagrama ER',        icon: Icons.table_chart_outlined),
  _DiagramTypeOption(value: 'flowchart',  label: 'Flujo',              icon: Icons.air_outlined),
  _DiagramTypeOption(value: 'state',      label: 'Estado',             icon: Icons.bubble_chart_outlined),
  _DiagramTypeOption(value: 'mr',         label: 'Modelo Relacional',  icon: Icons.storage_outlined),
];

class _DiagramTypeOption {
  final String value;
  final String label;
  final IconData icon;
  const _DiagramTypeOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class DiagramsScreen extends StatefulWidget {
  const DiagramsScreen({super.key});

  @override
  State<DiagramsScreen> createState() => _DiagramsScreenState();
}

class _DiagramsScreenState extends State<DiagramsScreen> {
  bool loading = true;
  String? errorMessage;
  List<dynamic> diagrams = [];
  String? filterType; // null = Todos

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getDiagrams();
      if (!mounted) return;
      setState(() {
        diagrams = data;
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

  List<dynamic> get _filtered {
    if (filterType == null) return diagrams;
    return diagrams
        .where((d) =>
            (d['diagram_type'] ?? d['type'] ?? '').toString() == filterType)
        .toList();
  }

  void _showCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateDiagramDialog(),
    );
    if (created == true) {
      setState(() => loading = true);
      await _load();
    }
  }

  void _openDetail(dynamic diagram) async {
    final id = diagram['id'];
    if (id == null) return;
    await context.push('/diagrams/$id');
    if (!mounted) return;
    setState(() => loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filtered;

    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.diagrams,
      eyebrow: 'Diagramas',
      titleWhite: 'Diagramas ',
      titlePink: 'del proyecto',
      description:
          'Visualizaciones técnicas y arquitecturales del sistema para documentación de software moderna.',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: fsdPink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nuevo diagrama',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: fsdPink)),
            )
          : errorMessage != null
              ? _ErrorState(
                  message: errorMessage!,
                  onRetry: () {
                    setState(() => loading = true);
                    _load();
                  },
                )
              : RefreshIndicator(
                  color: fsdPink,
                  onRefresh: _load,
                  child: ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      _FilterChips(
                        selected: filterType,
                        onSelected: (v) => setState(() => filterType = v),
                      ),
                      const SizedBox(height: 16),
                      if (diagrams.isEmpty)
                        const _EmptyState()
                      else if (visible.isEmpty)
                        const _NoResultsState()
                      else
                        Column(
                          children: visible.map((d) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DiagramCard(
                                diagram: d,
                                onTap: () => _openDetail(d),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}

// ─── Filter chips ────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    final chips = <Widget>[
      _Chip(
        label: 'Todos',
        active: selected == null,
        onTap: () => onSelected(null),
        borderColor: borderColor,
      ),
      ..._diagramTypes.map((t) => _Chip(
            label: t.label,
            active: selected == t.value,
            onTap: () => onSelected(selected == t.value ? null : t.value),
            borderColor: borderColor,
          )),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color borderColor;

  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? fsdPink : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? fsdPink : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : fsdTextGrey,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Diagram card ────────────────────────────────────────────────────────────

class _DiagramCard extends StatelessWidget {
  final dynamic diagram;
  final VoidCallback onTap;

  const _DiagramCard({required this.diagram, required this.onTap});

  String _typeLabel(String type) {
    final match = _diagramTypes.where((t) => t.value == type).toList();
    if (match.isNotEmpty) return match.first.label.toUpperCase();
    if (type.isEmpty) return 'DIAGRAMA';
    return type.toUpperCase().replaceAll('_', ' ');
  }

  IconData _typeIcon(String type) {
    final match = _diagramTypes.where((t) => t.value == type).toList();
    if (match.isNotEmpty) return match.first.icon;
    return Icons.schema_outlined;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw).toLocal();
      const months = [
        'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
        'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
      ];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return raw;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'BORRADOR';
      case 'published':
        return 'PUBLICADO';
      case 'archived':
        return 'ARCHIVADO';
      default:
        return status.isEmpty ? 'BORRADOR' : status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return const Color(0xFF1BC47D);
      case 'archived':
        return const Color(0xFF8E8E93);
      default:
        return const Color(0xFF55A6FF);
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return const Color(0x221BC47D);
      case 'archived':
        return const Color(0x228E8E93);
      default:
        return const Color(0x2255A6FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardBg = cs.surface;
    final borderColor = cs.outlineVariant;
    final titleColor = cs.onSurface;

    final rawType = (diagram['diagram_type'] ?? diagram['type'] ?? '').toString();
    final name = (diagram['name'] ?? 'Sin título').toString();
    final projectName = _projectName(diagram);
    final status = (diagram['status'] ?? '').toString();
    final date = _formatDate(diagram['updated_at'] ?? diagram['created_at']);
    final creatorRaw = diagram['created_by'] ?? diagram['owner'] ?? diagram['creator'];
    final creatorEmail = _extractEmail(creatorRaw);
    final creatorInitial = creatorEmail.isNotEmpty
        ? creatorEmail[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: fsdPink.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_typeIcon(rawType), color: fsdPink, size: 18),
                  ),
                  const Spacer(),
                  if (date.isNotEmpty)
                    Text(
                      date,
                      style: const TextStyle(
                        color: fsdTextGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            // Type label + name + project
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(rawType),
                    style: const TextStyle(
                      color: fsdTextGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (projectName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      projectName,
                      style: const TextStyle(
                        color: fsdTextGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Preview placeholder
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              height: 80,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Icon(
                  _typeIcon(rawType),
                  color: fsdTextGrey.withOpacity(0.4),
                  size: 32,
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: fsdPink,
                    child: Text(
                      creatorInitial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      creatorEmail,
                      style: const TextStyle(
                        color: fsdTextGrey,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBg(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
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

  String _projectName(dynamic d) {
    final p = d['project'];
    if (p == null) return '';
    if (p is Map) {
      return (p['name'] ?? p['code'] ?? '').toString();
    }
    final ws = d['workspace_name'] ?? d['project_name'] ?? '';
    return ws.toString();
  }

  String _extractEmail(dynamic creator) {
    if (creator == null) return '';
    if (creator is Map) {
      return (creator['email'] ?? creator['username'] ?? '').toString();
    }
    return creator.toString();
  }
}

// ─── Create dialog ───────────────────────────────────────────────────────────

class _CreateDiagramDialog extends StatefulWidget {
  @override
  State<_CreateDiagramDialog> createState() => _CreateDiagramDialogState();
}

class _CreateDiagramDialogState extends State<_CreateDiagramDialog> {
  final _nameController = TextEditingController();
  int? _selectedProjectId;
  String? _selectedProjectName;
  String? _selectedType;
  bool _loading = false;
  bool _loadingProjects = true;
  List<dynamic> _projects = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final data = await ApiService.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = data;
        _loadingProjects = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProjects = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es requerido.');
      return;
    }
    if (_selectedProjectId == null) {
      setState(() => _error = 'Selecciona un proyecto.');
      return;
    }
    if (_selectedType == null) {
      setState(() => _error = 'Selecciona el tipo de diagrama.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiService.createDiagram({
        'name': name,
        'project_id': _selectedProjectId,
        'diagram_type': _selectedType,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surface;
    final border = cs.outlineVariant;
    final labelColor = fsdTextGrey;
    final textColor = cs.onSurface;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Nuevo diagrama',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: Icon(Icons.close_rounded, color: labelColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _FieldLabel(label: 'NOMBRE DEL DIAGRAMA', color: labelColor),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Ej: Flujo de autenticación',
                  hintStyle: TextStyle(color: labelColor),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: fsdPink),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel(label: 'PROYECTO', color: labelColor),
              const SizedBox(height: 6),
              _loadingProjects
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          color: fsdPink,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : _DropdownField(
                      value: _selectedProjectName,
                      hint: 'Selecciona un proyecto...',
                      items: _projects
                          .map((p) => p['name'].toString())
                          .toList(),
                      border: border,
                      labelColor: labelColor,
                      textColor: textColor,
                      onChanged: (val) {
                        final project = _projects.firstWhere(
                          (p) => p['name'].toString() == val,
                          orElse: () => null,
                        );
                        setState(() {
                          _selectedProjectName = val;
                          _selectedProjectId = project?['id'];
                        });
                      },
                    ),
              const SizedBox(height: 14),
              _FieldLabel(label: 'TIPO DE DIAGRAMA', color: labelColor),
              const SizedBox(height: 6),
              _DropdownField(
                value: _selectedType == null
                    ? null
                    : _diagramTypes
                        .where((t) => t.value == _selectedType)
                        .map((t) => t.label)
                        .firstOrNull,
                hint: 'Selecciona el tipo...',
                items: _diagramTypes.map((t) => t.label).toList(),
                border: border,
                labelColor: labelColor,
                textColor: textColor,
                onChanged: (val) {
                  final match =
                      _diagramTypes.where((t) => t.label == val).toList();
                  setState(() {
                    _selectedType = match.isNotEmpty ? match.first.value : val;
                  });
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: fsdPink,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: labelColor),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: fsdPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Crear diagrama',
                            style: TextStyle(fontWeight: FontWeight.w700),
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

class _FieldLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _FieldLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final Color border;
  final Color labelColor;
  final Color textColor;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.items,
    required this.border,
    required this.labelColor,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(hint, style: TextStyle(color: labelColor, fontSize: 14)),
        underline: const SizedBox(),
        isExpanded: true,
        dropdownColor: cs.surface,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: labelColor),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Empty / error states ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.schema_outlined,
              size: 56,
              color: fsdTextGrey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin diagramas',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea tu primer diagrama\npulsando el botón inferior.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fsdTextGrey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.filter_list_off_rounded,
              size: 48,
              color: fsdTextGrey.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Sin resultados',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No hay diagramas para\neste tipo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: fsdTextGrey, height: 1.5),
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
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: fsdPink,
            ),
            const SizedBox(height: 14),
            Text(
              'Error al cargar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: fsdTextGrey,
                fontSize: 13,
              ),
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
