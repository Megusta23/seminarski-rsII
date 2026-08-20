import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

final class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _weekly = false;
  Future<LeaderboardResult>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      final LeaderboardRepository repository = ref.read(leaderboardRepositoryProvider);
      _future = _weekly ? repository.getWeekly() : repository.getDaily();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: false, label: Text('Daily'), icon: Icon(Icons.today)),
              ButtonSegment<bool>(value: true, label: Text('Weekly'), icon: Icon(Icons.date_range)),
            ],
            selected: <bool>{_weekly},
            onSelectionChanged: (Set<bool> value) {
              setState(() => _weekly = value.first);
              _load();
            },
          ),
          const SizedBox(height: 18),
          FutureBuilder<LeaderboardResult>(
            future: _future,
            builder: (BuildContext context, AsyncSnapshot<LeaderboardResult> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return AppErrorView(error: snapshot.error!, onRetry: _load);
              }
              final LeaderboardResult result = snapshot.data!;
              return Column(
                children: <Widget>[
                  Text(
                    '${formatDate(result.fromDate)} – ${formatDate(result.toDate)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  if (result.entries.isEmpty)
                    const EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'No scores yet',
                      message: 'Complete tasks to enter the leaderboard.',
                    )
                  else ...<Widget>[
                    _Podium(entries: result.entries.take(3).toList(growable: false)),
                    const SizedBox(height: 16),
                    ...result.entries.map(
                      (LeaderboardEntry entry) => Card(
                        color: entry.isCurrentUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${entry.position}')),
                          title: Text(entry.displayName),
                          subtitle: entry.isCurrentUser ? const Text('You') : null,
                          trailing: Text(
                            '${entry.score} pts',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

final class _Podium extends StatelessWidget {
  const _Podium({required this.entries});
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: entries
              .map((LeaderboardEntry entry) => Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          entry.position == 1
                              ? Icons.emoji_events
                              : Icons.workspace_premium_outlined,
                          size: entry.position == 1 ? 42 : 32,
                          color: entry.position == 1 ? Colors.amber.shade700 : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        Text('${entry.score} pts'),
                      ],
                    ),
                  ))
              .toList(growable: false),
        ),
      ),
    );
  }
}
