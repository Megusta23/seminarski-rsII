import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_visuals.dart';

final class TodoTaskSection extends StatelessWidget {
  const TodoTaskSection({
    required this.kind,
    required this.tasks,
    required this.expanded,
    required this.onToggle,
    required this.onOpenTask,
    required this.onToggleCompletion,
    super.key,
  });

  final TodoSectionKind kind;
  final List<TaskListItem> tasks;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<TaskListItem> onOpenTask;
  final ValueChanged<TaskListItem> onToggleCompletion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TodoSectionHeader(
          key: Key('todo-section-header-${kind.name}'),
          kind: kind,
          count: tasks.length,
          expanded: expanded,
          onTap: onToggle,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: tasks.isEmpty
                      ? _TodoEmptySection(kind: kind)
                      : Column(
                          children: <Widget>[
                            for (int index = 0; index < tasks.length; index++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == tasks.length - 1 ? 0 : 7,
                                ),
                                child: TodoTaskRow(
                                  key: Key('todo-task-${tasks[index].id}'),
                                  task: tasks[index],
                                  isLast: index == tasks.length - 1,
                                  onOpen: () => onOpenTask(tasks[index]),
                                  onToggleCompletion: () =>
                                      onToggleCompletion(tasks[index]),
                                ),
                              ),
                          ],
                        ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

final class _TodoSectionHeader extends StatelessWidget {
  const _TodoSectionHeader({
    required this.kind,
    required this.count,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final TodoSectionKind kind;
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color railColor = Color(0xFF9FBAC3);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      expanded: expanded,
      label: '${kind.title}, $count tasks',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            children: <Widget>[
              AnimatedRotation(
                turns: expanded ? 0 : -0.25,
                duration: const Duration(milliseconds: 160),
                child: const Icon(Icons.keyboard_arrow_down, size: 25),
              ),
              const SizedBox(width: 2),
              Text(
                kind.title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Divider(height: 1, thickness: 1, color: railColor),
              ),
              SizedBox(
                width: 48,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned(
                      top: 33,
                      bottom: 0,
                      left: 23,
                      child: Container(width: 2, color: railColor),
                    ),
                    Container(
                      key: Key('todo-section-count-${kind.name}'),
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F7F9),
                        border: Border.all(color: const Color(0xFF8F9BA3)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Text(
                            '$count',
                            style: textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF515A60),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _TodoEmptySection extends StatelessWidget {
  const _TodoEmptySection({required this.kind});

  final TodoSectionKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('todo-empty-${kind.name}'),
      margin: const EdgeInsets.only(right: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        kind.emptyMessage,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF7D7880),
            ),
      ),
    );
  }
}

final class TodoTaskRow extends StatelessWidget {
  const TodoTaskRow({
    required this.task,
    required this.isLast,
    required this.onOpen,
    required this.onToggleCompletion,
    this.now,
    super.key,
  });

  final TaskListItem task;
  final bool isLast;
  final VoidCallback onOpen;
  final VoidCallback onToggleCompletion;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final TodoCategoryPalette palette = todoCategoryPalette(task.categoryCode);
    final bool completed = todoTaskIsCompleted(task);
    final TodoDuePresentation? due = todoDuePresentation(task, now: now);
    final String stateLabel = todoTaskStateLabel(task);

    return Material(
      color: palette.background,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.only(right: 48),
              child: Semantics(
                button: true,
                label: '${task.title}. ${task.categoryName}. $stateLabel',
                child: InkWell(
                  onTap: onOpen,
                  onLongPress: onOpen,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      due == null ? 14 : 9,
                      8,
                      9,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: completed
                                          ? const Color(0xFF9AA6AD)
                                          : const Color(0xFF30343A),
                                      fontWeight: FontWeight.w500,
                                      height: 1.15,
                                      decoration: completed
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: const Color(0xFF9AA6AD),
                                    ),
                          ),
                          if (due != null) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              due.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: due.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 48,
            child: _TodoStatusRail(
              task: task,
              accent: palette.accent,
              isLast: isLast,
              onTap: onToggleCompletion,
            ),
          ),
        ],
      ),
    );
  }
}

final class _TodoStatusRail extends StatelessWidget {
  const _TodoStatusRail({
    required this.task,
    required this.accent,
    required this.isLast,
    required this.onTap,
  });

  final TaskListItem task;
  final Color accent;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color lineColor = accent.withValues(alpha: 0.68);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double centerY = constraints.maxHeight / 2;
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              top: 0,
              height: centerY,
              left: 23,
              child: Container(width: 2, color: lineColor),
            ),
            if (!isLast)
              Positioned(
                top: centerY,
                bottom: 0,
                left: 23,
                child: Container(width: 2, color: lineColor),
              ),
            TodoTaskStatusBox(
              task: task,
              accent: accent,
              onTap: onTap,
            ),
          ],
        );
      },
    );
  }
}

final class TodoTaskStatusBox extends StatelessWidget {
  const TodoTaskStatusBox({
    required this.task,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final TaskListItem task;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TodoTaskVisualState state = todoTaskVisualState(task);
    final bool completed = todoTaskIsCompleted(task);
    final String label = todoTaskStateLabel(task);

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            key: Key('todo-task-status-${task.id}'),
            onTap: onTap,
            radius: 24,
            child: Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: completed
                    ? Colors.white.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.72),
                border: Border.all(color: accent, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: switch (state) {
                TodoTaskVisualState.unfinishedWithProof => Icon(
                    Icons.photo_camera_outlined,
                    size: 19,
                    color: accent,
                  ),
                TodoTaskVisualState.completedWithProof => Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Icon(Icons.photo_library_outlined,
                          size: 18, color: accent),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                TodoTaskVisualState.unfinishedWithoutProof =>
                  const SizedBox.shrink(),
                TodoTaskVisualState.completedWithoutProof => Icon(
                    Icons.check,
                    size: 21,
                    color: accent,
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

final class TodoTaskPreview extends StatelessWidget {
  const TodoTaskPreview({
    required this.title,
    required this.categoryCode,
    required this.requiresProof,
    super.key,
  });

  final String title;
  final String categoryCode;
  final bool requiresProof;

  @override
  Widget build(BuildContext context) {
    final TodoCategoryPalette palette = todoCategoryPalette(categoryCode);
    return Container(
      key: const Key('todo-task-preview'),
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E1E8)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                title.trim().isEmpty ? 'Your task preview' : title.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF36313A),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Center(
              child: Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  border: Border.all(color: palette.accent, width: 2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: requiresProof
                    ? Icon(
                        Icons.photo_camera_outlined,
                        size: 19,
                        color: palette.accent,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
