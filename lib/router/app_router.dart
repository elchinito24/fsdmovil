import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/screens/splash_screen.dart';
import 'package:fsdmovil/screens/login_screen.dart';
import 'package:fsdmovil/screens/register_screen.dart';
import 'package:fsdmovil/screens/dashboard_screen.dart';
import 'package:fsdmovil/screens/projects_screen.dart';
import 'package:fsdmovil/screens/editor_screen.dart';
import 'package:fsdmovil/screens/preview_screen.dart';
import 'package:fsdmovil/screens/create_project_screen.dart';
import 'package:fsdmovil/screens/create_workspace_screen.dart';
import 'package:fsdmovil/screens/workspaces_screen.dart';
import 'package:fsdmovil/screens/workspace_detail_screen.dart';

final routeObserver = RouteObserver<PageRoute<dynamic>>();

Page<void> _slideTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 300),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final primaryPosition = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(animation);

    final secondaryPosition = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
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
      path: '/projects',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const ProjectsScreen()),
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
      path: '/workspaces',
      pageBuilder: (context, state) =>
          _slideTransition(context, state, const WorkspacesScreen()),
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
  ],
);
