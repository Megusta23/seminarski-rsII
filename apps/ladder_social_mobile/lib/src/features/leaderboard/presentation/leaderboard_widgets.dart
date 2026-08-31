import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

enum LeaderboardPeriod { daily, weekly }

extension LeaderboardPeriodPresentation on LeaderboardPeriod {
  String get label => switch (this) {
        LeaderboardPeriod.daily => 'Today',
        LeaderboardPeriod.weekly => 'This week',
      };

  IconData get icon => switch (this) {
        LeaderboardPeriod.daily => Icons.today_outlined,
        LeaderboardPeriod.weekly => Icons.date_range_outlined,
      };
}

const Color leaderboardCurrentUserColor = Color(0xFF3498DB);
const Color _leaderboardGold = Color(0xFFF2C94C);
const Color _leaderboardSilver = Color(0xFFB8C2CC);
const Color _leaderboardBronze = Color(0xFFD79A62);

final class LeaderboardBody extends StatelessWidget {
  const LeaderboardBody({
    required this.result,
    required this.period,
    required this.onPeriodChanged,
    required this.onOpenEntry,
    super.key,
  });

  final LeaderboardResult result;
  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardPeriod> onPeriodChanged;
  final ValueChanged<LeaderboardEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final List<LeaderboardEntry> entries = result.entries.toList()
      ..sort(
        (LeaderboardEntry left, LeaderboardEntry right) =>
            left.position.compareTo(right.position),
      );
    final bool hasCompletedTasks =
        entries.any((LeaderboardEntry entry) => entry.score > 0);
    final List<LeaderboardEntry> podiumEntries = entries
        .where((LeaderboardEntry entry) => entry.position <= 3)
        .toList(growable: false);
    final List<LeaderboardEntry> rankedEntries = entries
        .where((LeaderboardEntry entry) => entry.position > 3)
        .toList(growable: false);
    final LeaderboardEntry? currentUser = result.currentUser;
    final bool currentUserIsVisible = currentUser == null ||
        entries.any(
          (LeaderboardEntry entry) => entry.userId == currentUser.userId,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LeaderboardPeriodHeader(
          period: period,
          fromDate: result.fromDate,
          toDate: result.toDate,
          onChanged: onPeriodChanged,
        ),
        const SizedBox(height: 18),
        if (!hasCompletedTasks)
          const EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'No completed tasks yet',
            message: 'Complete a task today to start the competition.',
          )
        else ...<Widget>[
          LeaderboardPodium(
            entries: podiumEntries,
            onOpenEntry: onOpenEntry,
          ),
          if (rankedEntries.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            LeaderboardRankList(
              entries: rankedEntries,
              onOpenEntry: onOpenEntry,
            ),
          ],
          if (!currentUserIsVisible) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Your position',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            LeaderboardRankRow(
              entry: currentUser,
              onTap: () => onOpenEntry(currentUser),
              isPinned: true,
            ),
          ],
        ],
      ],
    );
  }
}

final class LeaderboardPeriodHeader extends StatelessWidget {
  const LeaderboardPeriodHeader({
    required this.period,
    required this.fromDate,
    required this.toDate,
    required this.onChanged,
    super.key,
  });

  final LeaderboardPeriod period;
  final DateTime fromDate;
  final DateTime toDate;
  final ValueChanged<LeaderboardPeriod> onChanged;

  String get _dateLabel => fromDate.year == toDate.year &&
          fromDate.month == toDate.month &&
          fromDate.day == toDate.day
      ? formatDate(fromDate)
      : '${formatDate(fromDate)} – ${formatDate(toDate)}';

  @override
  Widget build(BuildContext context) {
    final Widget summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          period.label,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          _dateLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
    final Widget selector = SegmentedButton<LeaderboardPeriod>(
      key: const Key('leaderboard-period-selector'),
      showSelectedIcon: false,
      segments: LeaderboardPeriod.values
          .map(
            (LeaderboardPeriod value) => ButtonSegment<LeaderboardPeriod>(
              value: value,
              icon: Icon(value.icon, size: 18),
              label: Text(
                value == LeaderboardPeriod.daily ? 'Today' : 'Week',
              ),
            ),
          )
          .toList(growable: false),
      selected: <LeaderboardPeriod>{period},
      onSelectionChanged: (Set<LeaderboardPeriod> values) {
        onChanged(values.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: -2, vertical: -2),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 350) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              summary,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: selector),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: summary),
            const SizedBox(width: 12),
            selector,
          ],
        );
      },
    );
  }
}

final class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    required this.entries,
    required this.onOpenEntry,
    super.key,
  });

  final List<LeaderboardEntry> entries;
  final ValueChanged<LeaderboardEntry> onOpenEntry;

  LeaderboardEntry? _entryAt(int position) {
    for (final LeaderboardEntry entry in entries) {
      if (entry.position == position) {
        return entry;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final LeaderboardEntry? first = _entryAt(1);
    final LeaderboardEntry? second = _entryAt(2);
    final LeaderboardEntry? third = _entryAt(3);

    return Semantics(
      label: 'Top three leaderboard positions',
      child: SizedBox(
        key: const Key('leaderboard-podium'),
        height: 276,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _PodiumSlot(
                entry: second,
                onOpenEntry: onOpenEntry,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PodiumSlot(
                entry: first,
                onOpenEntry: onOpenEntry,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PodiumSlot(
                entry: third,
                onOpenEntry: onOpenEntry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.onOpenEntry,
  });

  final LeaderboardEntry? entry;
  final ValueChanged<LeaderboardEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final LeaderboardEntry? value = entry;
    if (value == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: LeaderboardPodiumPlace(
        entry: value,
        onTap: () => onOpenEntry(value),
      ),
    );
  }
}

final class LeaderboardPodiumPlace extends StatelessWidget {
  const LeaderboardPodiumPlace({
    required this.entry,
    required this.onTap,
    super.key,
  });

  final LeaderboardEntry entry;
  final VoidCallback onTap;

  Color get _rankColor => switch (entry.position) {
        1 => _leaderboardGold,
        2 => _leaderboardSilver,
        _ => _leaderboardBronze,
      };

  @override
  Widget build(BuildContext context) {
    final bool firstPlace = entry.position == 1;
    final double avatarRadius = firstPlace ? 36 : 30;
    final Color rankColor = _rankColor;
    final String semanticsLabel =
        '${_ordinal(entry.position)} place, ${entry.displayName}, '
        '${entry.score} completed ${entry.score == 1 ? 'task' : 'tasks'}'
        '${entry.isCurrentUser ? ', current user' : ''}';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('leaderboard-podium-${entry.position}'),
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            height: firstPlace ? 268 : 216,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (firstPlace) ...<Widget>[
                    Icon(
                      Icons.emoji_events,
                      size: 30,
                      color: _leaderboardGold,
                    ),
                    const SizedBox(height: 3),
                  ],
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: entry.isCurrentUser
                                ? leaderboardCurrentUserColor
                                : rankColor,
                            width: entry.isCurrentUser ? 4 : 3,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: rankColor.withValues(alpha: 0.22),
                              blurRadius: firstPlace ? 16 : 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: UserAvatar(
                            displayName: entry.displayName,
                            avatarUrl: entry.avatarUrl,
                            radius: avatarRadius,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -11,
                        child: Container(
                          width: firstPlace ? 31 : 28,
                          height: firstPlace ? 31 : 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: rankColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 3,
                            ),
                          ),
                          child: Text(
                            '${entry.position}',
                            style: TextStyle(
                              color: entry.position == 2
                                  ? const Color(0xFF334155)
                                  : const Color(0xFF4B3510),
                              fontWeight: FontWeight.w900,
                              fontSize: firstPlace ? 14 : 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    entry.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                  ),
                  if (entry.isCurrentUser) ...<Widget>[
                    const SizedBox(height: 5),
                    const _YouBadge(compact: true),
                  ] else
                    const SizedBox(height: 20),
                  const SizedBox(height: 7),
                  Container(
                    key: Key('leaderboard-podium-score-${entry.position}'),
                    constraints: BoxConstraints(
                      minWidth: firstPlace ? 82 : 70,
                      minHeight: firstPlace ? 54 : 46,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: firstPlace ? 15 : 12,
                      vertical: firstPlace ? 10 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: entry.isCurrentUser
                            ? leaderboardCurrentUserColor
                            : rankColor,
                        width: firstPlace ? 2.4 : 1.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${entry.score}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.done_all,
                          size: firstPlace ? 19 : 17,
                          color: rankColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class LeaderboardRankList extends StatelessWidget {
  const LeaderboardRankList({
    required this.entries,
    required this.onOpenEntry,
    super.key,
  });

  final List<LeaderboardEntry> entries;
  final ValueChanged<LeaderboardEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('leaderboard-ranked-list'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: <Widget>[
            for (int index = 0; index < entries.length; index++) ...<Widget>[
              LeaderboardRankRow(
                entry: entries[index],
                onTap: () => onOpenEntry(entries[index]),
              ),
              if (index != entries.length - 1)
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

final class LeaderboardRankRow extends StatelessWidget {
  const LeaderboardRankRow({
    required this.entry,
    required this.onTap,
    this.isPinned = false,
    super.key,
  });

  final LeaderboardEntry entry;
  final VoidCallback onTap;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final bool current = entry.isCurrentUser;
    final Color foreground =
        current ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final String semanticsLabel =
        'Rank ${entry.position}, ${entry.displayName}, '
        '${entry.score} completed ${entry.score == 1 ? 'task' : 'tasks'}'
        '${current ? ', current user' : ''}';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        key: Key('leaderboard-row-${entry.userId}'),
        color: current
            ? leaderboardCurrentUserColor
            : Theme.of(context).colorScheme.surface,
        borderRadius: isPinned ? BorderRadius.circular(14) : BorderRadius.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${entry.position}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: current
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.85),
                              width: 2,
                            )
                          : null,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(current ? 2 : 0),
                      child: UserAvatar(
                        displayName: entry.displayName,
                        avatarUrl: entry.avatarUrl,
                        radius: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            entry.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: foreground,
                                      fontWeight: current
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                          ),
                        ),
                        if (current) ...<Widget>[
                          const SizedBox(width: 7),
                          const _YouBadge(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.score}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.done_all,
                    size: 19,
                    color: current
                        ? Colors.white
                        : Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _YouBadge extends StatelessWidget {
  const _YouBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('leaderboard-you-badge'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'You',
        style: TextStyle(
          color: leaderboardCurrentUserColor,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

final class LeaderboardLoadingBody extends StatelessWidget {
  const LeaderboardLoadingBody({
    required this.period,
    required this.onPeriodChanged,
    super.key,
  });

  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final DateTime now = utcBusinessDate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LeaderboardPeriodHeader(
          period: period,
          fromDate: now,
          toDate: now,
          onChanged: onPeriodChanged,
        ),
        const SizedBox(height: 24),
        const SizedBox(
          height: 210,
          child: Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 16),
        for (int index = 0; index < 4; index++) ...<Widget>[
          Container(
            height: 62,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

String _ordinal(int position) => switch (position) {
      1 => 'First',
      2 => 'Second',
      3 => 'Third',
      _ => 'Rank $position',
    };
