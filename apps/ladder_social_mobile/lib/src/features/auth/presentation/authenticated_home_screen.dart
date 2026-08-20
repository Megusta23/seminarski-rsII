import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        title: const Text('Ladder Social'),
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
                        Expanded(
                          child: Text(
                            'Protected profile',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit profile',
                          onPressed: () => context.push('/edit-profile'),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'First name', value: value.firstName),
                    _InfoRow(label: 'Last name', value: value.lastName),
                    _InfoRow(
                      label: 'Biography',
                      value: value.bio ?? 'Not provided',
                    ),
                    _InfoRow(
                      label: 'City',
                      value: value.cityName ?? 'Not selected',
                    ),
                    _InfoRow(
                      label: 'Date of birth',
                      value: value.dateOfBirth == null
                          ? 'Not provided'
                          : _date(value.dateOfBirth!),
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
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Edit profile'),
                  subtitle: const Text(
                    'Update your name, biography, city and date of birth.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/edit-profile'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Change password'),
                  subtitle: const Text(
                    'All active sessions are revoked after a password change.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/change-password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.construction_outlined),
              title: Text('Next business module'),
              subtitle: Text(
                'Task CRUD, completion history and the mobile to-do master-detail flow.',
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

  static String _date(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
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
