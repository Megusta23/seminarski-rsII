import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_screen_controller.dart';
import 'package:ladder_social_mobile/src/features/friends/presentation/friends_search_action.dart';

void main() {
  testWidgets('friends search sits between chat and notifications and opens search', (
    WidgetTester tester,
  ) async {
    final FriendsScreenController controller = FriendsScreenController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Friends'),
              actions: <Widget>[
                const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.chat_bubble_outline),
                ),
                FriendsSearchAction(controller: controller),
                const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.notifications_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final double chatX =
        tester.getCenter(find.byIcon(Icons.chat_bubble_outline)).dx;
    final double searchX =
        tester.getCenter(find.byIcon(Icons.person_search_outlined)).dx;
    final double notificationsX =
        tester.getCenter(find.byIcon(Icons.notifications_outlined)).dx;

    expect(chatX, lessThan(searchX));
    expect(searchX, lessThan(notificationsX));

    await tester.tap(find.byTooltip('Search people'));
    await tester.pumpAndSettle();

    expect(find.text('Search people'), findsOneWidget);
    expect(find.byKey(const Key('people-search-field')), findsOneWidget);
    expect(find.text('Find people you know'), findsOneWidget);
  });
}
