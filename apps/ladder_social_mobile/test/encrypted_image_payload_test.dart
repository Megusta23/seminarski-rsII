import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/encrypted_image_payload.dart';

void main() {
  testWidgets('encrypted image is hidden until authenticated bytes arrive', (
    WidgetTester tester,
  ) async {
    final Completer<Uint8List> load = Completer<Uint8List>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncryptedImagePayload(
            message: _message,
            load: (ChatMessage message, {bool forceReload = false}) =>
                load.future,
            errorText: (Object error) => error.toString(),
          ),
        ),
      ),
    );

    expect(
      find.text('Downloading and authenticating encrypted image...'),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);

    load.complete(_transparentPng);
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(
      find.text('Downloading and authenticating encrypted image...'),
      findsNothing,
    );
  });

  testWidgets('encrypted image failure exposes retry and reloads ciphertext', (
    WidgetTester tester,
  ) async {
    var calls = 0;

    Future<Uint8List> loader(
      ChatMessage message, {
      bool forceReload = false,
    }) async {
      calls += 1;
      if (calls == 1) {
        throw const E2EAuthenticationException(
          'Encrypted image authentication failed.',
        );
      }
      expect(forceReload, isTrue);
      return _transparentPng;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncryptedImagePayload(
            message: _message,
            load: loader,
            errorText: (Object error) => error.toString(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Encrypted image authentication failed.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(Image), findsOneWidget);
  });
}

final ChatMessage _message = ChatMessage(
  id: 'image-message',
  conversationId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  senderUserId: '11111111-1111-1111-1111-111111111111',
  senderDisplayName: 'Alice',
  type: MessageType.image,
  sentAtUtc: DateTime.utc(2026, 9, 9),
  encryptionVersion: ChatEncryptionVersion.clientE2E,
  keyVersion: 1,
  attachmentId: '00000000-0000-0000-0000-000000000001',
  attachmentUrl:
      '/api/media/message-attachments/00000000-0000-0000-0000-000000000001',
  attachmentMimeType: E2ECryptoConstants.encryptedMediaContentType,
  attachmentNonce: List<int>.filled(E2ECryptoConstants.nonceBytes, 1),
  attachmentEncryptionVersion: ChatEncryptionVersion.clientE2E,
  attachmentKeyVersion: 1,
  attachmentSizeBytes: 84,
);

final Uint8List _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
