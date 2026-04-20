import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class ReviewsScreen extends StatefulWidget {
  final bool embedded;
  const ReviewsScreen({super.key, this.embedded = false});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool loading = true;
  String? errorMessage;

  // Projects owned by current user that have pending revisions to approve.
  List<dynamic> _ownedPending = [];
  // Projects NOT owned by current user where current user submitted a revision.
  List<dynamic> _sentByMe = [];

  String filter = 'Pendientes';
  final filters = ['Pendientes', 'Enviadas', 'Todos'];

  @override
  void initState() {
    super.initState();
    loadReviews();
  }

  // version label cache: projectId → latest version map
  final Map<int, Map<String, dynamic>> _latestVersionByProject = {};

  Future<void> loadReviews() async {
    try {
      final ownProjects = await ApiService.getProjects();
      final workspaces  = await ApiService.getWorkspaces();

      final Map<int, dynamic> byId = {};
      for (final p in ownProjects) {
        final id = p['id'];
        if (id != null) byId[id as int] = p;
      }
      for (final ws in workspaces) {
        final wsId = ws['id'];
        if (wsId == null) continue;
        try {
          final wsProjects = await ApiService.getProjectsByWorkspace(wsId as int);
          for (final p in wsProjects) {
            final id = p['id'];
            if (id != null) byId[id as int] = p;
          }
        } catch (_) {}
      }

      final currentEmail = (AuthService.userEmail ?? '').trim().toLowerCase();
      final currentId   = AuthService.userId;

      bool isOwnerOf(dynamic p) {
        final ownerField = p['owner'];
        if (ownerField is Map) {
          final email = (ownerField['email'] ?? '').toString().trim().toLowerCase();
          if (email.isNotEmpty && email == currentEmail) return true;
          final id = ownerField['id'];
          if (currentId != null && id != null) {
            return id.toString() == currentId.toString();
          }
          return false;
        }
        // Integer owner ID (compact list response)
        if (ownerField is int && currentId != null) return ownerField == currentId;
        // String fallback (email or stringified ID)
        final s = ownerField?.toString().trim().toLowerCase() ?? '';
        if (s.isEmpty) return false;
        if (s == currentEmail) return true;
        if (currentId != null && s == currentId.toString()) return true;
        return false;
      }

      final owned    = byId.values.where((p) =>  isOwnerOf(p)).toList();
      final nonOwned = byId.values.where((p) => !isOwnerOf(p)).toList();

      // Owned projects: pending = API status is 'in_review'.
      // Also cache the latest version for the approve flow (to get srs_data).
      await Future.wait(owned.map((p) async {
        final id = p['id'] as int?;
        if (id == null) return;
        final apiStatus = (p['status'] ?? '').toString();
        if (apiStatus == 'in_review') {
          // Keep status as 'review' locally so filteredProjects works.
          p['status'] = 'review';
        }
        try {
          final versions = await ApiService.getProjectVersions(id);
          if (versions.isNotEmpty) {
            _latestVersionByProject[id] =
                Map<String, dynamic>.from(versions.first as Map);
          }
        } catch (_) {}
      }));

      // Non-owned: visible to sender when project status is 'in_review'
      // AND the most recent version was created by the current user.
      final List<dynamic> sentList = [];
      await Future.wait(nonOwned.map((p) async {
        final id = p['id'] as int?;
        if (id == null) return;
        final apiStatus = (p['status'] ?? '').toString();
        if (apiStatus != 'in_review') return;
        try {
          final versions = await ApiService.getProjectVersions(id);
          if (versions.isEmpty) return;
          final latest = Map<String, dynamic>.from(versions.first as Map);
          final createdBy = latest['created_by'];
          final creator = (createdBy is Map
              ? (createdBy['email'] ?? '')
              : (latest['created_by_email'] ?? ''))
              .toString().trim().toLowerCase();
          if (creator == currentEmail) {
            final copy = Map<String, dynamic>.from(p as Map);
            copy['_sentVersion'] = latest;
            copy['status'] = 'review';
            _latestVersionByProject[id] = latest;
            sentList.add(copy);
          }
        } catch (_) {}
      }));

      if (!mounted) return;
      setState(() {
        _ownedPending = owned;
        _sentByMe = sentList;
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

  List<dynamic> get filteredProjects {
    switch (filter) {
      case 'Pendientes':
        return _ownedPending.where((p) =>
          (p['status'] ?? '').toString().toLowerCase() == 'review').toList();
      case 'Enviadas':
        return _sentByMe;
      case 'Todos':
        final all = <dynamic>[..._ownedPending, ..._sentByMe];
        final seen = <int>{};
        return all.where((p) {
          final id = p['id'] as int?;
          if (id == null || seen.contains(id)) return false;
          seen.add(id);
          return true;
        }).toList();
      default:
        return _ownedPending;
    }
  }

  Future<void> _openPreview(int id) async {
    await context.push('/preview/$id');

    if (!mounted) return;

    setState(() => loading = true);
    await loadReviews();
  }

  Future<void> _approveReview(dynamic project) async {
    final id = project['id'] as int;
    final name = (project['name'] ?? 'este proyecto').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fsdCardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Aprobar cambios',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          '¿Aceptar los cambios enviados a revisión en "$name"? El proyecto quedará como Aprobado.',
          style: const TextStyle(color: fsdTextGrey, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: fsdTextGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1BC47D),
                foregroundColor: Colors.white),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // Non-owner already pushed their changes to the live SRS when submitting.
      // Approving just marks the project as approved and stamps a version.
      await ApiService.partialUpdateProject(id, {'status': 'approved'});

      final versions = await ApiService.getProjectVersions(id);
      await ApiService.createProjectVersion(id, {
        'version_number': (versions.length + 1).toString(),
        'version_name': 'Aprobada - v${versions.length + 1}',
        'change_description': 'Revisión aprobada por el propietario',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios aprobados y aplicados al SRS'),
          backgroundColor: Color(0xFF1BC47D),
        ),
      );
      setState(() => loading = true);
      await loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aprobar: $e'), backgroundColor: fsdPink),
      );
    }
  }

  Future<void> _rejectReview(dynamic project) async {
    final id = project['id'] as int;
    final name = (project['name'] ?? 'este proyecto').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: fsdCardBg,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Rechazar cambios',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: Text(
          '¿Rechazar los cambios en "$name"? Los cambios propuestos no se aplicarán al SRS.',
          style: const TextStyle(color: fsdTextGrey, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: fsdTextGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: fsdPink, foregroundColor: Colors.white),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // Non-owner pushed their changes to live SRS when submitting.
      // Restore the version prior to the submission to revert those changes.
      final versions = await ApiService.getProjectVersions(id);
      // versions is ordered newest-first; [0] = pending, [1] = previous owner state
      if (versions.length >= 2) {
        final prevVersionId = (versions[1] as Map)['id'] as int?;
        if (prevVersionId != null) {
          await ApiService.restoreProjectVersion(id, prevVersionId);
        }
      }

      // Set status back to draft.
      await ApiService.partialUpdateProject(id, {'status': 'draft'});

      // Create a neutral version marking the rejection.
      final updatedVersions = await ApiService.getProjectVersions(id);
      await ApiService.createProjectVersion(id, {
        'version_number': (updatedVersions.length + 1).toString(),
        'version_name': 'Rechazada - v${updatedVersions.length + 1}',
        'change_description': 'Revisión rechazada por el propietario',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisión rechazada. El SRS no fue modificado.'),
          backgroundColor: fsdPink,
        ),
      );
      setState(() => loading = true);
      await loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar: $e'), backgroundColor: fsdPink),
      );
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'review':      return 'En revisión';
      case 'in_progress': return 'En progreso';
      case 'approved':    return 'Aprobado';
      case 'completed':   return 'Completado';
      case 'draft':       return 'Borrador';
      default:            return status.isEmpty ? 'Sin estado' : status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'review':      return Colors.orange;
      case 'in_progress': return const Color(0xFFFFC857);
      case 'approved':    return const Color(0xFF1BC47D);
      case 'completed':   return const Color(0xFF1BC47D);
      default:            return const Color(0xFF55A6FF);
    }
  }

  Widget _buildContent(BuildContext context) {
    final data = filteredProjects;
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: CircularProgressIndicator(color: fsdPink),
        ),
      );
    }
    if (errorMessage != null) {
      return Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.white)));
    }
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          children: filters.map((f) {
            final selected = f == filter;
            final surface = Theme.of(context).colorScheme.surface;
            final onSurface = Theme.of(context).colorScheme.onSurface;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => filter = f),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? fsdPink.withValues(alpha: 0.2) : surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? fsdPink : fsdBorderColor),
                  ),
                  child: Center(
                    child: Text(
                      f,
                      style: TextStyle(
                        color: selected ? fsdPink : onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (data.isEmpty)
          const _EmptyReviews()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.length,
            itemBuilder: (context, i) {
              final p = data[i];
              final status = (p['status'] ?? '').toString();
              final pid = p['id'] as int;
              final isSentByMe = p['_sentVersion'] != null;
              return _ReviewCard(
                project: p,
                status: isSentByMe ? 'En espera' : _statusLabel(status),
                color: isSentByMe ? Colors.orange : _statusColor(status),
                latestVersion: _latestVersionByProject[pid],
                onPreview: () => _openPreview(pid),
                onApprove: (!isSentByMe && status == 'review') ? () => _approveReview(p) : null,
                onReject: (!isSentByMe && status == 'review') ? () => _rejectReview(p) : null,
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildContent(context);
    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.reviews,
      eyebrow: 'Revisiones',
      titleWhite: 'Gestión de ',
      titlePink: 'revisiones',
      description: 'Aprueba, revisa y valida documentos SRS.',
      child: _buildContent(context),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final dynamic project;
  final String status;
  final Color color;
  final Map<String, dynamic>? latestVersion;
  final VoidCallback onPreview;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ReviewCard({
    required this.project,
    required this.status,
    required this.color,
    required this.onPreview,
    this.latestVersion,
    this.onApprove,
    this.onReject,
  });

  String _formatDate(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return '';
    try {
      final date = DateTime.parse(value).toLocal();
      final d = date.day.toString().padLeft(2, '0');
      final m = date.month.toString().padLeft(2, '0');
      final y = date.year.toString();
      final h = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '$d/$m/$y $h:$min';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final versionLabel = latestVersion != null
        ? (latestVersion!['version_name'] ?? latestVersion!['label'] ?? '').toString()
        : '';
    final versionNumber = latestVersion != null
        ? (latestVersion!['version_number'] ?? '').toString()
        : '';
    String versionAuthor = '';
    if (latestVersion != null) {
      final createdBy = latestVersion!['created_by'];
      versionAuthor = createdBy is Map
          ? (createdBy['email'] ?? createdBy['first_name'] ?? '').toString()
          : (latestVersion!['created_by_email'] ?? '').toString();
    }
    final versionDate = latestVersion != null
        ? _formatDate(latestVersion!['created_at'])
        : '';
    final hasVersion = latestVersion != null && versionLabel.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: fsdCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: onApprove != null ? Colors.orange.withValues(alpha: 0.5) : fsdBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project['name'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      if ((project['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          project['description'].toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: fsdTextGrey, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Version info ─────────────────────────────────────────────
          if (hasVersion) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bookmark_outlined,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (versionNumber.isNotEmpty) ...[
                              Text(
                                'v$versionNumber',
                                style: const TextStyle(
                                  color: fsdPink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                versionLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (versionAuthor.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Por $versionAuthor${versionDate.isNotEmpty ? '  •  $versionDate' : ''}',
                            style: const TextStyle(
                                color: fsdTextGrey, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Actions ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Row(
              children: [
                // Preview
                OutlinedButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Ver'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: fsdBorderColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (onReject != null) ...[
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fsdPink,
                      side: BorderSide(color: fsdPink.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onApprove != null)
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Aceptar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1BC47D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: const [
          Icon(Icons.rate_review, color: fsdPink, size: 40),
          SizedBox(height: 10),
          Text(
            'Sin revisiones pendientes',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Cuando un colaborador envíe cambios,\naparecerán aquí para que los apruebes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: fsdTextGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
