import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_state.dart';

final class AuthenticatedHomeScreen extends ConsumerWidget {
  const AuthenticatedHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MobileAuthState authState =
        ref.watch(mobileAuthControllerProvider);
    final AuthSession session = authState.session!;
    final AsyncValue<CurrentProfile> profile =
        ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authentication test'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload profile',
            onPressed: () => ref.invalidate(currentProfileProvider),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: authState.isBusy
                ? null
                : () => ref
                    .read(mobileAuthControllerProvider.notifier)
                    .logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Authenticated session',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'User', value: session.displayName),
                  _InfoRow(label: 'Email', value: session.email),
                  _InfoRow(label: 'Roles', value: session.roles.join(', ')),
                  _InfoRow(
                    label: 'Access token expires',
                    value: session.accessTokenExpiresAtUtc.toLocal().toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          profile.when(
            data: (CurrentProfile value) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.verified_user_outlined),
                        const SizedBox(width: 10),
                        Text(
                          'Protected /api/profile/me result',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'First name', value: value.firstName),
                    _InfoRow(label: 'Last name', value: value.lastName),
                    _InfoRow(
                      label: 'City',
                      value: value.cityName ?? 'Not selected',
                    ),
                    _InfoRow(
                      label: 'Profile roles',
                      value: value.roles.join(', '),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (Object error, StackTrace stackTrace) => Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(ApiException.from(error).message),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.security),
              title: Text('What is being tested'),
              subtitle: Text(
                'JWT authorization, secure token storage, refresh-token rotation, '
                'protected profile access and server-side logout invalidation.',
              ),
            ),
          ),
          if (authState.isBusy) ...<Widget>[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (authState.errorMessage != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              authState.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
