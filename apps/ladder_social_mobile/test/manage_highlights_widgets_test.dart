import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/profile/presentation/manage_highlights_screen.dart';

void main() {
  testWidgets('highlight candidate clearly shows add and selected states', (
    WidgetTester tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: ProfileHighlightCandidateCard(
              candidate: _candidate,
              onTap: () => taps++,
              thumbnail: const ColoredBox(color: Colors.blueGrey),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Finish the seminar'), findsOneWidget);
    await tester.tap(find.text('Finish the seminar'));
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: ProfileHighlightCandidateCard(
              candidate: _candidate.copyWithHighlighted(true),
              onTap: () => taps++,
              thumbnail: const ColoredBox(color: Colors.blueGrey),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('busy highlight candidate disables repeated taps', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 320,
            child: ProfileHighlightCandidateCard(
              candidate: _candidate,
              isBusy: true,
              onTap: () => taps++,
              thumbnail: const ColoredBox(color: Colors.blueGrey),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Finish the seminar'));
    expect(taps, 0);
  });
}

final ProfileHighlightCandidate _candidate = ProfileHighlightCandidate(
  postId: 'post-id',
  taskId: 'task-id',
  taskTitle: 'Finish the seminar',
  caption: 'All tests passed.',
  categoryName: 'Work',
  categoryCode: 'work',
  proofMediaId: 'proof-id',
  proofUrl: '/api/media/task-proofs/proof-id',
  completedAtUtc: DateTime.utc(2026, 8, 25, 12),
  isHighlighted: false,
);
