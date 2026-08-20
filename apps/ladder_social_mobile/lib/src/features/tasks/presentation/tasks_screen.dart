import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/task_details_screen.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/task_form_screen.dart';

final class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

final class _TasksScreenState extends ConsumerState<TasksScreen> {
  final TextEditingController _searchController = TextEditingController();
  Future<PagedResult<TaskListItem>>? _future;
  List<ReferenceItem> _categories = const <ReferenceItem>[];
  String? _categoryId;
  int? _status = TaskStatus.active;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadReferences();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    try {
      final List<ReferenceItem> values =
          await ref.read(referenceDataRepositoryProvider).getTaskCategories();
      if (mounted) setState(() => _categories = values);
    } catch (_) {
      // The task list remains usable even if the optional filter fails to load.
    }
  }

  void _load({int? page}) {
    final int target = page ?? _page;
    setState(() {
      _page = target;
      _future = ref.read(taskRepositoryProvider).getTasks(
            TaskQuery(
              search: _searchController.text,
              categoryId: _categoryId,
              status: _status,
              page: target,
              sortBy: 'dueAtUtc',
              sortDirection: 'asc',
            ),
          );
    });
  }

  Future<void> _create() async {
    final TaskDetail? created = await Navigator.of(context).push<TaskDetail>(
      MaterialPageRoute<TaskDetail>(builder: (_) => const TaskFormScreen()),
    );
    if (created != null && mounted) {
      showMessage(context, 'Task created.');
      _load(page: 1);
    }
  }

  Future<void> _open(TaskListItem item) async {
    final bool? deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TaskDetailsScreen(taskId: item.id),
      ),
    );
    if (mounted) {
      if (deleted == true) showMessage(context, 'Task deleted.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _load(page: 1),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: <Widget>[
                    SearchBar(
                      controller: _searchController,
                      hintText: 'Search tasks',
                      leading: const Icon(Icons.search),
                      onSubmitted: (_) => _load(page: 1),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _categoryId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              isDense: true,
                            ),
                            items: <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All categories'),
                              ),
                              ..._categories.map(
                                (ReferenceItem item) => DropdownMenuItem<String?>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              ),
                            ],
                            onChanged: (String? value) {
                              setState(() => _categoryId = value);
                              _load(page: 1);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              isDense: true,
                            ),
                            items: const <DropdownMenuItem<int?>>[
                              DropdownMenuItem<int?>(value: null, child: Text('All')),
                              DropdownMenuItem<int?>(value: TaskStatus.active, child: Text('Active')),
                              DropdownMenuItem<int?>(value: TaskStatus.cancelled, child: Text('Cancelled')),
                              DropdownMenuItem<int?>(value: TaskStatus.archived, child: Text('Archived')),
                            ],
                            onChanged: (int? value) {
                              setState(() => _status = value);
                              _load(page: 1);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<PagedResult<TaskListItem>>(
              future: _future,
              builder: (
                BuildContext context,
                AsyncSnapshot<PagedResult<TaskListItem>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: AppErrorView(error: snapshot.error!, onRetry: _load),
                  );
                }
                final PagedResult<TaskListItem> result = snapshot.data!;
                if (result.items.isEmpty) {
                  return const SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.task_alt,
                      title: 'No matching tasks',
                      message: 'Create a task or change the filters.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  sliver: SliverList.separated(
                    itemCount: result.items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == result.items.length) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            IconButton(
                              onPressed: result.page > 1
                                  ? () => _load(page: result.page - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Page ${result.page} of ${result.totalPages == 0 ? 1 : result.totalPages}'),
                            IconButton(
                              onPressed: result.page < result.totalPages
                                  ? () => _load(page: result.page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        );
                      }
                      final TaskListItem item = result.items[index];
                      return Card(
                        child: ListTile(
                          onTap: () => _open(item),
                          leading: Icon(
                            item.isCompletedForToday
                                ? Icons.check_circle
                                : item.requiresProofImage
                                    ? Icons.add_a_photo_outlined
                                    : Icons.radio_button_unchecked,
                            color: item.isCompletedForToday ? Colors.green : null,
                          ),
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.categoryName} • ${item.recurrenceName}'
                            '${item.dueAtUtc == null ? '' : '\nDue ${formatDateTime(item.dueAtUtc!)}'}',
                          ),
                          isThreeLine: item.dueAtUtc != null,
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
    );
  }
}
