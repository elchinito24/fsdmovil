import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Color fsdPink = Color(0xFFE8365D);
const Color fsdDarkBg = Color(0xFF0F1017);
const Color fsdCardBg = Color(0xFF191B24);
const Color fsdBorderColor = Color(0xFF2A2D3A);
const Color fsdTextGrey = Color(0xFF8E8E93);

enum TopNavItem { workspaces, projects, documents, reviews, diagrams, history }

class TopNavMenu extends StatelessWidget {
  final TopNavItem? selected;

  const TopNavMenu({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final items = <_NavMenuData>[
      _NavMenuData(
        label: 'Espacios de trabajo',
        item: TopNavItem.workspaces,
        route: '/workspaces',
      ),
      _NavMenuData(
        label: 'Proyectos',
        item: TopNavItem.projects,
        route: '/projects',
      ),
      _NavMenuData(
        label: 'Documentos',
        item: TopNavItem.documents,
        route: '/documents',
      ),
      _NavMenuData(
        label: 'Revisiones',
        item: TopNavItem.reviews,
        route: '/reviews',
      ),
      _NavMenuData(
        label: 'Diagramas',
        item: TopNavItem.diagrams,
        route: '/diagrams',
      ),
      _NavMenuData(
        label: 'Historial',
        item: TopNavItem.history,
        route: '/history',
      ),
    ];

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          final nav = items[index];
          final isSelected = nav.item == selected;

          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (!isSelected) {
                context.go(nav.route);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0x33E8365D)
                    : const Color(0xFF171922),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? fsdPink : fsdBorderColor,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: fsdPink.withOpacity(0.14),
                          blurRadius: 16,
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  nav.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : fsdTextGrey,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: items.length,
      ),
    );
  }
}

class _NavMenuData {
  final String label;
  final TopNavItem item;
  final String route;

  const _NavMenuData({
    required this.label,
    required this.item,
    required this.route,
  });
}
