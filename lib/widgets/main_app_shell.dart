import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/providers/auth_provider.dart';
import 'package:fsdmovil/providers/theme_mode_provider.dart';
import 'package:fsdmovil/services/api_service.dart';
import 'package:fsdmovil/services/auth_service.dart';
import 'package:fsdmovil/widgets/app_logo.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';

class MainAppShell extends ConsumerWidget {
  final TopNavItem? selectedItem;
  final String eyebrow;
  final String titleWhite;
  final String titlePink;
  final String description;
  final Widget child;
  final Widget? action;
  final bool useBodyPadding;
  final bool showTopNav;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;
  final bool insideShell;

  const MainAppShell({
    super.key,
    required this.selectedItem,
    required this.eyebrow,
    required this.titleWhite,
    required this.titlePink,
    required this.description,
    required this.child,
    this.action,
    this.useBodyPadding = true,
    this.showTopNav = true,
    this.floatingActionButton,
    this.onRefresh,
    this.insideShell = false,
  });

  String _buildInitials() {
    final first = (AuthService.firstName ?? '').trim();
    final last = (AuthService.lastName ?? '').trim();

    final fromNames = [
      if (first.isNotEmpty) first[0],
      if (last.isNotEmpty) last[0],
    ].join();

    if (fromNames.isNotEmpty) return fromNames.toUpperCase();

    final email = AuthService.userEmail ?? '';
    if (email.trim().isNotEmpty) {
      return email.trim().substring(0, email.length >= 2 ? 2 : 1).toUpperCase();
    }

    return 'AF';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF6F7FB);
    final headerColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);
    final descriptionColor = isDark ? fsdTextGrey : const Color(0xFF6B7280);

    // When inside PersistentShell, skip the outer chrome and render only content.
    if (insideShell) {
      final listView = ListView(
        padding: EdgeInsets.fromLTRB(
          useBodyPadding ? 20 : 0,
          0,
          useBodyPadding ? 20 : 0,
          28,
        ),
        children: [
          if (eyebrow.trim().isNotEmpty) ...[
            Text(
              eyebrow.toUpperCase(),
              style: const TextStyle(
                color: fsdPink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 14),
          ],
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: titleWhite,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 34,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(text: ''),
                TextSpan(
                  text: titlePink,
                  style: const TextStyle(
                    color: fsdPink,
                    fontSize: 34,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: descriptionColor,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 20),
          ],
          child,
        ],
      );
      return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: floatingActionButton,
        body: onRefresh != null
            ? RefreshIndicator(
                color: fsdPink,
                onRefresh: onRefresh!,
                child: listView,
              )
            : listView,
      );
    }

    final initials = _buildInitials();
    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.0, 0.9),
            radius: 1.15,
            colors: [
              const Color(0x20E8365D),
              isDark ? Colors.transparent : const Color(0x00E8365D),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    if (canGoBack) ...[
                      IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: titleColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF2A91D),
                        border: Border.all(
                          color: const Color(0xFFF5C76B),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFF1B1202),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const _NotificationsBell(),
                    const SizedBox(width: 6),
                    const _UserMenuButton(),
                  ],
                ),
              ),
              if (showTopNav) ...[
                TopNavMenu(selected: selectedItem),
                const SizedBox(height: 18),
              ],
              Expanded(
                child: Builder(builder: (context) {
                  final listView = ListView(
                  padding: EdgeInsets.fromLTRB(
                    useBodyPadding ? 20 : 0,
                    0,
                    useBodyPadding ? 20 : 0,
                    28,
                  ),
                  children: [
                    if (eyebrow.trim().isNotEmpty) ...[
                      Text(
                        eyebrow.toUpperCase(),
                        style: const TextStyle(
                          color: fsdPink,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: titleWhite,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TextSpan(text: ''),
                          TextSpan(
                            text: titlePink,
                            style: const TextStyle(
                              color: fsdPink,
                              fontSize: 34,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(
                        color: descriptionColor,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: 14),
                      action!,
                      const SizedBox(height: 12),
                    ] else ...[
                      const SizedBox(height: 20),
                    ],
                    child,
                  ],
                  );
                  return onRefresh != null
                      ? RefreshIndicator(
                          color: fsdPink,
                          onRefresh: onRefresh!,
                          child: listView,
                        )
                      : listView;
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF151823);

    return FutureBuilder<int>(
      future: ApiService.getUnreadNotificationsCount(),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Invitaciones',
              onPressed: () async {
                await context.push('/invitations');
              },
              icon: Icon(Icons.notifications_none_rounded, color: iconColor),
            ),
            if (unread > 0)
              Positioned(
                right: 8,
                top: 6,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: fsdPink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _UserMenuButton extends ConsumerWidget {
  const _UserMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF151823);

    return IconButton(
      tooltip: 'Menú de usuario',
      onPressed: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Cerrar',
          barrierColor: Colors.black.withOpacity(0.35),
          transitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (dialogContext, _, __) {
            return SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: 74,
                    right: 16,
                    child: _UserMenuCard(
                      onClose: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ],
              ),
            );
          },
          transitionBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
      icon: Icon(Icons.more_vert_rounded, color: iconColor),
    );
  }
}

class _UserMenuCard extends ConsumerWidget {
  final VoidCallback onClose;

  const _UserMenuCard({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? fsdCardBg : Colors.white;
    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);
    final subColor = isDark ? fsdTextGrey : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 270,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.16),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AuthService.displayName,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AuthService.userEmail ?? '',
                style: TextStyle(color: subColor, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? fsdDarkBg
                    : const Color(0xFFF2F3F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  _ThemeModeButton(
                    selected: preference == AppThemePreference.light,
                    icon: Icons.light_mode_outlined,
                    onTap: () {
                      ref
                          .read(themePreferenceProvider.notifier)
                          .setPreference(AppThemePreference.light);
                    },
                  ),
                  _ThemeModeButton(
                    selected: preference == AppThemePreference.dark,
                    icon: Icons.dark_mode_outlined,
                    onTap: () {
                      ref
                          .read(themePreferenceProvider.notifier)
                          .setPreference(AppThemePreference.dark);
                    },
                  ),
                  _ThemeModeButton(
                    selected: preference == AppThemePreference.system,
                    icon: Icons.desktop_windows_outlined,
                    onTap: () {
                      ref
                          .read(themePreferenceProvider.notifier)
                          .setPreference(AppThemePreference.system);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            _MenuActionTile(
              icon: Icons.settings_outlined,
              label: 'Configuración',
              color: titleColor,
              onTap: () {
                onClose();
                context.push('/settings');
              },
            ),
            const Divider(height: 1),
            _MenuActionTile(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              color: fsdPink,
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _ThemeModeButton({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected ? Border.all(color: isDark ? fsdBorderColor : const Color(0xFFD1D5DB)) : null,
          ),
          child: Icon(
            icon,
            color: selected
                ? (isDark ? Colors.white : const Color(0xFF151823))
                : fsdTextGrey,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _MenuActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}

// ── Persistent shell ──────────────────────────────────────────────────────────
// Keeps the header and nav bar alive across tab switches (StatefulShellRoute).

class PersistentShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const PersistentShell({super.key, required this.navigationShell});

  static const _tabItems = [
    TopNavItem.dashboard,
    TopNavItem.workspaces,
    TopNavItem.projects,
    TopNavItem.documents,
    TopNavItem.reviews,
    TopNavItem.diagrams,
    TopNavItem.history,
    TopNavItem.schedule,
  ];

  String _buildInitials() {
    final first = (AuthService.firstName ?? '').trim();
    final last = (AuthService.lastName ?? '').trim();
    final fromNames = [
      if (first.isNotEmpty) first[0],
      if (last.isNotEmpty) last[0],
    ].join();
    if (fromNames.isNotEmpty) return fromNames.toUpperCase();
    final email = AuthService.userEmail ?? '';
    if (email.trim().isNotEmpty) {
      return email.trim().substring(0, email.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'AF';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? theme.scaffoldBackgroundColor : const Color(0xFFF6F7FB);
    final headerColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark ? fsdBorderColor : const Color(0xFFE5E7EF);
    final titleColor = isDark ? Colors.white : const Color(0xFF151823);
    final initials = _buildInitials();

    final idx = navigationShell.currentIndex;
    final selected = idx < _tabItems.length ? _tabItems[idx] : null;

    final currentPath = GoRouterState.of(context).uri.path;
    const _rootPaths = {
      '/dashboard', '/workspaces', '/projects', '/documents',
      '/reviews', '/diagrams', '/history', '/meeting-mode', '/schedule',
    };
    final isSubPage = !_rootPaths.contains(currentPath);

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.0, 0.9),
            radius: 1.15,
            colors: [
              const Color(0x20E8365D),
              isDark ? Colors.transparent : const Color(0x00E8365D),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-0.4, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          )),
                          child: child,
                        ),
                      ),
                      child: isSubPage
                          ? Row(
                              key: const ValueKey('back'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Volver',
                                  onPressed: () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/workspaces');
                                    }
                                  },
                                  icon: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: titleColor,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 4),
                              ],
                            )
                          : const SizedBox.shrink(key: ValueKey('no-back')),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF2A91D),
                        border: Border.all(
                          color: const Color(0xFFF5C76B),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFF1B1202),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Modo Reunión',
                      onPressed: () => context.go('/meeting-mode'),
                      icon: Icon(Icons.mic_rounded, color: titleColor),
                    ),
                    const _NotificationsBell(),
                    const SizedBox(width: 6),
                    const _UserMenuButton(),
                  ],
                ),
              ),
              TopNavMenu(selected: selected),
              const SizedBox(height: 18),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      ),
    );
  }
}
