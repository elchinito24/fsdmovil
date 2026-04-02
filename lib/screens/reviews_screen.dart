import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';
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

  List<dynamic> get filteredProjects {
    if (filter == 'Todos') return projects;

    return projects.where((p) {
      final status = (p['status'] ?? '').toString().toLowerCase();
      return status == 'review' || status == 'in_progress';
    }).toList();
  }

  Future<void> _openEditor(int id) async {
    await context.push('/editor/$id');

    if (!mounted) return;

    setState(() => loading = true);
    await loadReviews();
  }

  Future<void> _openPreview(int id) async {
    await context.push('/preview/$id');

    if (!mounted) return;

    setState(() => loading = true);
    await loadReviews();
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'review':
        return 'En revisión';
      case 'in_progress':
        return 'En progreso';
      case 'approved':
        return 'Aprobado';
      default:
        return 'Borrador';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'review':
        return Colors.orange;
      case 'in_progress':
        return Colors.yellow;
      case 'approved':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = filteredProjects;

    return MainAppShell(
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
                        onEdit: () => _openEditor(p['id']),
                        onPreview: () => _openPreview(p['id']),
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
  final VoidCallback onEdit;
  final VoidCallback onPreview;

  const _ReviewCard({
    required this.project,
    required this.status,
    required this.color,
    required this.onEdit,
    required this.onPreview,
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
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.visibility, color: Colors.white),
                onPressed: onPreview,
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
            'No hay revisiones pendientes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
