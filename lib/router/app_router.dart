import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fsdmovil/screens/login_screen.dart';
import 'package:fsdmovil/screens/register_screen.dart';
import 'package:fsdmovil/screens/dashboard_screen.dart';

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
    // Pantalla nueva: entra desde la derecha al hacer push, sale a la derecha al hacer pop
    final primaryPosition = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(animation);

    // Pantalla de fondo: se desliza a la izquierda cuando una nueva entra encima,
    // y vuelve desde la izquierda cuando la nueva hace pop
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
  initialLocation: '/login',
  routes: [
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
  ],
);
