import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/leaderboard/presentation/leaderboard_widgets.dart';

void main() {
  testWidgets('leaderboard follows podium order and highlights current user', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    LeaderboardEntry? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LeaderboardBody(
              result: _completeResult,
              period: LeaderboardPeriod.daily,
              onPeriodChanged: (_) {},
              onOpenEntry: (LeaderboardEntry entry) => opened = entry,
            ),
          ),
        ),
      ),
    );

    final double secondX =
        tester.getCenter(find.byKey(const Key('leaderboard-podium-2'))).dx;
    final double firstX =
        tester.getCenter(find.byKey(const Key('leaderboard-podium-1'))).dx;
    final double thirdX =
        tester.getCenter(find.byKey(const Key('leaderboard-podium-3'))).dx;

    expect(secondX, lessThan(firstX));
    expect(firstX, lessThan(thirdX));
    expect(find.byKey(const Key('leaderboard-ranked-list')), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Hasan Brkic'), findsOneWidget);

    await tester.tap(find.byKey(const Key('leaderboard-row-friend-four')));
    expect(opened?.userId, 'friend-four');

    await tester.tap(find.byKey(const Key('leaderboard-row-current-user')));
    expect(opened?.userId, 'current-user');
  });

  testWidgets('current user is identified on the podium', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final LeaderboardEntry current = _entry(
      position: 1,
      userId: 'current-user',
      name: 'Hasan Brkic',
      score: 12,
      current: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LeaderboardBody(
              result: LeaderboardResult(
                fromDate: DateTime(2026, 8, 25),
                toDate: DateTime(2026, 8, 25),
                entries: <LeaderboardEntry>[current],
                currentUser: current,
              ),
              period: LeaderboardPeriod.daily,
              onPeriodChanged: (_) {},
              onOpenEntry: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('leaderboard-podium-1')), findsOneWidget);
    expect(find.byKey(const Key('leaderboard-podium-2')), findsNothing);
    expect(find.byKey(const Key('leaderboard-podium-3')), findsNothing);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('leaderboard presents a useful zero-score state', (
    WidgetTester tester,
  ) async {
    final LeaderboardEntry current = _entry(
      position: 1,
      userId: 'current-user',
      name: 'Hasan Brkic',
      score: 0,
      current: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LeaderboardBody(
              result: LeaderboardResult(
                fromDate: DateTime(2026, 8, 25),
                toDate: DateTime(2026, 8, 25),
                entries: <LeaderboardEntry>[current],
                currentUser: current,
              ),
              period: LeaderboardPeriod.daily,
              onPeriodChanged: (_) {},
              onOpenEntry: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('No completed tasks yet'), findsOneWidget);
    expect(
      find.text('Complete a task today to start the competition.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('leaderboard-podium')), findsNothing);
  });

  testWidgets('period selector changes to weekly without layout overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(340, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    LeaderboardPeriod selected = LeaderboardPeriod.daily;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(340, 950),
            textScaler: TextScaler.linear(1.2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: LeaderboardBody(
                result: _completeResult,
                period: selected,
                onPeriodChanged: (LeaderboardPeriod value) => selected = value,
                onOpenEntry: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Week'));
    expect(selected, LeaderboardPeriod.weekly);
    expect(tester.takeException(), isNull);
  });
}

final LeaderboardResult _completeResult = LeaderboardResult(
  fromDate: DateTime(2026, 8, 25),
  toDate: DateTime(2026, 8, 25),
  entries: <LeaderboardEntry>[
    _entry(position: 1, userId: 'friend-one', name: 'Faruk Chaluk', score: 28),
    _entry(position: 2, userId: 'friend-two', name: 'Harun Cora', score: 24),
    _entry(position: 3, userId: 'friend-three', name: 'Edhem V.', score: 20),
    _entry(position: 4, userId: 'friend-four', name: 'Ajdin Islamovic', score: 19),
    _entry(
      position: 5,
      userId: 'current-user',
      name: 'Hasan Brkic',
      score: 18,
      current: true,
    ),
  ],
  currentUser: _entry(
    position: 5,
    userId: 'current-user',
    name: 'Hasan Brkic',
    score: 18,
    current: true,
  ),
);

LeaderboardEntry _entry({
  required int position,
  required String userId,
  required String name,
  required int score,
  bool current = false,
}) =>
    LeaderboardEntry(
      position: position,
      userId: userId,
      displayName: name,
      score: score,
      isCurrentUser: current,
    );
