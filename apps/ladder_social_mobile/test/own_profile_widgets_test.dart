import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/profile/presentation/own_profile_widgets.dart';
import 'package:ladder_social_mobile/src/features/profile/presentation/profile_settings_sheet.dart';

void main() {
  testWidgets('own profile follows the friend-profile visual language', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1150));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var avatarOpened = false;
    var postsOpened = false;
    var friendsOpened = false;
    HighlightedPost? openedHighlight;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnProfileBody(
            profile: _completeProfile,
            onOpenAvatar: () => avatarOpened = true,
            onOpenPosts: () => postsOpened = true,
            onOpenFriends: () => friendsOpened = true,
            onOpenHighlightedPost: (HighlightedPost post) {
              openedHighlight = post;
            },
            highlightThumbnailBuilder: (_, __) => const ColoredBox(
              color: Colors.blueGrey,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hasan Brkic'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Trying to improve every day.'), findsOneWidget);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.text('Change password'), findsNothing);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('Tasks completed'), findsOneWidget);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.byKey(const Key('own-profile-highlight-grid')), findsOneWidget);

    await tester.tap(find.byKey(const Key('own-profile-avatar')));
    await tester.tap(find.byKey(const Key('own-profile-post-count')));
    await tester.tap(find.byKey(const Key('own-profile-friend-count')));
    expect(avatarOpened, isTrue);
    expect(postsOpened, isTrue);
    expect(friendsOpened, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const Key('own-highlight-post-id')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('own-highlight-post-id')));
    expect(openedHighlight?.postId, 'post-id');
  });

  testWidgets('own profile presents polished empty states', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnProfileBody(
            profile: _emptyProfile,
            onOpenAvatar: () {},
            onOpenPosts: () {},
            onOpenFriends: () {},
            onOpenHighlightedPost: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.text('Add a biography from Profile settings.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('own-profile-empty-highlights')),
      findsOneWidget,
    );
    expect(find.text('No highlighted tasks yet.'), findsOneWidget);
    expect(find.text('Manage highlighted posts'), findsNothing);
  });

  testWidgets('profile settings action is the only top-right profile action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: const <Widget>[ProfileSettingsAction()],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.byKey(const Key('profile-settings-button')), findsOneWidget);
  });

  testWidgets('settings sheet contains only supported profile actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfileSettingsSheet(hasAvatar: true),
        ),
      ),
    );

    expect(find.text('Edit profile'), findsOneWidget);
    expect(find.text('Change profile picture'), findsOneWidget);
    expect(find.text('Remove profile picture'), findsOneWidget);
    expect(find.text('Manage highlighted posts'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Private account'), findsNothing);
  });

  testWidgets('own profile remains responsive with larger text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 900),
            textScaler: TextScaler.linear(1.35),
          ),
          child: Scaffold(
            body: OwnProfileBody(
              profile: _completeProfile,
              onOpenAvatar: () {},
              onOpenPosts: () {},
              onOpenFriends: () {},
              onOpenHighlightedPost: (_) {},
              highlightThumbnailBuilder: (_, __) => const ColoredBox(
                color: Colors.blueGrey,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

final OwnProfileOverview _completeProfile = OwnProfileOverview(
  userId: 'user-id',
  displayName: 'Hasan Brkic',
  bio: 'Trying to improve every day.',
  cityName: 'Mostar',
  memberSinceUtc: DateTime.utc(2026, 6, 1),
  visiblePostCount: 12,
  friendCount: 24,
  completedTaskCount: 54,
  habitCount: 4,
  currentStreak: 7,
  highlightedPosts: <HighlightedPost>[
    HighlightedPost(
      postId: 'post-id',
      taskId: 'task-id',
      taskTitle: 'Go for a hike',
      caption: 'Sunday morning outside.',
      categoryName: 'Self-care',
      categoryCode: 'self-care',
      proofMediaId: 'proof-id',
      proofUrl: '/api/media/task-proofs/proof-id',
      completedAtUtc: DateTime.utc(2026, 8, 25, 9, 30),
      highlightedAtUtc: DateTime.utc(2026, 8, 25, 10),
    ),
  ],
);

final OwnProfileOverview _emptyProfile = OwnProfileOverview(
  userId: 'user-id',
  displayName: 'Empty Profile',
  memberSinceUtc: DateTime.utc(2026, 8, 1),
  visiblePostCount: 0,
  friendCount: 0,
  completedTaskCount: 0,
  habitCount: 0,
  currentStreak: 0,
  highlightedPosts: const <HighlightedPost>[],
);
