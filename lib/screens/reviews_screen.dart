import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool loading = true;
  String? errorMessage;
  List<dynamic> projects = [];

  String filter = 'Pendientes';

  final filters = ['Pendientes', 'Todos'];

  @override
  void initState() {
    super.initState();
    loadReviews();
  }

  Future<void> loadReviews() async {
    try {
      // Fetch all accessible projects then keep only the ones this user owns.
      // Non-owners submit for review — they never appear in this queue.
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
          final wsProjects =
              await ApiService.getProjectsByWorkspace(wsId as int);
          for (final p in wsProjects) {
            final id = p['id'];
            if (id != null) byId[id as int] = p;
          }
        } catch (_) {}
      }

      // Only keep projects where the current user is the owner.
      final currentEmail =
          (AuthService.userEmail ?? '').trim().toLowerCase();
      final owned = byId.values.where((p) {
        final ownerField = p['owner'];
        final ownerEmail = (ownerField is Map
                ? ownerField['email']
                : ownerField)
            ?.toString()
            .trim()
            .toLowerCase() ??
            '';
        return ownerEmail.isNotEmpty && ownerEmail == currentEmail;
      }).toList();

      if (!mounted) return;

      setState(() {
        projects = owned;
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
    if (filter == 'Todos') return projects;

    // 'Pendientes' = projects actually awaiting approval.
    return projects.where((p) {
      final status = (p['status'] ?? '').toString().toLowerCase();
      return status == 'review';
    }).toList();
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
      await ApiService.partialUpdateProject(id, {'status': 'approved'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios aprobados'),
          backgroundColor: Color(0xFF1BC47D),
        ),
      );
      setState(() => loading = true);
      await loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: fsdPink),
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
          '¿Rechazar los cambios en "$name"? Se restaurará la versión anterior al envío.',
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
      // Find the version saved just before review was submitted.
      final versions = await ApiService.getProjectVersions(id);
      // Versions are ordered newest-first; the one labelled 'Revisión pendiente'
      // contains the submitted srs_data. We want the one *before* it to restore.
      // Strategy: take the second entry if it exists; otherwise just revert status.
      if (versions.length >= 2) {
        // Index 0 = the submitted review snapshot, index 1 = previous state.
        final prevVersion =
            Map<String, dynamic>.from(versions[1] as Map);
        final prevSrsData =
            prevVersion['srs_data'] as Map<String, dynamic>?;
        if (prevSrsData != null) {
          await ApiService.updateProjectSrs(id, {'srs_data': prevSrsData});
        }
      }
      // Set status back to in_progress (was being edited).
      await ApiService.partialUpdateProject(
          id, {'status': 'in_progress'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cambios rechazados. Versión anterior restaurada.'),
          backgroundColor: fsdPink,
        ),
      );
      setState(() => loading = true);
      await loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: fsdPink),
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

  @override
  Widget build(BuildContext context) {
    final data = filteredProjects;

    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.reviews,
      eyebrow: 'Revisiones',
      titleWhite: 'Gestión de ',
      titlePink: 'revisiones',
      description: 'Aprueba, revisa y valida documentos SRS.',
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: CircularProgressIndicator(color: fsdPink),
              ),
            )
          : errorMessage != null
          ? Center(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 10),

                // filtro
                Row(
                  children: filters.map((f) {
                    final selected = f == filter;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            filter = f;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? fsdPink.withOpacity(0.2)
                                : fsdCardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? fsdPink : fsdBorderColor,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              f,
                              style: TextStyle(
                                color: Colors.white,
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

                      return _ReviewCard(
                        project: p,
                        status: _statusLabel(status),
                        color: _statusColor(status),
                        onPreview: () => _openPreview(p['id']),
                        onApprove: status == 'review'
                            ? () => _approveReview(p)
                            : null,
                        onReject: status == 'review'
                            ? () => _rejectReview(p)
                            : null,
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final dynamic project;
  final String status;
  final Color color;
  final VoidCallback onPreview;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ReviewCard({
    required this.project,
    required this.status,
    required this.color,
    required this.onPreview,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fsdCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fsdBorderColor),
      ),
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
          const SizedBox(height: 8),
          Text(
            project['description'] ?? '',
            style: const TextStyle(color: fsdTextGrey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.visibility, color: Colors.white),
                onPressed: onPreview,
                tooltip: 'Vista previa',
              ),
              if (onApprove != null)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF1BC47D)),
                  onPressed: onApprove,
                  tooltip: 'Aprobar',
                ),
              if (onReject != null)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: fsdPink),
                  onPressed: onReject,
                  tooltip: 'Rechazar',
                ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: fsdCardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.rate_review, color: fsdPink, size: 40),
          SizedBox(height: 10),
          Text(
            'Sin revisiones pendientes',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
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
