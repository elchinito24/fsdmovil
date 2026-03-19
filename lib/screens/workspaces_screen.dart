import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/api_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class WorkspacesScreen extends StatefulWidget {
  const WorkspacesScreen({super.key});

  @override
  State<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends State<WorkspacesScreen> {
  bool loading = true;
  String? errorMessage;
  List<dynamic> workspaces = [];

  @override
  void initState() {
    super.initState();
    loadWorkspaces();
  }

  Future<void> loadWorkspaces() async {
    try {
      final data = await ApiService.getWorkspaces();

      setState(() {
        workspaces = data;
        loading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
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
          'Workspaces',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _pink,
        foregroundColor: Colors.white,
        onPressed: () async {
          await context.push('/create-workspace');
          if (mounted) {
            setState(() {
              loading = true;
            });
            loadWorkspaces();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Workspace'),
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
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _pink,
                  onRefresh: loadWorkspaces,
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
                              text: 'Workspaces',
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
                      const Text(
                        'Manage your active projects and collaborative environments.',
                        style: TextStyle(
                          color: _textGrey,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 26),
                      if (workspaces.isEmpty)
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
                                Icons.workspaces_outline,
                                color: _pink,
                                size: 44,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'No hay workspaces todavía',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Crea tu primer workspace para comenzar.',
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
                        ...workspaces.map((workspace) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _WorkspaceCard(
                              workspace: workspace,
                              onTap: () {
                                context.push('/workspace/${workspace['id']}');
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final dynamic workspace;
  final VoidCallback onTap;

  const _WorkspaceCard({required this.workspace, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = workspace['name']?.toString() ?? 'Workspace';
    final description =
        workspace['description']?.toString() ?? 'Sin descripción';
    final members = workspace['member_count']?.toString() ?? '0';
    final projects = workspace['project_count']?.toString() ?? '0';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF232532),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                color: _pink,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: _textGrey,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.person_outline, color: _textGrey, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$members miembro${members == '1' ? '' : 's'}',
                  style: const TextStyle(color: _textGrey, fontSize: 14),
                ),
                const SizedBox(width: 18),
                const Icon(
                  Icons.description_outlined,
                  color: _textGrey,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$projects proyecto${projects == '1' ? '' : 's'}',
                  style: const TextStyle(color: _textGrey, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
