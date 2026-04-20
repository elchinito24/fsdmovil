import 'package:flutter/material.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/auth_service.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);
const _green = Color(0xFF1BC47D);

class VersionHistoryScreen extends StatefulWidget {
  final int projectId;

  const VersionHistoryScreen({super.key, required this.projectId});

  @override
  State<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends State<VersionHistoryScreen> {
  List<dynamic> versions = [];
  dynamic project;
  bool loading = true;
  String? errorMessage;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final projectData = await ApiService.getProject(widget.projectId);

      List<dynamic> versionList = [];
      try {
        versionList = await ApiService.getProjectVersions(widget.projectId);
      } catch (_) {}

      final normalized = <Map<String, dynamic>>[];
      for (final v in versionList) {
        if (v is Map) normalized.add(Map<String, dynamic>.from(v));
      }

      // Determine ownership
      final ownerField = projectData['owner'];
      final currentEmail = (AuthService.userEmail ?? '').trim().toLowerCase();
      final currentId = AuthService.userId;
      bool isOwner = false;
      if (ownerField is Map) {
        final email = (ownerField['email'] ?? '').toString().trim().toLowerCase();
        final id = ownerField['id'];
        isOwner = (email.isNotEmpty && email == currentEmail) ||
            (currentId != null && id != null && id.toString() == currentId.toString());
      } else if (ownerField is int && currentId != null) {
        isOwner = ownerField == currentId;
      } else {
        final s = ownerField?.toString().trim().toLowerCase() ?? '';
        isOwner = s.isNotEmpty && s == currentEmail;
      }

      if (!mounted) return;
      setState(() {
        project = projectData;
        versions = normalized;
        _isOwner = isOwner;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _projectDisplayName() {
    if (project == null) return '';
    if (project is Map) {
      final p = project as Map;
      final name = (p['name'] ?? p['title'] ?? p['code'])?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return project.toString();
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

  String _authorName(dynamic raw) {
    if (raw == null) return 'Usuario';
    if (raw is Map) {
      final first = (raw['first_name'] ?? '').toString().trim();
      final last = (raw['last_name'] ?? '').toString().trim();
      final full = '$first $last'.trim();
      if (full.isNotEmpty) return full;
      return (raw['email'] ?? 'Usuario').toString();
    }
    return raw.toString();
  }

  Future<void> _applyVersion(Map<String, dynamic> version) async {
    final vId = version['id'] as int?;
    final vName = (version['version_name'] ?? version['label'] ?? 'esta versión').toString();
    if (vId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Aplicar versión al SRS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          '¿Deseas restaurar "$vName" como el contenido actual del SRS? Esta acción reemplazará los cambios actuales.',
          style: const TextStyle(color: _textGrey, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Fetch the full version detail to get srs_data_snapshot
      final detail = await ApiService.getProjectVersion(widget.projectId, vId);
      final snapshot = detail['srs_data_snapshot'];

      if (snapshot != null) {
        await ApiService.updateProjectSrs(widget.projectId, {'srs_data': snapshot});
      } else {
        // Fallback: use the API restore endpoint
        await ApiService.restoreProjectVersion(widget.projectId, vId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Versión aplicada al SRS correctamente'),
          backgroundColor: _green,
        ),
      );
      setState(() => loading = true);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al aplicar versión: $e'),
          backgroundColor: _pink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projName = _projectDisplayName();

    return MainAppShell(
      insideShell: true,
      selectedItem: null,
      eyebrow: projName,
      titleWhite: 'Historial ',
      titlePink: 'de versiones',
      description: 'Versiones guardadas del documento SRS.',
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: CircularProgressIndicator(color: _pink),
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : versions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.bookmark_border_rounded,
                                color: _textGrey, size: 44),
                            SizedBox(height: 12),
                            Text(
                              'Sin versiones guardadas',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Crea una nueva versión desde el editor\npara verla aquí.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _textGrey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: _pink,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: versions.length,
                        itemBuilder: (context, index) {
                          final item = versions[index];
                          final vName = (item['version_name'] ?? item['label'] ?? 'Sin nombre').toString();
                          final changeDesc = (item['change_description'] ?? '').toString().trim();
                          final authorRaw = item['created_by'];
                          final author = _authorName(authorRaw);
                          final date = _formatDate(item['created_at']);
                          final isPending = vName.toLowerCase().contains('revision') ||
                              vName.toLowerCase().contains('revisión') ||
                              vName.toLowerCase().contains('pendiente');
                          final isRestored = (item['restored_from_version'] != null);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _VersionCard(
                              displayNumber: versions.length - index,
                              isNewest: index == 0,
                              versionName: vName,
                              changeDescription: changeDesc,
                              author: author,
                              date: date,
                              isPending: isPending,
                              isRestored: isRestored,
                              isOwner: _isOwner,
                              onApply: _isOwner
                                  ? () => _applyVersion(Map<String, dynamic>.from(item))
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final int displayNumber;
  final bool isNewest;
  final String versionName;
  final String changeDescription;
  final String author;
  final String date;
  final bool isPending;
  final bool isRestored;
  final bool isOwner;
  final VoidCallback? onApply;

  const _VersionCard({
    required this.displayNumber,
    required this.isNewest,
    required this.versionName,
    required this.changeDescription,
    required this.author,
    required this.date,
    required this.isPending,
    required this.isRestored,
    required this.isOwner,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final String badgeText;
    final IconData badgeIcon;

    if (isPending) {
      badgeColor = Colors.orange;
      badgeText = 'En revisión';
      badgeIcon = Icons.pending_outlined;
    } else if (isRestored) {
      badgeColor = const Color(0xFF55A6FF);
      badgeText = 'Restaurada';
      badgeIcon = Icons.restore_rounded;
    } else {
      badgeColor = _green;
      badgeText = 'Guardada';
      badgeIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPending ? Colors.orange.withValues(alpha: 0.4) : _borderColor,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v$displayNumber',
                style: const TextStyle(
                  color: _pink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              if (isNewest)
                _Badge(text: 'Actual', color: _green),
              const Spacer(),
              _Badge(text: badgeText, color: badgeColor, icon: badgeIcon),
            ],
          ),
          const SizedBox(height: 10),

          // ── Version name ─────────────────────────────────────────────
          Text(
            versionName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          // ── Change description ────────────────────────────────────────
          if (changeDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 15, color: _textGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      changeDescription,
                      style: const TextStyle(
                        color: _textGrey,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ── Author & date ─────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: _textGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  author,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textGrey, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.access_time_rounded, size: 14, color: _textGrey),
              const SizedBox(width: 4),
              Text(date, style: const TextStyle(color: _textGrey, fontSize: 13)),
            ],
          ),

          // ── Apply button (owner only) ─────────────────────────────────
          if (onApply != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('Aplicar al SRS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const _Badge({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
