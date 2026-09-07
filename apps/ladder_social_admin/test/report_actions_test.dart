import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_admin/src/features/reports/presentation/report_widgets.dart';

void main() {
  testWidgets('save and print are separate report actions', (
    WidgetTester tester,
  ) async {
    int saveCalls = 0;
    int printCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportActionButtons(
            onSave: () => saveCalls += 1,
            onPrint: () => printCalls += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save PDF'));
    await tester.pump();
    expect(saveCalls, 1);
    expect(printCalls, 0);

    await tester.tap(find.text('Print PDF'));
    await tester.pump();
    expect(saveCalls, 1);
    expect(printCalls, 1);
  });
}
