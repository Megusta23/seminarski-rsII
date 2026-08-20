import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/core/providers/core_providers.dart';
import 'package:ladder_social_admin/src/core/widgets/admin_widgets.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

final class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<PagedResult<AdminPostItem>>? _future;
  bool? _isVisible;
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
      _future = ref.read(adminRepositoryProvider).getPosts(
            search: _searchController.text,
            isVisible: _isVisible,
            page: target,
          );
    });
  }

  Future<void> _toggle(AdminPostItem item) async {
    final bool target = !item.isVisible;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(target ? 'Restore post?' : 'Hide post?'),
        content: Text(
          target
              ? 'The post will become visible to eligible friends again.'
              : 'The post will be hidden from all feeds.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(target ? 'Restore' : 'Hide')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminRepositoryProvider).setPostVisibility(item.id, target);
      if (mounted) {
        adminMessage(context, target ? 'Post restored.' : 'Post hidden.');
        _load();
      }
    } catch (error) {
      if (mounted) adminMessage(context, ApiException.from(error).message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminPageHeader(
            title: 'Post moderation',
            subtitle: 'Review shared task completions and control their visibility.',
            actions: <Widget>[
              IconButton.filledTonal(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search author, task or caption',
                  leading: const Icon(Icons.search),
                  onSubmitted: (_) => _load(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _isVisible,
                  decoration: const InputDecoration(labelText: 'Visibility'),
                  items: const <DropdownMenuItem<bool?>>[
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: true, child: Text('Visible')),
                    DropdownMenuItem(value: false, child: Text('Hidden')),
                  ],
                  onChanged: (bool? value) {
                    setState(() => _isVisible = value);
                    _load(page: 1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<PagedResult<AdminPostItem>>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<PagedResult<AdminPostItem>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return AdminErrorView(error: snapshot.error!, onRetry: _load);
                final PagedResult<AdminPostItem> result = snapshot.data!;
                if (result.items.isEmpty) return const Center(child: Text('No posts match the current filters.'));
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const <DataColumn>[
                              DataColumn(label: Text('Author')),
                              DataColumn(label: Text('Task')),
                              DataColumn(label: Text('Caption')),
                              DataColumn(label: Text('Created')),
                              DataColumn(label: Text('Visibility')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: result.items
                                .map((AdminPostItem item) => DataRow(cells: <DataCell>[
                                      DataCell(Text(item.authorDisplayName)),
                                      DataCell(Text(item.taskTitle)),
                                      DataCell(SizedBox(
                                        width: 300,
                                        child: Text(item.caption ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                                      )),
                                      DataCell(Text(adminDateTime(item.createdAtUtc))),
                                      DataCell(Chip(label: Text(item.isVisible ? 'Visible' : 'Hidden'))),
                                      DataCell(IconButton(
                                        tooltip: item.isVisible ? 'Hide post' : 'Restore post',
                                        onPressed: () => _toggle(item),
                                        icon: Icon(item.isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                      )),
                                    ]))
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton(onPressed: result.page > 1 ? () => _load(page: result.page - 1) : null, icon: const Icon(Icons.chevron_left)),
                        Text('Page ${result.page} of ${result.totalPages == 0 ? 1 : result.totalPages}'),
                        IconButton(onPressed: result.page < result.totalPages ? () => _load(page: result.page + 1) : null, icon: const Icon(Icons.chevron_right)),
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
