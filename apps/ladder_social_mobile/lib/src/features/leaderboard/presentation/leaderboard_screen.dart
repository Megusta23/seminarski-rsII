import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friend_profile_screen.dart';
import 'package:ladder_social_mobile/src/features/leaderboard/presentation/leaderboard_widgets.dart';

final class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({required this.onOpenCurrentUser, super.key});

  final VoidCallback onOpenCurrentUser;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

final class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.daily;
  Future<LeaderboardResult>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _fetch(_period);
  }

  Future<LeaderboardResult> _fetch(LeaderboardPeriod period) {
    final LeaderboardRepository repository =
        ref.read(leaderboardRepositoryProvider);
    return period == LeaderboardPeriod.weekly
        ? repository.getWeekly()
        : repository.getDaily();
  }

  Future<void> _refresh() async {
    final Future<LeaderboardResult> future = _fetch(_period);
    setState(() => _future = future);
    await future;
  }

  void _changePeriod(LeaderboardPeriod period) {
    if (_period == period) {
      return;
    }
    setState(() {
      _period = period;
      _future = _fetch(period);
    });
  }

  Future<void> _openEntry(LeaderboardEntry entry) async {
    if (entry.isCurrentUser) {
      widget.onOpenCurrentUser();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(userId: entry.userId),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<LeaderboardResult>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<LeaderboardResult> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              children: <Widget>[
                LeaderboardLoadingBody(
                  period: _period,
                  onPeriodChanged: _changePeriod,
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
              children: <Widget>[
                LeaderboardPeriodHeader(
                  period: _period,
                  fromDate: DateTime.now(),
                  toDate: DateTime.now(),
                  onChanged: _changePeriod,
                ),
                const SizedBox(height: 36),
                AppErrorView(error: snapshot.error!, onRetry: _refresh),
              ],
            );
          }

          return ListView(
            key: const PageStorageKey<String>('leaderboard-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
            children: <Widget>[
              LeaderboardBody(
                result: snapshot.requireData,
                period: _period,
                onPeriodChanged: _changePeriod,
                onOpenEntry: _openEntry,
              ),
            ],
          );
        },
      ),
    );
  }
}
