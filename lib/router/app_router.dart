import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/screens/create_project_screen.dart';
import 'package:fsdmovil/screens/create_workspace_screen.dart';
import 'package:fsdmovil/screens/dashboard_screen.dart';
import 'package:fsdmovil/screens/documents_screen.dart';
import 'package:fsdmovil/screens/editor_screen.dart';
import 'package:fsdmovil/screens/login_screen.dart';
import 'package:fsdmovil/screens/preview_screen.dart';
import 'package:fsdmovil/screens/projects_screen.dart';
import 'package:fsdmovil/screens/register_screen.dart';
import 'package:fsdmovil/screens/splash_screen.dart';
import 'package:fsdmovil/screens/workspace_detail_screen.dart';
import 'package:fsdmovil/screens/workspaces_screen.dart';
import 'package:fsdmovil/widgets/main_app_shell.dart';
import 'package:fsdmovil/widgets/top_nav_menu.dart';
import 'package:fsdmovil/screens/reviews_screen.dart';
import 'package:fsdmovil/screens/history_screen.dart';
import 'package:fsdmovil/screens/invitations_screen.dart';
import 'package:fsdmovil/screens/settings_screen.dart';
import 'package:fsdmovil/screens/meeting_mode_screen.dart';
import 'package:fsdmovil/screens/team_meeting_lobby_screen.dart';
import 'package:fsdmovil/screens/team_meeting_room_screen.dart';
import 'package:fsdmovil/screens/team_meeting_ai_result_screen.dart';

final routeObserver = RouteObserver<PageRoute<dynamic>>();

Page<void> _tabTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 180),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  },
);

Page<void> _slideTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 260),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final primaryPosition = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(animation);

    final secondaryPosition = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.12, 0.0),
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(secondaryAnimation);

    return SlideTransition(
      position: primaryPosition,
      child: SlideTransition(position: secondaryPosition, child: child),
    );
  },
);

final appRouter = GoRouter(
  initialLocation: '/splash',
  observers: [routeObserver],
  redirect: (context, state) {
    // El deep link fsdmovil://login-callback es manejado por supabase_flutter
    // internamente. GoRouter no debe procesarlo como ruta.
    final location = state.uri.toString();
    if (location.startsWith('fsdmovil://login-callback') ||
        location.contains('login-callback')) {
      return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const LoginScreen()),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const RegisterScreen()),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const DashboardScreen()),
    ),
    GoRoute(
      path: '/workspaces',
      pageBuilder: (context, state) =>
          _tabTransition(context, state, const WorkspacesScreen()),
    ),
    GoRoute(
      path: '/workspace/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return _slideTransition(
          context,
          state,
          WorkspaceDetailScreen(workspaceId: id),
        );
      },
    ),
    GoRoute(
      path: '/projects',
      pageBuilder: (context, state) =>
          _tabTransition(context, state, const ProjectsScreen()),
    ),
    GoRoute(
      path: '/create-project',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const CreateProjectScreen()),
    ),
    GoRoute(
      path: '/create-workspace',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const CreateWorkspaceScreen()),
    ),
    GoRoute(
      path: '/editor/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return _slideTransition(context, state, EditorScreen(projectId: id));
      },
    ),
    GoRoute(
      path: '/preview/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return _slideTransition(context, state, PreviewScreen(projectId: id));
      },
    ),
    GoRoute(
      path: '/documents',
      pageBuilder: (context, state) =>
          _tabTransition(context, state, const DocumentsScreen()),
    ),
    GoRoute(
      path: '/reviews',
      pageBuilder: (context, state) =>
          _tabTransition(context, state, const ReviewsScreen()),
    ),
    GoRoute(
      path: '/diagrams',
      pageBuilder: (context, state) => _tabTransition(
        context,
        state,
        const _SectionPlaceholderScreen(
          selectedItem: TopNavItem.diagrams,
          eyebrow: 'Diagramas',
          titleWhite: 'Vista de ',
          titlePink: 'diagramas',
          description:
              'Dejaremos esta sección preparada por ahora. Más adelante conectaremos los diagramas reales.',
          icon: Icons.hub_outlined,
          badgeText: 'Pendiente',
        ),
      ),
    ),
    GoRoute(
      path: '/history',
      pageBuilder: (context, state) =>
          _tabTransition(context, state, const HistoryScreen()),
    ),
    GoRoute(
      path: '/invitations',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const InvitationsScreen()),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const SettingsScreen()),
    ),
    GoRoute(
      path: '/meeting-mode',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const MeetingModeScreen()),
    ),
    GoRoute(
      path: '/team-meetings',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const TeamMeetingLobbyScreen()),
    ),
    GoRoute(
      path: '/team-meeting-room/:sessionId',
      pageBuilder: (context, state) {
        final sessionId = int.parse(state.pathParameters['sessionId']!);
        return _slideTransition(
          context,
          state,
          TeamMeetingRoomScreen(sessionId: sessionId),
        );
      },
    ),
    GoRoute(
      path: '/team-meeting-result/:sessionId',
      pageBuilder: (context, state) {
        final sessionId = int.parse(state.pathParameters['sessionId']!);
        return _slideTransition(
          context,
          state,
          TeamMeetingAiResultScreen(sessionId: sessionId),
        );
      },
    ),
  ],
);

class _SectionPlaceholderScreen extends StatelessWidget {
  final TopNavItem selectedItem;
  final String eyebrow;
  final String titleWhite;
  final String titlePink;
  final String description;
  final IconData icon;
  final String badgeText;

  const _SectionPlaceholderScreen({
    required this.selectedItem,
    required this.eyebrow,
    required this.titleWhite,
    required this.titlePink,
    required this.description,
    required this.icon,
    required this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return MainAppShell(
      selectedItem: selectedItem,
      eyebrow: eyebrow,
      titleWhite: titleWhite,
      titlePink: titlePink,
      description: description,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0x22E8365D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: fsdPink),
            ),
            const SizedBox(height: 18),
            Text(
              'Esta sección será la siguiente que construiremos',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: fsdTextGrey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x33E8365D),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: fsdPink),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
