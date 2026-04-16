import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

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
  bool _usingHistory = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final projectData = await ApiService.getProject(widget.projectId);

      // Fetch version snapshots for this project and keep only meaningful
      // entries (belonging to this project and with actual srs_data changes).
      List<dynamic> versionList = [];
      try {
        versionList = await ApiService.getProjectVersions(widget.projectId);
      } catch (_) {}

      // Normalize to Map and filter out items that clearly belong to other projects.
      final normalized = <Map<String, dynamic>>[];
      for (final v in versionList) {
        if (v is Map) normalized.add(Map<String, dynamic>.from(v));
      }

      final filteredByProject = normalized.where((v) {
        final pid = v['project'] ?? v['project_id'] ?? v['projectId'];
        if (pid == null) return true;
        return pid.toString() == widget.projectId.toString();
      }).toList();

      // Remove consecutive versions that have identical srs_data (keep only
      // versions that introduce a change). Assumes versions are ordered
      // newest-first by the API.
      final deduped = <Map<String, dynamic>>[];
      for (var i = 0; i < filteredByProject.length; i++) {
        final current = filteredByProject[i];
        final next = i + 1 < filteredByProject.length ? filteredByProject[i + 1] : null;
        final currentSrs = current['srs_data'];
        final nextSrs = next?['srs_data'];
        final cs = currentSrs == null ? '' : jsonEncode(currentSrs);
        final ns = nextSrs == null ? '' : jsonEncode(nextSrs);
        if (cs != ns) deduped.add(current);
      }

      final displayVersions = deduped.cast<dynamic>().toList();

      if (!mounted) return;

      setState(() {
        project = projectData;
        versions = displayVersions;
        _usingHistory = false;
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
      final name = (p['name'] ?? p['title'] ?? p['project_name'] ?? p['display_name'] ?? p['code'])?.toString();
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

  /// Extracts a display name from a UserDetail object or plain string.
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

  String get _ownerEmail {
    final ownerField = project?['owner'];
    if (ownerField is Map) return (ownerField['email'] ?? '').toString().trim().toLowerCase();
    return (ownerField ?? '').toString().trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final projName = _projectDisplayName();
    final descBase = _usingHistory
        ? 'Actividad registrada del proyecto.'
        : 'Snapshots guardados del documento SRS.';
    final description = projName.isNotEmpty ? '$descBase Proyecto: $projName' : descBase;

    return MainAppShell(
      insideShell: true,
      selectedItem: null,
      eyebrow: projName,
      titleWhite: 'Historial ',
      titlePink: 'de versiones',
      description: description,
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
                          fontSize: 16),
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
                  final label =
                      (item['label'] ?? 'Sin nombre').toString();
                  final createdByEmail =
                      (item['created_by_email'] ?? '').toString();
                  final authorRaw = item['created_by'] ?? createdByEmail;
                  final author = authorRaw is Map
                      ? _authorName(authorRaw)
                      : createdByEmail.isNotEmpty
                          ? createdByEmail
                          : 'Usuario';
                  final date = _formatDate(item['created_at']);
                  final isOwnerVersion = createdByEmail.trim().toLowerCase() == _ownerEmail;
                  final isPending = label.toLowerCase().contains('revisión') ||
                      label.toLowerCase().contains('revision') ||
                      label.toLowerCase().contains('pendiente');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _VersionCard(
                      versionNumber: versions.length - index,
                      isNewest: index == 0,
                      label: label,
                      author: author,
                      date: date,
                      isOwnerVersion: isOwnerVersion,
                      isPending: isPending,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final int versionNumber;
  final bool isNewest;
  final String label;
  final String author;
  final String date;
  final bool isOwnerVersion;
  final bool isPending;

  const _VersionCard({
    required this.versionNumber,
    required this.isNewest,
    required this.label,
    required this.author,
    required this.date,
    required this.isOwnerVersion,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    // Determine badge
    final Color badgeColor;
    final String badgeText;
    final IconData badgeIcon;

    if (isPending) {
      badgeColor = Colors.orange;
      badgeText = 'En revisión';
      badgeIcon = Icons.pending_outlined;
    } else if (isOwnerVersion) {
      badgeColor = const Color(0xFF1BC47D);
      badgeText = 'Aprobado';
      badgeIcon = Icons.check_circle_outline_rounded;
    } else {
      badgeColor = const Color(0xFF1BC47D);
      badgeText = 'Aceptado';
      badgeIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v$versionNumber',
                style: const TextStyle(
                  color: _pink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              if (isNewest)
                _Badge(
                  text: 'Actual',
                  color: const Color(0xFF1BC47D),
                ),
              const Spacer(),
              _Badge(
                text: badgeText,
                color: badgeColor,
                icon: badgeIcon,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: _textGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  author,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textGrey, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: _textGrey),
              const SizedBox(width: 4),
              Text(
                date,
                style: const TextStyle(color: _textGrey, fontSize: 13),
              ),
            ],
          ),
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
