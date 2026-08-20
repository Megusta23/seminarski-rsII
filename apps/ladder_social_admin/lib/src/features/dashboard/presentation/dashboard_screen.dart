import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/core/widgets/admin_widgets.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

final class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<AdminDashboard>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(adminRepositoryProvider).getDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminPageHeader(
            title: 'Dashboard',
            subtitle: 'Live application activity and productivity overview.',
            actions: <Widget>[
              IconButton.filledTonal(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: FutureBuilder<AdminDashboard>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<AdminDashboard> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AdminErrorView(error: snapshot.error!, onRetry: _load);
                }
                final AdminDashboard dashboard = snapshot.data!;
                return ListView(
                  children: <Widget>[
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: <Widget>[
                        MetricCard(label: 'Total users', value: dashboard.totalUsers, icon: Icons.people_outline),
                        MetricCard(label: 'Active users', value: dashboard.activeUsers, icon: Icons.verified_user_outlined),
                        MetricCard(label: 'Tasks created', value: dashboard.tasksCreated, icon: Icons.task_alt_outlined),
                        MetricCard(label: 'Completed today', value: dashboard.tasksCompletedToday, icon: Icons.check_circle_outline),
                        MetricCard(label: 'Shared posts', value: dashboard.sharedPosts, icon: Icons.dynamic_feed_outlined),
                        MetricCard(label: 'Friend requests', value: dashboard.friendRequests, icon: Icons.person_add_alt),
                        MetricCard(label: 'Messages', value: dashboard.messages, icon: Icons.chat_bubble_outline),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text('Top productive users', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Card(
                      child: dashboard.topUsers.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No task completions have been recorded yet.'),
                            )
                          : DataTable(
                              columns: const <DataColumn>[
                                DataColumn(label: Text('Position')),
                                DataColumn(label: Text('User')),
                                DataColumn(label: Text('Completed tasks'), numeric: true),
                              ],
                              rows: dashboard.topUsers
                                  .asMap()
                                  .entries
                                  .map((MapEntry<int, AdminTopUser> entry) => DataRow(
                                        cells: <DataCell>[
                                          DataCell(Text('${entry.key + 1}')),
                                          DataCell(Text(entry.value.displayName)),
                                          DataCell(Text('${entry.value.completedTaskCount}')),
                                        ],
                                      ))
                                  .toList(growable: false),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Generated ${adminDateTime(dashboard.generatedAtUtc)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
