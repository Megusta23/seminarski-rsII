import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_state.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class AdminScaffoldReadyScreen extends ConsumerWidget {
  const AdminScaffoldReadyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdminAuthState authState = ref.watch(adminAuthControllerProvider);
    final AuthSession session = authState.session!;
    final AsyncValue<CurrentProfile> profile = ref.watch(adminProfileProvider);
    final AsyncValue<AdminAccessResult> access =
        ref.watch(adminAccessProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ladder Social Admin'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(session.email)),
          ),
          IconButton(
            tooltip: 'Reload authentication checks',
            onPressed: () {
              ref.invalidate(adminProfileProvider);
              ref.invalidate(adminAccessProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: authState.isBusy
                ? null
                : () => ref
                    .read(adminAuthControllerProvider.notifier)
                    .logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: 0,
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
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: Text('Reports'),
              ),
            ],
            onDestinationSelected: null,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(32),
              children: <Widget>[
                Text(
                  'Authentication dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'The remaining admin modules stay disabled until their backend features are implemented.',
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: <Widget>[
                    _StatusCard(
                      title: 'JWT session',
                      icon: Icons.key,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(session.displayName),
                          Text(session.email),
                          Text('Roles: ${session.roles.join(', ')}'),
                          Text(
                            'Expires: ${session.accessTokenExpiresAtUtc.toLocal()}',
                          ),
                        ],
                      ),
                    ),
                    _StatusCard(
                      title: 'Protected profile endpoint',
                      icon: Icons.verified_user_outlined,
                      child: profile.when(
                        data: (CurrentProfile value) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${value.firstName} ${value.lastName}'),
                            Text(value.email),
                            Text('City: ${value.cityName ?? 'Not selected'}'),
                          ],
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (Object error, StackTrace stackTrace) => Text(
                          ApiException.from(error).message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                    _StatusCard(
                      title: 'Admin role authorization',
                      icon: Icons.admin_panel_settings_outlined,
                      child: access.when(
                        data: (AdminAccessResult value) => Row(
                          children: <Widget>[
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(value.message)),
                          ],
                        ),
                        loading: () => const CircularProgressIndicator(),
                        error: (Object error, StackTrace stackTrace) => Text(
                          ApiException.from(error).message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (authState.isBusy) ...<Widget>[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                ],
                if (authState.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    authState.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
