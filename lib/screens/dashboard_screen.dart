import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.dashboard,
      eyebrow: 'Resumen',
      titleWhite: 'Tu panel ',
      titlePink: 'principal',
      description:
          'Administra espacios de trabajo, proyectos y documentación colaborativa desde tu app móvil.',
      action: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _PrimaryActionButton(
                  label: 'Nuevo espacio de trabajo',
                  icon: Icons.add_rounded,
                  onTap: () => context.push('/create-workspace'),
                ),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Accesos rápidos'),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 600 ? 3 : 2;
              final cardW = (w - 16 * (cols - 1)) / cols;
              final ratio = cardW / (cardW * 1.1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: ratio,
                children: [
              _QuickAccessCard(
                title: 'Espacios de trabajo',
                subtitle: 'Administra entornos colaborativos',
                icon: Icons.folder_open_rounded,
                onTap: () => context.go('/workspaces'),
              ),
              _QuickAccessCard(
                title: 'Proyectos',
                subtitle: 'Gestiona proyectos SRS',
                icon: Icons.inventory_2_outlined,
                onTap: () => context.go('/projects'),
              ),
              _QuickAccessCard(
                title: 'Documentos',
                subtitle: 'Consulta documentos creados',
                icon: Icons.description_outlined,
                onTap: () => context.go('/documents'),
              ),
              _QuickAccessCard(
                title: 'Revisiones',
                subtitle: 'Aprueba o solicita cambios',
                icon: Icons.rate_review_outlined,
                onTap: () => context.go('/reviews'),
              ),
              _QuickAccessCard(
                title: 'Modo Reunión',
                subtitle: 'Graba y procesa reuniones',
                icon: Icons.mic_rounded,
                onTap: () => context.push('/meeting-mode'),
              ),
              _QuickAccessCard(
                title: 'Historial',
                subtitle: 'Revisa cambios y versiones',
                icon: Icons.history_rounded,
                onTap: () => context.go('/history'),
              ),
              _QuickAccessCard(
                title: 'Reunión en equipo',
                subtitle: 'Llamada colaborativa del proyecto',
                icon: Icons.groups_rounded,
                onTap: () => context.push('/team-meetings'),
              ),
            ],
          );
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Flujo recomendado'),
          const SizedBox(height: 14),
          const _InfoTimelineCard(),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: fsdPink,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: fsdPink.withOpacity(0.05),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: fsdPink, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: fsdTextGrey,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTimelineCard extends StatelessWidget {
  const _InfoTimelineCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _TimelineStep(
            title: '1. Crear espacio de trabajo',
            subtitle: 'Agrupa equipos y proyectos dentro de un mismo entorno.',
            isFirst: true,
          ),
          _TimelineStep(
            title: '2. Crear proyecto',
            subtitle:
                'Asocia un proyecto al workspace correcto y define su base.',
          ),
          _TimelineStep(
            title: '3. Editar documento SRS',
            subtitle: 'Completa secciones, requisitos y detalles del sistema.',
          ),
          _TimelineStep(
            title: '4. Revisar historial y aprobaciones',
            subtitle: 'Da seguimiento a cambios, versiones y revisiones.',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 14, color: Theme.of(context).colorScheme.outlineVariant)
                else
                  const SizedBox(height: 14),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: fsdPink,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: fsdPink.withOpacity(0.35),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 6),
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: fsdTextGrey,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
