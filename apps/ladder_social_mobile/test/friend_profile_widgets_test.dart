import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friend_profile_widgets.dart';

void main() {
  testWidgets('friend profile follows the document statistics and highlights', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    HighlightedPost? openedHighlight;
    var friendshipPressed = false;
    var messagePressed = false;
    var mutualFriendsOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendProfileBody(
            profile: _completeProfile,
            onMessage: () => messagePressed = true,
            onFriendship: () => friendshipPressed = true,
            onOpenMutualFriends: () => mutualFriendsOpened = true,
            onOpenMutualFriend: (_) {},
            onOpenHighlightedPost: (HighlightedPost post) =>
                openedHighlight = post,
            highlightThumbnailBuilder: (_, __) => const ColoredBox(
              color: Colors.blueGrey,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Faruk Chaluk'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('122'), findsOneWidget);
    expect(find.text('posts'), findsOneWidget);
    expect(find.text('friends'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.textContaining('Building better habits'), findsOneWidget);
    expect(find.text('Mutual friends:'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('Tasks completed'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('46'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.byKey(const Key('highlighted-posts-grid')), findsOneWidget);

    await tester.tap(find.byKey(const Key('friendship-button')));
    await tester.tap(find.byKey(const Key('message-button')));
    expect(friendshipPressed, isTrue);
    expect(messagePressed, isTrue);

    await tester.tap(find.byKey(const Key('mutual-friends-preview')));
    expect(mutualFriendsOpened, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const Key('highlight-post-post-id')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('highlight-post-post-id')));
    expect(openedHighlight?.postId, 'post-id');
  });

  testWidgets('friend profile presents polished empty states', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendProfileBody(
            profile: _emptyProfile,
            onMessage: null,
            onFriendship: () {},
            onOpenMutualFriends: null,
            onOpenMutualFriend: (_) {},
            onOpenHighlightedPost: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No biography added yet.'), findsOneWidget);
    expect(find.byKey(const Key('no-mutual-friends')), findsOneWidget);
    expect(find.byKey(const Key('empty-highlighted-posts')), findsOneWidget);
    expect(find.text('No highlighted tasks yet.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('message-button')))
          .onPressed,
      isNull,
    );
  });
}

final FriendProfile _completeProfile = FriendProfile(
  userId: 'friend-id',
  displayName: 'Faruk Chaluk',
  bio: 'Building better habits one day at a time.',
  avatarUrl: null,
  cityName: 'Mostar',
  memberSinceUtc: DateTime.utc(2026, 6, 15),
  visiblePostCount: 4,
  friendCount: 122,
  completedTaskCount: 46,
  habitCount: 3,
  currentStreak: 12,
  canMessage: true,
  mutualFriends: const MutualFriends(
    count: 3,
    items: <MutualFriend>[
      MutualFriend(
        userId: 'mutual-id',
        displayName: 'Ajdin',
      ),
    ],
  ),
  highlightedPosts: <HighlightedPost>[
    HighlightedPost(
      postId: 'post-id',
      taskId: 'task-id',
      taskTitle: 'Go for a hike',
      caption: 'A productive afternoon outside.',
      categoryName: 'Self-care',
      categoryCode: 'self-care',
      proofMediaId: 'proof-id',
      proofUrl: '/api/media/task-proofs/proof-id',
      completedAtUtc: DateTime.utc(2026, 8, 24, 16, 30),
      highlightedAtUtc: DateTime.utc(2026, 8, 25, 8),
    ),
  ],
);

final FriendProfile _emptyProfile = FriendProfile(
  userId: 'friend-id',
  displayName: 'Empty Profile',
  memberSinceUtc: DateTime.utc(2026, 8, 1),
  visiblePostCount: 0,
  friendCount: 1,
  completedTaskCount: 0,
  habitCount: 0,
  currentStreak: 0,
  canMessage: false,
  mutualFriends: const MutualFriends(count: 0, items: <MutualFriend>[]),
  highlightedPosts: const <HighlightedPost>[],
);
