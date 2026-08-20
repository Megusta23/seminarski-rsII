import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ladder_social_mobile/src/core/theme/app_theme.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/auth_gate.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/register_screen.dart';

final GoRouter _router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const MobileAuthGate(),
    ),
    GoRoute(
      path: '/register',
      builder: (BuildContext context, GoRouterState state) =>
          const RegisterScreen(),
    ),
  ],
);

final class LadderSocialMobileApp extends StatelessWidget {
  const LadderSocialMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ladder Social',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
