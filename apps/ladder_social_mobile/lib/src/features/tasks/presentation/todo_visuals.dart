import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

enum TodoSectionKind { todos, dailies, habits }

extension TodoSectionKindPresentation on TodoSectionKind {
  String get title => switch (this) {
        TodoSectionKind.todos => "To-do's",
        TodoSectionKind.dailies => 'Dailies',
        TodoSectionKind.habits => 'Habits',
      };

  String get emptyMessage => switch (this) {
        TodoSectionKind.todos => 'No one-time tasks yet.',
        TodoSectionKind.dailies => 'No daily tasks yet.',
        TodoSectionKind.habits => 'No recurring habits yet.',
      };
}

enum TodoTaskVisualState {
  unfinishedWithProof,
  completedWithProof,
  unfinishedWithoutProof,
  completedWithoutProof,
}

final class TodoCategoryPalette {
  const TodoCategoryPalette({
    required this.background,
    required this.accent,
    required this.foreground,
  });

  final Color background;
  final Color accent;
  final Color foreground;
}

const TodoCategoryPalette _creativePalette = TodoCategoryPalette(
  background: Color(0xFFFFF3DE),
  accent: Color(0xFFE4A42F),
  foreground: Color(0xFF5C461E),
);
const TodoCategoryPalette _socialPalette = TodoCategoryPalette(
  background: Color(0xFFE1F6F2),
  accent: Color(0xFF08BFA7),
  foreground: Color(0xFF174F49),
);
const TodoCategoryPalette _selfCarePalette = TodoCategoryPalette(
  background: Color(0xFFF4EAF8),
  accent: Color(0xFFA955C1),
  foreground: Color(0xFF55315F),
);
const TodoCategoryPalette _workPalette = TodoCategoryPalette(
  background: Color(0xFFE7F1FA),
  accent: Color(0xFF3E9DCB),
  foreground: Color(0xFF244E64),
);
const TodoCategoryPalette _fallbackPalette = TodoCategoryPalette(
  background: Color(0xFFF1F3F5),
  accent: Color(0xFF7A8790),
  foreground: Color(0xFF3C444A),
);

TodoCategoryPalette todoCategoryPalette(String code) {
  return switch (code.trim().toLowerCase()) {
    'creative' => _creativePalette,
    'social' => _socialPalette,
    'self-care' || 'selfcare' => _selfCarePalette,
    'work' => _workPalette,
    _ => _fallbackPalette,
  };
}

TodoSectionKind todoSectionFor(TaskListItem task) {
  return switch (task.recurrenceCode.trim().toLowerCase()) {
    'none' => TodoSectionKind.todos,
    'daily' => TodoSectionKind.dailies,
    _ => TodoSectionKind.habits,
  };
}

bool todoTaskIsCompleted(TaskListItem task) {
  final String recurrence = task.recurrenceCode.trim().toLowerCase();
  if (recurrence == 'none') {
    return task.status == TaskStatus.completed || task.isCompletedForToday;
  }
  return task.isCompletedForToday;
}

bool todoTaskIsVisible(TaskListItem task) {
  return task.status == TaskStatus.active || task.status == TaskStatus.completed;
}

TodoTaskVisualState todoTaskVisualState(TaskListItem task) {
  final bool completed = todoTaskIsCompleted(task);
  if (task.requiresProofImage) {
    return completed
        ? TodoTaskVisualState.completedWithProof
        : TodoTaskVisualState.unfinishedWithProof;
  }
  return completed
      ? TodoTaskVisualState.completedWithoutProof
      : TodoTaskVisualState.unfinishedWithoutProof;
}

String todoTaskStateLabel(TaskListItem task) {
  return switch (todoTaskVisualState(task)) {
    TodoTaskVisualState.unfinishedWithProof =>
      'Not completed; a proof image is required',
    TodoTaskVisualState.completedWithProof =>
      'Completed with a proof image',
    TodoTaskVisualState.unfinishedWithoutProof =>
      'Not completed; no proof image is required',
    TodoTaskVisualState.completedWithoutProof =>
      'Completed without a proof image',
  };
}

final class TodoDuePresentation {
  const TodoDuePresentation(this.label, this.color);

  final String label;
  final Color color;
}

TodoDuePresentation? todoDuePresentation(
  TaskListItem task, {
  DateTime? now,
}) {
  if (todoTaskIsCompleted(task) || task.dueAtUtc == null) {
    return null;
  }

  final DateTime businessDate = now == null
      ? calendarDate(task.businessDate)
      : calendarDate(now);
  final DateTime dueDate = utcCalendarDate(task.dueAtUtc!);
  final int days = dueDate.difference(businessDate).inDays;

  if (days < 0) {
    return const TodoDuePresentation('Overdue', Color(0xFFB3261E));
  }
  if (days == 0) {
    return const TodoDuePresentation('Due today', Color(0xFF8A5A00));
  }
  if (days == 1) {
    return const TodoDuePresentation('Tomorrow', Color(0xFF53606A));
  }
  return null;
}

List<TaskListItem> sortTodoTasks(
  Iterable<TaskListItem> values, {
  DateTime? now,
}) {
  final DateTime? suppliedBusinessDate =
      now == null ? null : calendarDate(now);
  final List<TaskListItem> result = values.toList(growable: false);
  result.sort((TaskListItem left, TaskListItem right) {
    final bool leftCompleted = todoTaskIsCompleted(left);
    final bool rightCompleted = todoTaskIsCompleted(right);
    if (leftCompleted != rightCompleted) {
      return leftCompleted ? 1 : -1;
    }

    final DateTime? leftDue = left.dueAtUtc;
    final DateTime? rightDue = right.dueAtUtc;
    final DateTime leftBusinessDate =
        suppliedBusinessDate ?? calendarDate(left.businessDate);
    final DateTime rightBusinessDate =
        suppliedBusinessDate ?? calendarDate(right.businessDate);
    final bool leftOverdue = leftDue != null &&
        utcCalendarDate(leftDue).isBefore(leftBusinessDate);
    final bool rightOverdue = rightDue != null &&
        utcCalendarDate(rightDue).isBefore(rightBusinessDate);
    if (leftOverdue != rightOverdue) {
      return leftOverdue ? -1 : 1;
    }

    if (leftDue == null && rightDue != null) {
      return 1;
    }
    if (leftDue != null && rightDue == null) {
      return -1;
    }
    if (leftDue != null && rightDue != null) {
      final int dueComparison = leftDue.compareTo(rightDue);
      if (dueComparison != 0) {
        return dueComparison;
      }
    }

    final int createdComparison = left.createdAtUtc.compareTo(right.createdAtUtc);
    if (createdComparison != 0) {
      return createdComparison;
    }
    return left.title.toLowerCase().compareTo(right.title.toLowerCase());
  });
  return result;
}
