import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_state.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/authenticated_home_screen.dart';
import 'package:ladder_social_mobile/src/features/auth/presentation/login_screen.dart';

final class MobileAuthGate extends ConsumerWidget {
  const MobileAuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MobileAuthState state = ref.watch(mobileAuthControllerProvider);

    if (state.status == MobileAuthStatus.checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isAuthenticated) {
      return const AuthenticatedHomeScreen();
    }

    return const LoginScreen();
  }
}
