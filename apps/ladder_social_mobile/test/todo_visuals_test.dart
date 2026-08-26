import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_visuals.dart';

void main() {
  test('tasks map into document sections by recurrence', () {
    expect(
      todoSectionFor(_task(id: 'one', recurrenceCode: 'none')),
      TodoSectionKind.todos,
    );
    expect(
      todoSectionFor(_task(id: 'daily', recurrenceCode: 'daily')),
      TodoSectionKind.dailies,
    );
    expect(
      todoSectionFor(_task(id: 'weekly', recurrenceCode: 'weekly')),
      TodoSectionKind.habits,
    );
    expect(
      todoSectionFor(_task(id: 'monthly', recurrenceCode: 'monthly')),
      TodoSectionKind.habits,
    );
  });

  test('all four document task states are represented', () {
    expect(
      todoTaskVisualState(
        _task(id: 'unfinished-proof', requiresProof: true),
      ),
      TodoTaskVisualState.unfinishedWithProof,
    );
    expect(
      todoTaskVisualState(
        _task(
          id: 'completed-proof',
          requiresProof: true,
          completedToday: true,
        ),
      ),
      TodoTaskVisualState.completedWithProof,
    );
    expect(
      todoTaskVisualState(_task(id: 'unfinished-plain')),
      TodoTaskVisualState.unfinishedWithoutProof,
    );
    expect(
      todoTaskVisualState(
        _task(id: 'completed-plain', completedToday: true),
      ),
      TodoTaskVisualState.completedWithoutProof,
    );
  });

  test('completed one-time tasks remain completed after their completion day', () {
    final TaskListItem task = _task(
      id: 'completed-one-time',
      status: TaskStatus.completed,
      recurrenceCode: 'none',
    );

    expect(todoTaskIsCompleted(task), isTrue);
  });

  test('unfinished tasks sort before completed tasks', () {
    final List<TaskListItem> tasks = sortTodoTasks(<TaskListItem>[
      _task(id: 'completed', completedToday: true),
      _task(id: 'unfinished'),
    ]);

    expect(tasks.map((TaskListItem item) => item.id), <String>[
      'unfinished',
      'completed',
    ]);
  });
}

TaskListItem _task({
  required String id,
  String recurrenceCode = 'none',
  int status = TaskStatus.active,
  bool requiresProof = false,
  bool completedToday = false,
}) {
  return TaskListItem(
    id: id,
    title: id,
    categoryName: 'Work',
    categoryCode: 'work',
    recurrenceName: recurrenceCode,
    recurrenceCode: recurrenceCode,
    status: status,
    requiresProofImage: requiresProof,
    shareWithFriends: false,
    isCompletedForToday: completedToday,
    createdAtUtc: DateTime.utc(2026, 8, 25),
  );
}
