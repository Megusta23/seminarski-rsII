import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/core/widgets/admin_widgets.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class UserDetailsScreen extends ConsumerStatefulWidget {
  const UserDetailsScreen({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

final class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen> {
  Future<AdminUserDetail>? _future;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => _future = ref.read(adminRepositoryProvider).getUser(widget.userId));
  }

  Future<void> _toggle(AdminUserDetail user) async {
    final bool target = !user.isActive;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(target ? 'Activate user?' : 'Deactivate user?'),
        content: Text(
          target
              ? '${user.displayName} will regain access to the application.'
              : '${user.displayName} will no longer be able to sign in.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(target ? 'Activate' : 'Deactivate')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _updating = true);
    try {
      await ref.read(adminRepositoryProvider).setUserActive(user.id, target);
      if (mounted) {
        adminMessage(context, target ? 'User activated.' : 'User deactivated.');
        _load();
      }
    } catch (error) {
      if (mounted) adminMessage(context, ApiException.from(error).message, error: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User details')),
      body: FutureBuilder<AdminUserDetail>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<AdminUserDetail> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return AdminErrorView(error: snapshot.error!, onRetry: _load);
          final AdminUserDetail user = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 42,
                    child: Text(user.displayName.isEmpty ? '?' : user.displayName[0].toUpperCase()),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(user.displayName, style: Theme.of(context).textTheme.headlineSmall),
                        Text(user.email),
                        const SizedBox(height: 5),
                        Chip(
                          avatar: Icon(user.isActive ? Icons.check_circle : Icons.block, size: 16),
                          label: Text(user.isActive ? 'Active' : 'Inactive'),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _updating ? null : () => _toggle(user),
                    icon: _updating
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(user.isActive ? Icons.person_off_outlined : Icons.person_add_alt),
                    label: Text(user.isActive ? 'Deactivate' : 'Activate'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: <Widget>[
                  MetricCard(label: 'Friends', value: user.friendCount, icon: Icons.people_outline),
                  MetricCard(label: 'Tasks', value: user.taskCount, icon: Icons.task_alt_outlined),
                  MetricCard(label: 'Completed', value: user.completedTaskCount, icon: Icons.check_circle_outline),
                  MetricCard(label: 'Posts', value: user.postCount, icon: Icons.dynamic_feed_outlined),
                  MetricCard(label: 'Messages', value: user.messageCount, icon: Icons.chat_bubble_outline),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Profile', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 14),
                      _Row(label: 'First name', value: user.firstName),
                      _Row(label: 'Last name', value: user.lastName),
                      _Row(label: 'City', value: user.cityName ?? 'Not selected'),
                      _Row(label: 'Date of birth', value: user.dateOfBirth == null ? 'Not provided' : adminDate(user.dateOfBirth!)),
                      _Row(label: 'Joined', value: adminDateTime(user.createdAtUtc)),
                      _Row(label: 'Roles', value: user.roles.join(', ')),
                      _Row(label: 'Biography', value: user.bio ?? 'Not provided'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 150, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
