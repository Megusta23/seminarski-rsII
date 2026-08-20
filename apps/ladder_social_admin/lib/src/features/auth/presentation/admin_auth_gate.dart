import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_state.dart';
import 'package:ladder_social_admin/src/features/auth/presentation/admin_login_screen.dart';
import 'package:ladder_social_admin/src/features/scaffold/presentation/admin_scaffold_ready_screen.dart';

final class AdminAuthGate extends ConsumerWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdminAuthState state = ref.watch(adminAuthControllerProvider);

    if (state.status == AdminAuthStatus.checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isAuthenticated) {
      return const AdminScaffoldReadyScreen();
    }

    return const AdminLoginScreen();
  }
}
