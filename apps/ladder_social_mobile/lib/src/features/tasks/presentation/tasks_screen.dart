import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/complete_task_screen.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/task_details_screen.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/task_form_screen.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/task_proof_viewer_screen.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_visuals.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_widgets.dart';

final class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

final class _TasksScreenState extends ConsumerState<TasksScreen> {
  static const int _pageSize = 100;

  Future<List<TaskListItem>>? _future;
  final Set<TodoSectionKind> _expandedSections = <TodoSectionKind>{
    TodoSectionKind.todos,
    TodoSectionKind.dailies,
    TodoSectionKind.habits,
  };
  String? _busyTaskId;

  @override
  void initState() {
    super.initState();
    _future = _fetchAllTasks();
  }

  Future<List<TaskListItem>> _fetchAllTasks() async {
    final TaskRepository repository = ref.read(taskRepositoryProvider);
    final List<TaskListItem> all = <TaskListItem>[];
    int page = 1;
    int totalPages = 1;

    do {
      final PagedResult<TaskListItem> result = await repository.getTasks(
        TaskQuery(
          page: page,
          pageSize: _pageSize,
          sortBy: 'dueAtUtc',
          sortDirection: 'asc',
        ),
      );
      all.addAll(result.items.where(todoTaskIsVisible));
      totalPages = result.totalPages;
      page += 1;
    } while (page <= totalPages);

    return List<TaskListItem>.unmodifiable(all);
  }

  Future<void> _load() async {
    final Future<List<TaskListItem>> future = _fetchAllTasks();
    if (!mounted) {
      return;
    }
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder presents the error while RefreshIndicator can finish.
    }
  }

  Future<void> _create() async {
    final TaskDetail? created = await Navigator.of(context).push<TaskDetail>(
      MaterialPageRoute<TaskDetail>(builder: (_) => const TaskFormScreen()),
    );
    if (created != null && mounted) {
      showMessage(context, 'Task created.');
      await _load();
    }
  }

  Future<void> _open(TaskListItem item) async {
    final bool? deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TaskDetailsScreen(taskId: item.id),
      ),
    );
    if (!mounted) {
      return;
    }
    if (deleted == true) {
      showMessage(context, 'Task deleted.');
    }
    await _load();
  }

  Future<void> _handleStatusAction(TaskListItem item) async {
    if (_busyTaskId != null) {
      return;
    }

    if (todoTaskIsCompleted(item)) {
      if (item.requiresProofImage) {
        await _openLatestProof(item);
      } else {
        await _open(item);
      }
      return;
    }

    if (!_isScheduledForToday(item)) {
      if (mounted) {
        showMessage(
          context,
          'This recurring task is not scheduled for today. Open its details to select a valid occurrence date.',
          error: true,
        );
        await _open(item);
      }
      return;
    }

    if (item.requiresProofImage) {
      await _completeWithProof(item);
    } else {
      await _completeWithoutProof(item);
    }
  }

  Future<void> _completeWithProof(TaskListItem item) async {
    setState(() => _busyTaskId = item.id);
    try {
      final TaskDetail task =
          await ref.read(taskRepositoryProvider).getTask(item.id);
      if (!mounted) {
        return;
      }
      final TaskCompletionItem? completion =
          await Navigator.of(context).push<TaskCompletionItem>(
        MaterialPageRoute<TaskCompletionItem>(
          builder: (_) => CompleteTaskScreen(task: task),
        ),
      );
      if (completion != null && mounted) {
        showMessage(
          context,
          'Task completed. You earned ${completion.scorePoints} point(s).',
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyTaskId = null);
      }
    }
  }

  Future<void> _completeWithoutProof(TaskListItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Complete task?'),
        content: Text('Mark “${item.title}” as completed for today?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busyTaskId = item.id);
    try {
      final TaskCompletionItem completion =
          await ref.read(taskRepositoryProvider).completeTask(
                taskId: item.id,
                occurrenceDate: DateTime.now(),
              );
      if (!mounted) {
        return;
      }
      showMessage(
        context,
        'Task completed. You earned ${completion.scorePoints} point(s).',
      );
      await _load();
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyTaskId = null);
      }
    }
  }

  Future<void> _openLatestProof(TaskListItem item) async {
    setState(() => _busyTaskId = item.id);
    try {
      final TaskDetail task =
          await ref.read(taskRepositoryProvider).getTask(item.id);
      final TaskCompletionItem? completion = _matchingProofCompletion(task);
      if (!mounted) {
        return;
      }
      if (completion == null) {
        await _open(item);
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TaskProofViewerScreen(
            task: task,
            completion: completion,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        showMessage(context, ApiException.from(error).message, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busyTaskId = null);
      }
    }
  }

  TaskCompletionItem? _matchingProofCompletion(TaskDetail task) {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    for (final TaskCompletionItem completion in task.recentCompletions) {
      if (completion.proofUrl == null || completion.proofUrl!.isEmpty) {
        continue;
      }
      if (task.recurrenceCode.toLowerCase() == 'none' ||
          DateUtils.isSameDay(completion.occurrenceDate, today)) {
        return completion;
      }
    }
    return null;
  }

  void _toggleSection(TodoSectionKind kind) {
    setState(() {
      if (!_expandedSections.add(kind)) {
        _expandedSections.remove(kind);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FF),
      body: RefreshIndicator(
        onRefresh: _load,
        child: FutureBuilder<List<TaskListItem>>(
          future: _future,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<TaskListItem>> snapshot,
          ) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _TodoLoadingView();
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: AppErrorView(error: snapshot.error!, onRetry: _load),
                  ),
                ],
              );
            }

            final List<TaskListItem> tasks =
                snapshot.data ?? const <TaskListItem>[];
            final Map<TodoSectionKind, List<TaskListItem>> grouped =
                <TodoSectionKind, List<TaskListItem>>{
              for (final TodoSectionKind kind in TodoSectionKind.values)
                kind: sortTodoTasks(
                  tasks.where(
                      (TaskListItem item) => todoSectionFor(item) == kind),
                ),
            };
            final bool hasTasks = tasks.isNotEmpty;

            return ListView(
              key: const PageStorageKey<String>('todo-v2-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 118),
              children: <Widget>[
                if (!hasTasks)
                  const Padding(
                    padding: EdgeInsets.only(top: 120, right: 8),
                    child: EmptyState(
                      icon: Icons.task_alt,
                      title: 'No tasks yet',
                      message: 'Tap + to create your first task.',
                    ),
                  )
                else
                  for (int index = 0;
                      index < TodoSectionKind.values.length;
                      index++) ...<Widget>[
                    TodoTaskSection(
                      kind: TodoSectionKind.values[index],
                      tasks: grouped[TodoSectionKind.values[index]]!,
                      expanded: _expandedSections.contains(
                        TodoSectionKind.values[index],
                      ),
                      onToggle: () => _toggleSection(
                        TodoSectionKind.values[index],
                      ),
                      onOpenTask: _open,
                      onToggleCompletion: _handleStatusAction,
                    ),
                    if (index != TodoSectionKind.values.length - 1)
                      const SizedBox(height: 23),
                  ],
                if (_busyTaskId != null) ...<Widget>[
                  const SizedBox(height: 18),
                  const Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('todo-create-button'),
        onPressed: _busyTaskId == null ? _create : null,
        tooltip: 'Create task',
        backgroundColor: const Color(0xFFB7C2C8),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}

bool _isScheduledForToday(TaskListItem task) {
  final String recurrence = task.recurrenceCode.trim().toLowerCase();
  if (recurrence == 'none' || recurrence == 'daily') {
    return true;
  }

  final DateTime now = DateTime.now();
  final DateTime today = DateUtils.dateOnly(now);
  final DateTime anchorValue = (task.dueAtUtc ?? task.createdAtUtc).toLocal();
  final DateTime anchor = DateUtils.dateOnly(anchorValue);
  if (today.isBefore(anchor)) {
    return false;
  }

  return switch (recurrence) {
    'weekly' => today.difference(anchor).inDays % 7 == 0,
    'monthly' => today.day == anchor.day,
    _ => true,
  };
}

final class _TodoLoadingView extends StatelessWidget {
  const _TodoLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 10, 110),
      children: <Widget>[
        for (int section = 0; section < 3; section++) ...<Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 110,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E1E9),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Divider()),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          for (int row = 0; row < 2; row++) ...<Widget>[
            Container(
              height: 54,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EBF3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 7),
          ],
          if (section < 2) const SizedBox(height: 20),
        ],
      ],
    );
  }
}
