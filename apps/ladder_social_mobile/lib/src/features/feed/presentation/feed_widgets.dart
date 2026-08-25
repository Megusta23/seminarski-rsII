import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

String formatFeedRelativeTime(DateTime value, {DateTime? now}) {
  final DateTime reference = (now ?? DateTime.now()).toUtc();
  final DateTime timestamp = value.toUtc();
  final Duration difference = reference.difference(timestamp);

  if (difference.isNegative || difference.inSeconds < 45) {
    return 'Just now';
  }
  if (difference.inMinutes < 60) {
    final int minutes = difference.inMinutes;
    return '$minutes min ago';
  }
  if (difference.inHours < 24) {
    final int hours = difference.inHours;
    return '$hours h ago';
  }
  if (difference.inDays < 7) {
    final int days = difference.inDays;
    return '$days d ago';
  }
  return formatDate(timestamp);
}

final class FeedStatusIndicator extends StatelessWidget {
  const FeedStatusIndicator({required this.post, super.key});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ({IconData icon, String label, Color color}) presentation = switch (
        post.activityType) {
      FeedActivityType.unfinished => (
          icon: Icons.check_box_outline_blank,
          label: 'Not completed',
          color: colors.outline,
        ),
      FeedActivityType.completedWithoutProof => (
          icon: Icons.check_box_outlined,
          label: 'Completed · No proof',
          color: colors.primary,
        ),
      FeedActivityType.completedWithProof when post.hasBeenViewed => (
          icon: Icons.check_box_outlined,
          label: 'Completed · Proof viewed',
          color: colors.primary,
        ),
      FeedActivityType.completedWithProof => (
          icon: Icons.check_box,
          label: 'Completed · New proof',
          color: colors.tertiary,
        ),
    };

    return Semantics(
      label: presentation.label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: presentation.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: presentation.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(presentation.icon, size: 17, color: presentation.color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                presentation.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: presentation.color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact, document-aligned feed card: one friend header followed by all
/// shared tasks for the selected day. The right-side rail mirrors the original
/// Ladder Social mock-up and doubles as the proof/view state indicator.
final class FriendFeedCard extends StatelessWidget {
  const FriendFeedCard({
    required this.progress,
    required this.tasks,
    required this.onOpenFriend,
    required this.onOpenTask,
    required this.onOpenProof,
    this.now,
    super.key,
  });

  final FriendProgress progress;
  final List<FeedPost> tasks;
  final VoidCallback onOpenFriend;
  final ValueChanged<FeedPost> onOpenTask;
  final ValueChanged<FeedPost> onOpenProof;
  final DateTime? now;

  DateTime get _latestActivityAt => tasks
      .map((FeedPost item) => item.activityAtUtc)
      .reduce((DateTime current, DateTime next) => next.isAfter(current) ? next : current);

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    const Color borderColor = Color(0xFFB9C7D0);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _FriendFeedHeader(
            progress: progress,
            relativeTime: formatFeedRelativeTime(_latestActivityAt, now: now),
            onTap: onOpenFriend,
          ),
          const Divider(height: 1, thickness: 1, color: borderColor),
          for (int index = 0; index < tasks.length; index++)
            _FriendTaskRow(
              post: tasks[index],
              isFirst: index == 0,
              isLast: index == tasks.length - 1,
              onTap: tasks[index].hasProof
                  ? () => onOpenProof(tasks[index])
                  : () => onOpenTask(tasks[index]),
            ),
        ],
      ),
    );
  }
}

final class _FriendFeedHeader extends StatelessWidget {
  const _FriendFeedHeader({
    required this.progress,
    required this.relativeTime,
    required this.onTap,
  });

  final FriendProgress progress;
  final String relativeTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
          child: Row(
            children: <Widget>[
              UserAvatar(
                displayName: progress.displayName,
                avatarUrl: progress.avatarUrl,
                radius: 18,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      progress.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      relativeTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9AA3AB),
                            height: 1,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _HeaderMetric(
                icon: Icons.light_mode_outlined,
                value: progress.completedToday,
                color: const Color(0xFF57C96D),
                tooltip: '${progress.completedToday} shared tasks completed today',
              ),
              const SizedBox(width: 10),
              _HeaderMetric(
                icon: Icons.local_fire_department,
                value: progress.currentStreak,
                color: const Color(0xFFFF9A3D),
                tooltip: '${progress.currentStreak}-day streak',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.icon,
    required this.value,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final int value;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 3),
            Text(
              '$value',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _FriendTaskRow extends StatelessWidget {
  const _FriendTaskRow({
    required this.post,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final FeedPost post;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _CategoryPalette palette = _categoryPalette(post.categoryCode);
    final String semanticsLabel = _taskStateLabel(post);

    return Semantics(
      button: true,
      label: '${post.taskTitle}. $semanticsLabel',
      child: Material(
        color: palette.background,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 11, 8, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        post.taskTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: post.isCompleted
                                  ? const Color(0xFF30343A)
                                  : const Color(0xFFADB7BE),
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                            ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: _TaskStatusRail(
                    post: post,
                    accent: palette.accent,
                    isFirst: isFirst,
                    isLast: isLast,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _TaskStatusRail extends StatelessWidget {
  const _TaskStatusRail({
    required this.post,
    required this.accent,
    required this.isFirst,
    required this.isLast,
  });

  final FeedPost post;
  final Color accent;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color lineColor = post.isCompleted
        ? accent.withValues(alpha: 0.78)
        : const Color(0xFFB7C4CC);

    return Tooltip(
      message: _taskStateLabel(post),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double centerY = constraints.maxHeight / 2;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (!isFirst)
                Positioned(
                  top: 0,
                  height: centerY,
                  left: 21.5,
                  child: Container(width: 2, color: lineColor),
                ),
              if (!isLast)
                Positioned(
                  top: centerY,
                  bottom: 0,
                  left: 21.5,
                  child: Container(width: 2, color: lineColor),
                ),
              _TaskStatusBox(post: post, accent: accent),
            ],
          );
        },
      ),
    );
  }
}

final class _TaskStatusBox extends StatelessWidget {
  const _TaskStatusBox({required this.post, required this.accent});

  final FeedPost post;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool filled = post.hasUnseenProof;
    final bool unfinished = !post.isCompleted;
    final Color borderColor = unfinished ? const Color(0xFFB6C2CA) : accent;
    final Color backgroundColor = unfinished
        ? const Color(0xFFBCC8D0)
        : filled
            ? accent
            : Colors.white.withValues(alpha: 0.82);
    final Color checkColor = filled ? Colors.white : accent;

    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: unfinished ? 1 : 2),
        borderRadius: BorderRadius.circular(2),
      ),
      child: post.isCompleted
          ? Icon(Icons.check, size: 18, color: checkColor)
          : null,
    );
  }
}

String _taskStateLabel(FeedPost post) {
  if (!post.isCompleted) return 'Not completed';
  if (!post.hasProof) return 'Completed without a proof image';
  if (post.hasBeenViewed) return 'Completed; proof image viewed';
  return 'Completed with a new proof image';
}

_CategoryPalette _categoryPalette(String code) {
  return switch (code.toLowerCase()) {
    'self-care' => const _CategoryPalette(
        background: Color(0xFFF4EAF8),
        accent: Color(0xFFA955C1),
      ),
    'social' => const _CategoryPalette(
        background: Color(0xFFE6F8F2),
        accent: Color(0xFF08BFA7),
      ),
    'creative' => const _CategoryPalette(
        background: Color(0xFFFFF3DE),
        accent: Color(0xFFE4A42F),
      ),
    'work' => const _CategoryPalette(
        background: Color(0xFFEAF4FB),
        accent: Color(0xFF3E9DCB),
      ),
    _ => const _CategoryPalette(
        background: Color(0xFFF1F3F5),
        accent: Color(0xFF7A8790),
      ),
  };
}

final class _CategoryPalette {
  const _CategoryPalette({required this.background, required this.accent});

  final Color background;
  final Color accent;
}
