import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/complete_task_screen.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/task_form_screen.dart';

final class TaskDetailsScreen extends ConsumerStatefulWidget {
  const TaskDetailsScreen({required this.taskId, super.key});
  final String taskId;

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

final class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  Future<TaskDetail>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(taskRepositoryProvider).getTask(widget.taskId);
    });
  }

  Future<void> _edit(TaskDetail task) async {
    final TaskDetail? updated = await Navigator.of(context).push<TaskDetail>(
      MaterialPageRoute<TaskDetail>(
        builder: (_) => TaskFormScreen(initialTask: task),
      ),
    );
    if (updated != null && mounted) _load();
  }

  Future<void> _complete(TaskDetail task) async {
    final TaskCompletionItem? completion =
        await Navigator.of(context).push<TaskCompletionItem>(
      MaterialPageRoute<TaskCompletionItem>(
        builder: (_) => CompleteTaskScreen(task: task),
      ),
    );
    if (completion != null && mounted) {
      showMessage(context, 'Task completed. You earned ${completion.scorePoints} point(s).');
      _load();
    }
  }

  Future<void> _delete(TaskDetail task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be removed from your active list.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(taskRepositoryProvider).deleteTask(task.id);
      if (!mounted) return;
      Navigator.of(context).pop<bool>(true);
    } catch (error) {
      if (mounted) showMessage(context, ApiException.from(error).message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task details')),
      body: FutureBuilder<TaskDetail>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<TaskDetail> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppErrorView(error: snapshot.error!, onRetry: _load);
          }
          final TaskDetail task = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            Chip(label: Text(task.categoryName)),
                            Chip(
                              avatar: const Icon(Icons.repeat, size: 16),
                              label: Text(task.recurrenceName),
                            ),
                            Chip(label: Text(TaskStatus.label(task.status))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        _edit(task);
                      }
                      if (value == 'delete') {
                        _delete(task);
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      if (task.canEdit)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              if (task.description != null) ...<Widget>[
                const SizedBox(height: 18),
                Text(task.description!),
              ],
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Deadline'),
                      subtitle: Text(task.dueAtUtc == null
                          ? 'No deadline'
                          : formatDateTime(task.dueAtUtc!)),
                    ),
                    ListTile(
                      leading: Icon(task.requiresProofImage
                          ? Icons.add_a_photo_outlined
                          : Icons.no_photography_outlined),
                      title: const Text('Proof image'),
                      subtitle: Text(task.requiresProofImage ? 'Required' : 'Optional'),
                    ),
                    ListTile(
                      leading: Icon(task.shareWithFriends
                          ? Icons.people_outline
                          : Icons.lock_outline),
                      title: const Text('Sharing'),
                      subtitle: Text(task.shareWithFriends
                          ? 'Completion will appear in friends’ feed'
                          : 'Private task'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: task.canComplete ? () => _complete(task) : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete task'),
              ),
              const SizedBox(height: 24),
              Text('Recent completions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (task.recentCompletions.isEmpty)
                const EmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'No completions yet',
                )
              else
                ...task.recentCompletions.map(
                  (TaskCompletionItem item) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(formatDate(item.occurrenceDate)),
                      subtitle: Text(item.note ?? 'Completed ${formatDateTime(item.completedAtUtc)}'),
                      trailing: Text('+${item.scorePoints}'),
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
