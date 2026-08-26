import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_screen_controller.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_widgets.dart';

void main() {
  testWidgets('friends tabs show an incoming request badge', (
    WidgetTester tester,
  ) async {
    FriendsSection selected = FriendsSection.friends;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendsTabSwitcher(
            selected: selected,
            requestCount: 3,
            onSelected: (FriendsSection value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('friends-section-requests')));
    expect(selected, FriendsSection.requests);
  });

  testWidgets('friend card uses profile, mutual, streak and task information', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    bool opened = false;
    bool messaged = false;
    bool removed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FriendCard(
              friend: const FriendSummary(
                userId: 'friend-1',
                displayName: 'Faruk Chaluk',
                mutualFriendCount: 4,
                completedTaskCount: 46,
                currentStreak: 12,
              ),
              onOpenProfile: () => opened = true,
              onMessage: () => messaged = true,
              onRemove: () => removed = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Faruk Chaluk'), findsOneWidget);
    expect(find.text('4 mutual friends'), findsOneWidget);
    expect(find.text('12 day streak'), findsOneWidget);
    expect(find.text('46 completed'), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-friend-friend-1')));
    expect(opened, isTrue);
    await tester.tap(find.byKey(const Key('message-friend-friend-1')));
    expect(messaged, isTrue);

    await tester.tap(find.byTooltip('Friend actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove friend'));
    expect(removed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incoming request actions are disabled while processing', (
    WidgetTester tester,
  ) async {
    final FriendRequestItem request = FriendRequestItem(
      id: 'request-1',
      senderUserId: 'sender-1',
      senderDisplayName: 'Ajdin Hajdarevic',
      receiverUserId: 'current-user',
      receiverDisplayName: 'Hasan Brkic',
      status: FriendRequestStatus.pending,
      createdAtUtc: DateTime.now().toUtc(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: IncomingFriendRequestCard(
              request: request,
              isProcessing: true,
              onAccept: () {},
              onReject: () {},
            ),
          ),
        ),
      ),
    );

    final FilledButton accept = tester.widget<FilledButton>(
      find.byKey(const Key('accept-request-request-1')),
    );
    final OutlinedButton decline = tester.widget<OutlinedButton>(
      find.byKey(const Key('reject-request-request-1')),
    );

    expect(accept.onPressed, isNull);
    expect(decline.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('people search presents relationship-aware actions', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final List<UserSearchItem> items = <UserSearchItem>[
      const UserSearchItem(
        userId: 'friend',
        displayName: 'Existing Friend',
        email: 'friend@example.com',
        isFriend: true,
        hasOutgoingPendingRequest: false,
        hasIncomingPendingRequest: false,
        mutualFriendCount: 2,
      ),
      const UserSearchItem(
        userId: 'incoming',
        displayName: 'Incoming Person',
        email: 'incoming@example.com',
        isFriend: false,
        hasOutgoingPendingRequest: false,
        hasIncomingPendingRequest: true,
        mutualFriendCount: 1,
        incomingRequestId: 'incoming-request',
      ),
      const UserSearchItem(
        userId: 'outgoing',
        displayName: 'Outgoing Person',
        email: 'outgoing@example.com',
        isFriend: false,
        hasOutgoingPendingRequest: true,
        hasIncomingPendingRequest: false,
        mutualFriendCount: 0,
        outgoingRequestId: 'outgoing-request',
      ),
      const UserSearchItem(
        userId: 'new',
        displayName: 'New Person',
        email: 'new@example.com',
        isFriend: false,
        hasOutgoingPendingRequest: false,
        hasIncomingPendingRequest: false,
        mutualFriendCount: 3,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: items
                .map(
                  (UserSearchItem item) => PeopleSearchResultCard(
                    item: item,
                    onPrimaryAction: () {},
                    onSecondaryAction: () {},
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('friend@example.com'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friend card remains responsive with larger text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(340, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(340, 900),
            textScaler: TextScaler.linear(1.25),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: FriendCard(
                friend: const FriendSummary(
                  userId: 'responsive',
                  displayName:
                      'A very long friend name that should remain readable',
                  mutualFriendCount: 18,
                  completedTaskCount: 1234,
                  currentStreak: 365,
                ),
                onOpenProfile: () {},
                onMessage: () {},
                onRemove: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('request and discover cards remain responsive with larger text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final FriendRequestItem outgoing = FriendRequestItem(
      id: 'outgoing-responsive',
      senderUserId: 'current-user',
      senderDisplayName: 'Current User',
      receiverUserId: 'receiver-responsive',
      receiverDisplayName:
          'A very long pending request name that must not overflow',
      status: FriendRequestStatus.pending,
      createdAtUtc: DateTime.utc(2026, 8, 26),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(12),
              children: <Widget>[
                OutgoingFriendRequestCard(
                  request: outgoing,
                  onCancel: () {},
                ),
                FriendSuggestionCard(
                  recommendation: const FriendRecommendation(
                    userId: 'recommendation-responsive',
                    displayName:
                        'A very long recommended person name for testing',
                    mutualFriendCount: 12,
                    explanation:
                        'Recommended because you share many mutual friends in your productivity network.',
                  ),
                  onAdd: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

}
