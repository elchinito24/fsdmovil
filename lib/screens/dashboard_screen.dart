import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/services/auth_service.dart';

const _pink = Color(0xFFE8365D);
const _darkBg = Color(0xFF0F1017);
const _cardBg = Color(0xFF191B24);
const _borderColor = Color(0xFF2A2D3A);
const _textGrey = Color(0xFF8E8E93);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            _LogoBox(),
            SizedBox(width: 12),
            Text(
              'FSD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
                      text: 'Dashboard',
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
                'Manage your projects, workspaces and collaborative documentation from your mobile app.',
                style: TextStyle(color: _textGrey, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Workspaces',
                      value: 'Gestión',
                      subtitle: 'Crea y administra',
                      icon: Icons.workspaces_outline,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _StatCard(
                      title: 'Projects',
                      value: 'SRS',
                      subtitle: 'Edita documentos',
                      icon: Icons.description_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              const Text(
                'Acciones rápidas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),

              _DashboardActionCard(
                title: 'Mis Proyectos',
                description:
                    'Consulta todos los proyectos creados y continúa editando sus documentos.',
                icon: Icons.folder_outlined,
                onTap: () {
                  context.push('/projects');
                },
              ),
              const SizedBox(height: 14),

              _DashboardActionCard(
                title: 'Crear Proyecto',
                description:
                    'Crea un nuevo proyecto y comienza a trabajar su documento SRS.',
                icon: Icons.add_circle_outline,
                highlighted: true,
                onTap: () {
                  context.push('/create-project');
                },
              ),
              const SizedBox(height: 14),

              _DashboardActionCard(
                title: 'Crear Workspace',
                description:
                    'Organiza equipos y proyectos dentro de un nuevo workspace.',
                icon: Icons.grid_view_rounded,
                onTap: () {
                  context.push('/workspaces');
                },
              ),
              const SizedBox(height: 14),

              _DashboardActionCard(
                title: 'Proyectos Compartidos',
                description:
                    'Consulta proyectos colaborativos y trabajo compartido con otros usuarios.',
                icon: Icons.group_outlined,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBox extends StatelessWidget {
  const _LogoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _pink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text(
          'F',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _pink, size: 24),
          const SizedBox(height: 18),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _textGrey,
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: _textGrey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  const _DashboardActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: highlighted ? _pink : _cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: highlighted ? _pink : _borderColor),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: _pink.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: highlighted
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFF242734),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: highlighted
                          ? Colors.white.withValues(alpha: 0.92)
                          : _textGrey,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: highlighted
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.85),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
