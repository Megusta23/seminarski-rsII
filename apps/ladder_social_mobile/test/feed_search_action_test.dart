import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_mobile/src/features/feed/presentation/feed_search_action.dart';

void main() {
  testWidgets('app-bar feed search applies and clears the active query', (
    WidgetTester tester,
  ) async {
    final FeedSearchController controller = FeedSearchController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Feed'),
            actions: <Widget>[
              const IconButton(onPressed: null, icon: Icon(Icons.chat_bubble_outline)),
              FeedSearchAction(controller: controller),
              const IconButton(onPressed: null, icon: Icon(Icons.notifications_outlined)),
            ],
          ),
        ),
      ),
    );

    final double chatX = tester
        .getCenter(find.byIcon(Icons.chat_bubble_outline))
        .dx;
    final double searchX = tester.getCenter(find.byIcon(Icons.search)).dx;
    final double notificationsX = tester
        .getCenter(find.byIcon(Icons.notifications_outlined))
        .dx;

    expect(chatX, lessThan(searchX));
    expect(searchX, lessThan(notificationsX));
    expect(find.byTooltip('Search feed'), findsOneWidget);
    await tester.tap(find.byTooltip('Search feed'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Faruk');
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    expect(controller.value, 'Faruk');
    expect(find.byTooltip('Search feed: Faruk'), findsOneWidget);

    await tester.tap(find.byTooltip('Search feed: Faruk'));
    await tester.pumpAndSettle();
    expect(find.text('Faruk'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(controller.value, isEmpty);
    expect(find.byTooltip('Search feed'), findsOneWidget);
  });
}
