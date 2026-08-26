import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_visuals.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_widgets.dart';

void main() {
  testWidgets('todo board follows document sections and four task states', (
    WidgetTester tester,
  ) async {
    final List<TaskListItem> todos = <TaskListItem>[
      _task(
        id: 'todo-proof',
        title: 'Prepare monthly analytics presentation',
        categoryCode: 'work',
        recurrenceCode: 'none',
        requiresProof: true,
      ),
      _task(
        id: 'todo-plain',
        title: 'Brainstorm ideas for blog series',
        categoryCode: 'creative',
        recurrenceCode: 'none',
      ),
    ];
    final List<TaskListItem> dailies = <TaskListItem>[
      _task(
        id: 'daily-complete',
        title: 'Call mom and catch up',
        categoryCode: 'social',
        recurrenceCode: 'daily',
        completedToday: true,
      ),
    ];
    final List<TaskListItem> habits = <TaskListItem>[
      _task(
        id: 'habit-proof',
        title: 'Walk the dog',
        categoryCode: 'self-care',
        recurrenceCode: 'weekly',
        requiresProof: true,
        completedToday: true,
      ),
    ];

    TaskListItem? statusTapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                TodoTaskSection(
                  kind: TodoSectionKind.todos,
                  tasks: todos,
                  expanded: true,
                  onToggle: () {},
                  onOpenTask: (_) {},
                  onToggleCompletion: (TaskListItem task) =>
                      statusTapped = task,
                ),
                TodoTaskSection(
                  kind: TodoSectionKind.dailies,
                  tasks: dailies,
                  expanded: true,
                  onToggle: () {},
                  onOpenTask: (_) {},
                  onToggleCompletion: (TaskListItem task) =>
                      statusTapped = task,
                ),
                TodoTaskSection(
                  kind: TodoSectionKind.habits,
                  tasks: habits,
                  expanded: true,
                  onToggle: () {},
                  onOpenTask: (_) {},
                  onToggleCompletion: (TaskListItem task) =>
                      statusTapped = task,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text("To-do's"), findsOneWidget);
    expect(find.text('Dailies'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.byKey(const Key('todo-section-count-todos')), findsOneWidget);
    expect(find.byKey(const Key('todo-section-count-dailies')), findsOneWidget);
    expect(find.byKey(const Key('todo-section-count-habits')), findsOneWidget);
    expect(
      find.byTooltip('Not completed; a proof image is required'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Not completed; no proof image is required'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Completed without a proof image'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Completed with a proof image'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('todo-task-status-todo-proof')));
    expect(statusTapped?.id, 'todo-proof');
  });

  testWidgets('todo section collapses and keeps the count visible', (
    WidgetTester tester,
  ) async {
    bool expanded = true;
    final List<TaskListItem> tasks = <TaskListItem>[
      _task(
        id: 'daily',
        title: 'Daily task',
        categoryCode: 'social',
        recurrenceCode: 'daily',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return TodoTaskSection(
                kind: TodoSectionKind.dailies,
                tasks: tasks,
                expanded: expanded,
                onToggle: () => setState(() => expanded = !expanded),
                onOpenTask: (_) {},
                onToggleCompletion: (_) {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Daily task'), findsOneWidget);
    await tester.tap(find.byKey(const Key('todo-section-header-dailies')));
    await tester.pumpAndSettle();
    expect(find.text('Daily task'), findsNothing);
    expect(find.byKey(const Key('todo-section-count-dailies')), findsOneWidget);
  });

  testWidgets('todo task row remains responsive at narrow width', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 740),
            textScaler: TextScaler.linear(1.2),
          ),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: TodoTaskSection(
                kind: TodoSectionKind.todos,
                tasks: <TaskListItem>[
                  _task(
                    id: 'long',
                    title:
                        'A very long task title that must remain inside the pastel row',
                    categoryCode: 'work',
                    recurrenceCode: 'none',
                  ),
                ],
                expanded: true,
                onToggle: () {},
                onOpenTask: (_) {},
                onToggleCompletion: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('task preview follows selected category and proof state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: TodoTaskPreview(
              title: 'Go for a hike',
              categoryCode: 'self-care',
              requiresProof: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Go for a hike'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.byKey(const Key('todo-task-preview')), findsOneWidget);
  });
}

TaskListItem _task({
  required String id,
  required String title,
  required String categoryCode,
  required String recurrenceCode,
  bool requiresProof = false,
  bool completedToday = false,
}) {
  return TaskListItem(
    id: id,
    title: title,
    categoryName: categoryCode,
    categoryCode: categoryCode,
    recurrenceName: recurrenceCode,
    recurrenceCode: recurrenceCode,
    status: TaskStatus.active,
    requiresProofImage: requiresProof,
    shareWithFriends: false,
    isCompletedForToday: completedToday,
    createdAtUtc: DateTime.utc(2026, 8, 20),
  );
}
