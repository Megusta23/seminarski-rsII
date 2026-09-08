import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/proof_capture_screen.dart';

void main() {
  testWidgets('proof flow follows the document layout and composer stages', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: ProofCaptureScreen()),
    );

    expect(find.text('Choose a layout for your photos'), findsOneWidget);
    expect(find.byType(ProofDocumentLayoutTile), findsNWidgets(5));

    await tester.tap(find.textContaining('Continue with'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('proof-gallery-action')), findsOneWidget);
    expect(find.byKey(const Key('proof-edit-action')), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.cameraswitch_outlined), findsNothing);
    expect(find.byTooltip('Use this proof'), findsOneWidget);
  });
}
