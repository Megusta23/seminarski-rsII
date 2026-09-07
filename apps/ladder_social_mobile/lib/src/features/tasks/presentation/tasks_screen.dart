import 'dart:async';

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
  static const int _pageSize = 15;

  final Map<TodoSectionKind, _TodoSectionPageState> _sections =
      <TodoSectionKind, _TodoSectionPageState>{
    for (final TodoSectionKind kind in TodoSectionKind.values)
      kind: _TodoSectionPageState(),
  };
  final Set<TodoSectionKind> _expandedSections = <TodoSectionKind>{
    TodoSectionKind.todos,
    TodoSectionKind.dailies,
    TodoSectionKind.habits,
  };
  bool _didInitialize = false;
  String? _busyTaskId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) {
      return;
    }
    _didInitialize = true;
    unawaited(_refreshAll());
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>(
      TodoSectionKind.values.map(
        (TodoSectionKind kind) => _loadSection(kind, reset: true),
      ),
    );
  }

  Future<void> _loadSection(
    TodoSectionKind kind, {
    required bool reset,
  }) async {
    final _TodoSectionPageState state = _sections[kind]!;
    if (state.refreshing || state.loadingMore) {
      return;
    }

    final int generation = reset ? ++state.generation : state.generation;
    if (mounted) {
      setState(() {
        if (reset) {
          state.refreshing = true;
          state.loading = state.items.isEmpty;
          state.error = null;
        } else {
          state.loadingMore = true;
          state.loadMoreError = null;
        }
      });
    }

    try {
      final int page = reset ? 1 : state.page + 1;
      final PagedResult<TaskListItem> result =
          await ref.read(taskRepositoryProvider).getTasks(
                TaskQuery(
                  section: _sectionValue(kind),
                  page: page,
                  pageSize: _pageSize,
                  sortBy: 'dueAtUtc',
                  sortDirection: 'asc',
                ),
              );
      if (!mounted || generation != state.generation) {
        return;
      }

      final List<TaskListItem> visible =
          result.items.where(todoTaskIsVisible).toList(growable: false);
      final List<TaskListItem> merged = reset
          ? sortTodoTasks(visible)
          : sortTodoTasks(
              mergeUniqueItems<TaskListItem>(
                current: state.items,
                updates: visible,
                keyOf: (TaskListItem item) => item.id,
              ),
            );
      setState(() {
        state.items = List<TaskListItem>.unmodifiable(merged);
        state.page = result.page;
        state.totalPages = result.totalPages;
        state.totalCount = result.totalCount;
        state.refreshing = false;
        state.loading = false;
        state.loadingMore = false;
        state.error = null;
        state.loadMoreError = null;
      });
    } catch (error) {
      if (!mounted || generation != state.generation) {
        return;
      }
      setState(() {
        state.refreshing = false;
        state.loading = false;
        state.loadingMore = false;
        if (reset && state.items.isEmpty) {
          state.error = error;
        } else {
          state.loadMoreError = error;
        }
      });
    }
  }

  int _sectionValue(TodoSectionKind kind) => switch (kind) {
        TodoSectionKind.todos => TaskBoardSection.todo,
        TodoSectionKind.dailies => TaskBoardSection.daily,
        TodoSectionKind.habits => TaskBoardSection.habit,
      };

  Future<void> _create() async {
    final TaskDetail? created = await Navigator.of(context).push<TaskDetail>(
      MaterialPageRoute<TaskDetail>(builder: (_) => const TaskFormScreen()),
    );
    if (created != null && mounted) {
      showMessage(context, 'Task created.');
      await _refreshAll();
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
    await _refreshAll();
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

    if (!item.canCompleteForToday) {
      if (mounted) {
        showMessage(
          context,
          'This task cannot be completed for the current UTC business date. '
          'Open its details to review valid occurrence dates.',
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
        await _refreshAll();
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
                occurrenceDate: item.businessDate,
              );
      if (!mounted) {
        return;
      }
      showMessage(
        context,
        'Task completed. You earned ${completion.scorePoints} point(s).',
      );
      await _refreshAll();
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
      final TaskCompletionItem? completion = _matchingProofCompletion(
        task,
        item.businessDate,
      );
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

  TaskCompletionItem? _matchingProofCompletion(
    TaskDetail task,
    DateTime businessDate,
  ) {
    for (final TaskCompletionItem completion in task.recentCompletions) {
      if (completion.proofUrl == null || completion.proofUrl!.isEmpty) {
        continue;
      }
      if (task.recurrenceCode.toLowerCase() == 'none' ||
          DateUtils.isSameDay(completion.occurrenceDate, businessDate)) {
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
    final bool initialLoading = _sections.values.every(
      (_TodoSectionPageState state) => state.loading && state.items.isEmpty,
    );
    final bool hasTasks = _sections.values.any(
      (_TodoSectionPageState state) => state.items.isNotEmpty,
    );
    Object? globalError;
    if (!hasTasks) {
      for (final _TodoSectionPageState state in _sections.values) {
        if (state.error != null) {
          globalError = state.error;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FF),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: initialLoading
            ? const _TodoLoadingView()
            : globalError != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.65,
                        child: AppErrorView(
                          error: globalError,
                          onRetry: _refreshAll,
                        ),
                      ),
                    ],
                  )
                : ListView(
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
                          _buildSection(TodoSectionKind.values[index]),
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

  Widget _buildSection(TodoSectionKind kind) {
    final _TodoSectionPageState state = _sections[kind]!;
    return TodoTaskSection(
      kind: kind,
      tasks: state.items,
      totalCount: state.totalCount,
      expanded: _expandedSections.contains(kind),
      initialLoading: state.loading,
      error: state.error,
      hasMore: state.page < state.totalPages,
      isLoadingMore: state.loadingMore,
      paginationError: state.loadMoreError,
      onToggle: () => _toggleSection(kind),
      onOpenTask: _open,
      onToggleCompletion: _handleStatusAction,
      onRetry: () => unawaited(_loadSection(kind, reset: true)),
      onLoadMore: () => unawaited(_loadSection(kind, reset: false)),
    );
  }
}

final class _TodoSectionPageState {
  List<TaskListItem> items = const <TaskListItem>[];
  int page = 0;
  int totalPages = 1;
  int totalCount = 0;
  int generation = 0;
  bool refreshing = false;
  bool loading = false;
  bool loadingMore = false;
  Object? error;
  Object? loadMoreError;
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
