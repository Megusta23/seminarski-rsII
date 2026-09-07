import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

void main() {
  testWidgets('pagination footer exposes a working load-more action', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPaginationFooter(
            hasMore: true,
            isLoading: false,
            onLoadMore: () => calls += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Load more'));
    expect(calls, 1);
  });

  testWidgets('pagination footer shows progress while loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPaginationFooter(
            hasMore: true,
            isLoading: true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });
}
