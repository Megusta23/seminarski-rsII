import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/feed/presentation/feed_widgets.dart';

void main() {
  test('relative feed time matches the compact document header', () {
    final DateTime now = DateTime.utc(2026, 8, 25, 12);

    expect(
      formatFeedRelativeTime(
        DateTime.utc(2026, 8, 25, 11, 58),
        now: now,
      ),
      '2 min ago',
    );
    expect(
      formatFeedRelativeTime(
        DateTime.utc(2026, 8, 25, 9),
        now: now,
      ),
      '3 h ago',
    );
  });

  testWidgets('friend feed card groups one friend and all shared tasks', (
    WidgetTester tester,
  ) async {
    const FriendProgress progress = FriendProgress(
      userId: 'friend-id',
      displayName: 'Faruk Chaluk',
      completedToday: 3,
      scheduledToday: 5,
      percentage: 60,
      currentStreak: 4,
    );
    final List<FeedPost> tasks = <FeedPost>[
      _post(
        FeedActivityType.completedWithProof,
        id: 'post-new',
        title: 'Evening mindfulness meditation',
        categoryCode: 'self-care',
        activityAtUtc: DateTime.utc(2026, 8, 25, 11, 58),
      ),
      _post(
        FeedActivityType.completedWithProof,
        id: 'post-viewed',
        title: 'Stretch for 10 minutes',
        categoryCode: 'self-care',
        viewed: true,
      ),
      _post(
        FeedActivityType.completedWithoutProof,
        id: 'post-no-proof',
        title: 'Call mom and catch up',
        categoryCode: 'social',
      ),
      _post(
        FeedActivityType.unfinished,
        id: 'task-unfinished',
        title: 'Finish quarterly report draft',
        categoryCode: 'work',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FriendFeedCard(
              progress: progress,
              tasks: tasks,
              now: DateTime.utc(2026, 8, 25, 12),
              onOpenFriend: _noop,
              onOpenTask: (_) {},
              onOpenProof: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Faruk Chaluk'), findsOneWidget);
    expect(find.text('2 min ago'), findsOneWidget);
    expect(find.text('Evening mindfulness meditation'), findsOneWidget);
    expect(find.text('Stretch for 10 minutes'), findsOneWidget);
    expect(find.text('Call mom and catch up'), findsOneWidget);
    expect(find.text('Finish quarterly report draft'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('tapping a task with proof opens the Snapchat-style proof flow', (
    WidgetTester tester,
  ) async {
    FeedPost? openedProof;
    FeedPost? openedDetails;
    final FeedPost proofTask = _post(
      FeedActivityType.completedWithProof,
      id: 'proof-post',
      title: 'Stretch for 10 minutes',
      categoryCode: 'self-care',
    );
    final FeedPost plainTask = _post(
      FeedActivityType.completedWithoutProof,
      id: 'plain-post',
      title: 'Read a chapter before bed',
      categoryCode: 'self-care',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendFeedCard(
            progress: _progress,
            tasks: <FeedPost>[proofTask, plainTask],
            onOpenFriend: _noop,
            onOpenTask: (FeedPost post) => openedDetails = post,
            onOpenProof: (FeedPost post) => openedProof = post,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Stretch for 10 minutes'));
    expect(openedProof?.id, 'proof-post');
    expect(openedDetails, isNull);

    await tester.tap(find.text('Read a chapter before bed'));
    expect(openedDetails?.id, 'plain-post');
  });

  testWidgets('task rail exposes all original checkbox meanings accessibly', (
    WidgetTester tester,
  ) async {
    final List<FeedPost> tasks = <FeedPost>[
      _post(
        FeedActivityType.completedWithProof,
        id: 'new-proof',
        title: 'New proof',
        categoryCode: 'self-care',
      ),
      _post(
        FeedActivityType.completedWithProof,
        id: 'viewed-proof',
        title: 'Viewed proof',
        categoryCode: 'social',
        viewed: true,
      ),
      _post(
        FeedActivityType.completedWithoutProof,
        id: 'no-proof',
        title: 'No proof',
        categoryCode: 'creative',
      ),
      _post(
        FeedActivityType.unfinished,
        id: 'unfinished',
        title: 'Unfinished',
        categoryCode: 'work',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendFeedCard(
            progress: _progress,
            tasks: tasks,
            onOpenFriend: _noop,
            onOpenTask: (_) {},
            onOpenProof: (_) {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Completed with a new proof image'), findsOneWidget);
    expect(find.byTooltip('Completed; proof image viewed'), findsOneWidget);
    expect(find.byTooltip('Completed without a proof image'), findsOneWidget);
    expect(find.byTooltip('Not completed'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(3));
  });

  testWidgets('feed status indicator remains available for task details', (
    WidgetTester tester,
  ) async {
    final List<FeedPost> posts = <FeedPost>[
      _post(FeedActivityType.unfinished, id: 'unfinished', title: 'Unfinished'),
      _post(
        FeedActivityType.completedWithoutProof,
        id: 'no-proof',
        title: 'No proof',
      ),
      _post(
        FeedActivityType.completedWithProof,
        id: 'new-proof',
        title: 'New proof',
      ),
      _post(
        FeedActivityType.completedWithProof,
        id: 'viewed-proof',
        title: 'Viewed proof',
        viewed: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: posts
                .map((FeedPost post) => FeedStatusIndicator(post: post))
                .toList(),
          ),
        ),
      ),
    );

    expect(find.text('Not completed'), findsOneWidget);
    expect(find.text('Completed · No proof'), findsOneWidget);
    expect(find.text('Completed · New proof'), findsOneWidget);
    expect(find.text('Completed · Proof viewed'), findsOneWidget);
  });
}

const FriendProgress _progress = FriendProgress(
  userId: 'friend-id',
  displayName: 'Faruk Chaluk',
  completedToday: 3,
  scheduledToday: 5,
  percentage: 60,
  currentStreak: 4,
);

void _noop() {}

FeedPost _post(
  FeedActivityType type, {
  required String id,
  required String title,
  String categoryCode = 'work',
  bool viewed = false,
  DateTime? activityAtUtc,
}) =>
    FeedPost(
      id: type == FeedActivityType.unfinished ? 'task-$id' : id,
      activityType: type,
      activityAtUtc: activityAtUtc ?? DateTime.utc(2026, 8, 25, 10),
      occurrenceDate: DateTime(2026, 8, 25),
      authorUserId: 'friend-id',
      authorDisplayName: 'Faruk Chaluk',
      taskId: 'task-$id',
      taskTitle: title,
      categoryName: switch (categoryCode) {
        'self-care' => 'Self-care',
        'social' => 'Social',
        'creative' => 'Creative',
        _ => 'Work',
      },
      categoryCode: categoryCode,
      recurrenceName: 'Daily',
      recurrenceCode: 'daily',
      caption: type == FeedActivityType.completedWithProof
          ? 'I finished this task today.'
          : null,
      hasBeenViewed: viewed,
      proofMediaId:
          type == FeedActivityType.completedWithProof ? 'proof-$id' : null,
      proofUrl: type == FeedActivityType.completedWithProof
          ? '/api/media/task-proofs/proof-$id'
          : null,
      viewedAtUtc: viewed ? DateTime.utc(2026, 8, 25, 11) : null,
    );
