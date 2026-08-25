import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ladder_social_mobile/src/core/theme/app_theme.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/auth_gate.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/change_password_screen.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/forgot_password_screen.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/register_screen.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/reset_password_screen.dart';
import 'package:ladder_social_mobile/src/features/profile/presentation/edit_profile_screen.dart';
import 'package:ladder_social_mobile/src/features/profile/presentation/manage_highlights_screen.dart';

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
    GoRoute(
      path: '/forgot-password',
      builder: (BuildContext context, GoRouterState state) =>
          const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (BuildContext context, GoRouterState state) =>
          ResetPasswordScreen(
        initialEmail: state.uri.queryParameters['email'],
      ),
    ),
    GoRoute(
      path: '/change-password',
      builder: (BuildContext context, GoRouterState state) =>
          const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      builder: (BuildContext context, GoRouterState state) =>
          const EditProfileScreen(),
    ),
    GoRoute(
      path: '/manage-highlights',
      builder: (BuildContext context, GoRouterState state) =>
          const ManageHighlightsScreen(),
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
