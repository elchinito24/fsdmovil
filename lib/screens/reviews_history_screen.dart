import 'package:flutter/material.dart';
import 'package:fsdmovil/screens/history_screen.dart';
import 'package:fsdmovil/screens/reviews_screen.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

const _pink = Color(0xFFE8365D);
const _textGrey = Color(0xFF8E8E93);
const _borderColor = Color(0xFF3A3A3C);

class ReviewsHistoryScreen extends StatefulWidget {
  const ReviewsHistoryScreen({super.key});

  @override
  State<ReviewsHistoryScreen> createState() => _ReviewsHistoryScreenState();
}

class _ReviewsHistoryScreenState extends State<ReviewsHistoryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      insideShell: true,
      selectedItem: TopNavItem.reviews,
      eyebrow: 'Seguimiento',
      titleWhite: 'Revisiones e ',
      titlePink: 'historial',
      description: 'Aprueba cambios pendientes y consulta el historial de tus proyectos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // Tab selector
          Row(
            children: [
              _TabButton(
                label: 'Revisiones',
                icon: Icons.rate_review_outlined,
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 10),
              _TabButton(
                label: 'Historial',
                icon: Icons.history_rounded,
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Keep both alive with IndexedStack so state isn't lost on switch
          IndexedStack(
            index: _tab,
            children: const [
              ReviewsScreen(embedded: true),
              HistoryScreen(embedded: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _pink.withValues(alpha: 0.15) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _pink : _borderColor,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? _pink : _textGrey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? _pink : _textGrey,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
