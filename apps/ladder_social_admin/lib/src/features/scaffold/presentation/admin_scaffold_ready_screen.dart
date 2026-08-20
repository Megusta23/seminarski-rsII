import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_state.dart';
import 'package:ladder_social_admin/src/features/auth/presentation/admin_change_password_screen.dart';
import 'package:ladder_social_admin/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ladder_social_admin/src/features/moderation/presentation/moderation_screen.dart';
import 'package:ladder_social_admin/src/features/reference_data/presentation/reference_data_screen.dart';
import 'package:ladder_social_admin/src/features/reports/presentation/reports_screen.dart';
import 'package:ladder_social_admin/src/features/users/presentation/users_screen.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class AdminScaffoldReadyScreen extends ConsumerStatefulWidget {
  const AdminScaffoldReadyScreen({super.key});

  @override
  ConsumerState<AdminScaffoldReadyScreen> createState() =>
      _AdminScaffoldReadyScreenState();
}

final class _AdminScaffoldReadyScreenState
    extends ConsumerState<AdminScaffoldReadyScreen> {
  int _selectedIndex = 0;
  bool _extended = true;

  static const List<Widget> _pages = <Widget>[
    DashboardScreen(),
    UsersScreen(),
    ReferenceDataScreen(),
    ModerationScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final AdminAuthState authState = ref.watch(adminAuthControllerProvider);
    final AuthSession session = authState.session!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _extended ? 'Collapse navigation' : 'Expand navigation',
          onPressed: () => setState(() => _extended = !_extended),
          icon: const Icon(Icons.menu),
        ),
        title: const Text('Ladder Social Administration'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(session.email)),
          ),
          IconButton(
            tooltip: 'Change password',
            onPressed: authState.isBusy
                ? null
                : () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminChangePasswordScreen(),
                      ),
                    ),
            icon: const Icon(Icons.password_outlined),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: authState.isBusy
                ? null
                : () => ref.read(adminAuthControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: <Widget>[
          NavigationRail(
            extended: _extended,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int value) =>
                setState(() => _selectedIndex = value),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: CircleAvatar(
                radius: 24,
                child: Text(session.displayName.isEmpty
                    ? 'A'
                    : session.displayName[0].toUpperCase()),
              ),
            ),
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.dataset_outlined),
                selectedIcon: Icon(Icons.dataset),
                label: Text('Reference data'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield),
                label: Text('Moderation'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: Text('Reports'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _pages),
          ),
        ],
      ),
    );
  }
}
