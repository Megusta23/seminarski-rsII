import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/core/widgets/admin_widgets.dart';
import 'package:ladder_social_admin/src/features/users/presentation/user_details_screen.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

final class _UsersScreenState extends ConsumerState<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<PagedResult<AdminUserItem>>? _future;
  bool? _isActive;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load({int? page}) {
    final int target = page ?? _page;
    setState(() {
      _page = target;
      _future = ref.read(adminRepositoryProvider).getUsers(
            search: _searchController.text,
            isActive: _isActive,
            page: target,
          );
    });
  }

  Future<void> _open(AdminUserItem item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => UserDetailsScreen(userId: item.id)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminPageHeader(
            title: 'Users',
            subtitle: 'Search, inspect and control user access.',
            actions: <Widget>[
              IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search name or email',
                  leading: const Icon(Icons.search),
                  onSubmitted: (_) => _load(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _isActive,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const <DropdownMenuItem<bool?>>[
                    DropdownMenuItem<bool?>(value: null, child: Text('All users')),
                    DropdownMenuItem<bool?>(value: true, child: Text('Active')),
                    DropdownMenuItem<bool?>(value: false, child: Text('Inactive')),
                  ],
                  onChanged: (bool? value) {
                    setState(() => _isActive = value);
                    _load(page: 1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<PagedResult<AdminUserItem>>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<PagedResult<AdminUserItem>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return AdminErrorView(error: snapshot.error!, onRetry: _load);
                final PagedResult<AdminUserItem> result = snapshot.data!;
                if (result.items.isEmpty) return const Center(child: Text('No users match the current filters.'));
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            showCheckboxColumn: false,
                            columns: const <DataColumn>[
                              DataColumn(label: Text('User')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('City')),
                              DataColumn(label: Text('Friends'), numeric: true),
                              DataColumn(label: Text('Completed'), numeric: true),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Joined')),
                            ],
                            rows: result.items
                                .map((AdminUserItem item) => DataRow(
                                      onSelectChanged: (_) => _open(item),
                                      cells: <DataCell>[
                                        DataCell(Text(item.displayName)),
                                        DataCell(Text(item.email)),
                                        DataCell(Text(item.cityName ?? '—')),
                                        DataCell(Text('${item.friendCount}')),
                                        DataCell(Text('${item.completedTaskCount}')),
                                        DataCell(Chip(label: Text(item.isActive ? 'Active' : 'Inactive'))),
                                        DataCell(Text(adminDate(item.createdAtUtc))),
                                      ],
                                    ))
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          onPressed: result.page > 1 ? () => _load(page: result.page - 1) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Page ${result.page} of ${result.totalPages == 0 ? 1 : result.totalPages} • ${result.totalCount} users'),
                        IconButton(
                          onPressed: result.page < result.totalPages ? () => _load(page: result.page + 1) : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
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
