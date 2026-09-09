import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/encrypted_voice_payload.dart';

void main() {
  testWidgets(
      'encrypted voice stays unavailable until authenticated bytes are loaded',
      (WidgetTester tester) async {
    final Completer<Uint8List> load = Completer<Uint8List>();
    final _FakeVoicePlayer player = _FakeVoicePlayer(
      decodedDuration: const Duration(seconds: 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncryptedVoicePayload(
            message: _message,
            load: (ChatMessage message, {bool forceReload = false}) =>
                load.future,
            errorText: (Object error) => error.toString(),
            playerFactory: () => player,
            materializer: _materializeForTest,
          ),
        ),
      ),
    );

    expect(
      find.text('Downloading and authenticating encrypted voice...'),
      findsOneWidget,
    );
    expect(find.byTooltip('Play voice message'), findsNothing);

    load.complete(_m4aBytes('authenticated voice'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Play voice message'), findsOneWidget);
    expect(find.text('0:02'), findsOneWidget);

    await tester.tap(find.byTooltip('Play voice message'));
    await tester.pump();
    expect(player.playCalls, 1);
    expect(find.byTooltip('Pause voice message'), findsOneWidget);

    player.positionController.add(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(find.text('0:01'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause voice message'));
    await tester.pump();
    expect(player.pauseCalls, 1);

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();
    expect(player.seekPositions, isNotEmpty);
  });

  testWidgets('encrypted voice failure exposes retry and reloads ciphertext',
      (WidgetTester tester) async {
    var calls = 0;
    final _FakeVoicePlayer player = _FakeVoicePlayer(
      decodedDuration: const Duration(seconds: 2),
    );

    Future<Uint8List> loader(
      ChatMessage message, {
      bool forceReload = false,
    }) async {
      calls += 1;
      if (calls == 1) {
        throw const E2EAuthenticationException(
          'Encrypted voice authentication failed.',
        );
      }
      expect(forceReload, isTrue);
      return _m4aBytes('retry voice');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncryptedVoicePayload(
            message: _message,
            load: loader,
            errorText: (Object error) => error.toString(),
            playerFactory: () => player,
            materializer: _materializeForTest,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Encrypted voice authentication failed.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Play voice message'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byTooltip('Play voice message'), findsOneWidget);
  });

  testWidgets('decoded duration mismatch is rejected before playback',
      (WidgetTester tester) async {
    final _FakeVoicePlayer player = _FakeVoicePlayer(
      decodedDuration: const Duration(seconds: 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncryptedVoicePayload(
            message: _message,
            load: (ChatMessage message, {bool forceReload = false}) async =>
                _m4aBytes('duration mismatch'),
            errorText: (Object error) => error.toString(),
            playerFactory: () => player,
            materializer: _materializeForTest,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The decoded voice duration does not match authenticated message metadata.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Play voice message'), findsNothing);
  });
}

Future<VoiceMaterializedFile> _materializeForTest(
  Uint8List bytes,
  E2EVoiceFormat format,
  String identity,
) async {
  expect(bytes, isNotEmpty);
  expect(format, E2EVoiceFormat.m4a);
  expect(identity, _message.id);
  return const VoiceMaterializedFile(
    path: '/tmp/ladder-social-test-voice.m4a',
    deleteWhenDone: false,
  );
}

final ChatMessage _message = ChatMessage(
  id: 'voice-message',
  conversationId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  senderUserId: '11111111-1111-1111-1111-111111111111',
  senderDisplayName: 'Alice',
  type: MessageType.voice,
  sentAtUtc: DateTime.utc(2026, 9, 9),
  encryptionVersion: ChatEncryptionVersion.clientE2E,
  keyVersion: 1,
  attachmentId: '00000000-0000-0000-0000-000000000004',
  attachmentUrl:
      '/api/media/message-attachments/00000000-0000-0000-0000-000000000004',
  attachmentMimeType: E2ECryptoConstants.encryptedMediaContentType,
  attachmentNonce: List<int>.filled(E2ECryptoConstants.nonceBytes, 4),
  attachmentEncryptionVersion: ChatEncryptionVersion.clientE2E,
  attachmentKeyVersion: 1,
  attachmentSizeBytes: 96,
  attachmentDurationMilliseconds: 2000,
);

Uint8List _m4aBytes(String marker) => Uint8List.fromList(<int>[
      0x00,
      0x00,
      0x00,
      0x18,
      0x66,
      0x74,
      0x79,
      0x70,
      0x4d,
      0x34,
      0x41,
      0x20,
      0x00,
      0x00,
      0x00,
      0x00,
      ...utf8.encode(marker),
    ]);

final class _FakeVoicePlayer implements VoiceAudioPlayer {
  _FakeVoicePlayer({required this.decodedDuration});

  final Duration? decodedDuration;
  final StreamController<Duration> positionController =
      StreamController<Duration>.broadcast();
  final StreamController<VoicePlayerSnapshot> stateController =
      StreamController<VoicePlayerSnapshot>.broadcast();
  final StreamController<Object> errorController =
      StreamController<Object>.broadcast();
  final List<Duration> seekPositions = <Duration>[];
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Stream<Object> get errorStream => errorController.stream;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<VoicePlayerSnapshot> get stateStream => stateController.stream;

  @override
  Future<void> dispose() async {
    await positionController.close();
    await stateController.close();
    await errorController.close();
  }

  @override
  Future<Duration?> loadFile(String path) async {
    expect(path, '/tmp/ladder-social-test-voice.m4a');
    return decodedDuration;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    stateController.add(
      const VoicePlayerSnapshot(
        isPlaying: false,
        isLoading: false,
        isCompleted: false,
      ),
    );
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    stateController.add(
      const VoicePlayerSnapshot(
        isPlaying: true,
        isLoading: false,
        isCompleted: false,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    positionController.add(position);
  }

  @override
  Future<void> stop() async {
    stateController.add(
      const VoicePlayerSnapshot(
        isPlaying: false,
        isLoading: false,
        isCompleted: false,
      ),
    );
  }
}
