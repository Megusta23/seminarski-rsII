import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/encrypted_video_payload.dart';

void main() {
  testWidgets(
      'encrypted video stays unavailable until authenticated bytes are loaded',
      (WidgetTester tester) async {
    final Completer<Uint8List> load = Completer<Uint8List>();
    final _FakeVideoController controller = _FakeVideoController(
      decodedDuration: const Duration(seconds: 4),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncryptedVideoPayload(
            message: _message,
            load: (ChatMessage message, {bool forceReload = false}) =>
                load.future,
            errorText: (Object error) => error.toString(),
            controllerFactory: (String path) {
              expect(path, '/tmp/ladder-social-test-video.mp4');
              return controller;
            },
            materializer: _materializeForTest,
          ),
        ),
      ),
    );

    expect(
      find.text('Downloading and authenticating encrypted video...'),
      findsOneWidget,
    );
    expect(find.byTooltip('Play video'), findsNothing);
    expect(find.byKey(const Key('fake-video-surface')), findsNothing);

    load.complete(_mp4Bytes('authenticated video'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Play video'), findsOneWidget);
    expect(find.byKey(const Key('fake-video-surface')), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);

    await tester.tap(find.byTooltip('Play video'));
    await tester.pump();
    expect(controller.playCalls, 1);
    expect(find.byTooltip('Pause video'), findsOneWidget);

    controller.updatePosition(const Duration(milliseconds: 2100));
    await tester.pump();
    expect(find.text('0:02'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pump();
    expect(controller.seekPositions, isNotEmpty);

    await tester.tap(find.byTooltip('Pause video'));
    await tester.pump();
    expect(controller.pauseCalls, 1);
  });

  testWidgets('encrypted video failure exposes retry and reloads ciphertext',
      (WidgetTester tester) async {
    var calls = 0;
    final _FakeVideoController controller = _FakeVideoController(
      decodedDuration: const Duration(seconds: 4),
    );

    Future<Uint8List> loader(
      ChatMessage message, {
      bool forceReload = false,
    }) async {
      calls += 1;
      if (calls == 1) {
        throw const E2EAuthenticationException(
          'Encrypted video authentication failed.',
        );
      }
      expect(forceReload, isTrue);
      return _mp4Bytes('retry video');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncryptedVideoPayload(
            message: _message,
            load: loader,
            errorText: (Object error) => error.toString(),
            controllerFactory: (_) => controller,
            materializer: _materializeForTest,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Encrypted video authentication failed.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byTooltip('Play video'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byTooltip('Play video'), findsOneWidget);
  });

  testWidgets('decoded video duration mismatch is rejected before playback',
      (WidgetTester tester) async {
    final _FakeVideoController controller = _FakeVideoController(
      decodedDuration: const Duration(seconds: 8),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EncryptedVideoPayload(
            message: _message,
            load: (ChatMessage message, {bool forceReload = false}) async =>
                _mp4Bytes('duration mismatch'),
            errorText: (Object error) => error.toString(),
            controllerFactory: (_) => controller,
            materializer: _materializeForTest,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The decoded video duration does not match authenticated message metadata.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Play video'), findsNothing);
  });
}

Future<VideoMaterializedFile> _materializeForTest(
  Uint8List bytes,
  E2EVideoFormat format,
  String identity,
) async {
  expect(bytes, isNotEmpty);
  expect(format, E2EVideoFormat.mp4);
  expect(identity, _message.id);
  return const VideoMaterializedFile(
    path: '/tmp/ladder-social-test-video.mp4',
    deleteWhenDone: false,
  );
}

final ChatMessage _message = ChatMessage(
  id: 'video-message',
  conversationId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  senderUserId: '11111111-1111-1111-1111-111111111111',
  senderDisplayName: 'Alice',
  type: MessageType.video,
  sentAtUtc: DateTime.utc(2026, 9, 9),
  encryptionVersion: ChatEncryptionVersion.clientE2E,
  keyVersion: 1,
  attachmentId: '00000000-0000-0000-0000-000000000005',
  attachmentUrl:
      '/api/media/message-attachments/00000000-0000-0000-0000-000000000005',
  attachmentMimeType: E2ECryptoConstants.encryptedMediaContentType,
  attachmentNonce: List<int>.filled(E2ECryptoConstants.nonceBytes, 5),
  attachmentEncryptionVersion: ChatEncryptionVersion.clientE2E,
  attachmentKeyVersion: 1,
  attachmentSizeBytes: 128,
  attachmentDurationMilliseconds: 4000,
);

Uint8List _mp4Bytes(String marker) => Uint8List.fromList(<int>[
      0x00,
      0x00,
      0x00,
      0x18,
      0x66,
      0x74,
      0x79,
      0x70,
      0x69,
      0x73,
      0x6f,
      0x6d,
      0x00,
      0x00,
      0x00,
      0x00,
      ...utf8.encode(marker),
    ]);

final class _FakeVideoController implements VideoPlaybackController {
  _FakeVideoController({required Duration decodedDuration})
      : _snapshot = VideoPlaybackSnapshot(
          isInitialized: false,
          isPlaying: false,
          isBuffering: false,
          position: Duration.zero,
          duration: decodedDuration,
          aspectRatio: 16 / 9,
        );

  final List<VoidCallback> _listeners = <VoidCallback>[];
  final List<Duration> seekPositions = <Duration>[];
  VideoPlaybackSnapshot _snapshot;
  int playCalls = 0;
  int pauseCalls = 0;
  int initializeCalls = 0;
  bool disposed = false;

  @override
  VideoPlaybackSnapshot get snapshot => _snapshot;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  Widget buildVideo() => const SizedBox(
        key: Key('fake-video-surface'),
        width: 160,
        height: 90,
      );

  @override
  Future<void> dispose() async {
    disposed = true;
    _listeners.clear();
  }

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    _snapshot = _copySnapshot(isInitialized: true);
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    _snapshot = _copySnapshot(isPlaying: false);
    _notify();
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    _snapshot = _copySnapshot(isPlaying: true);
    _notify();
  }

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    _snapshot = _copySnapshot(position: position);
    _notify();
  }

  void updatePosition(Duration position) {
    _snapshot = _copySnapshot(position: position);
    _notify();
  }

  VideoPlaybackSnapshot _copySnapshot({
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
  }) =>
      VideoPlaybackSnapshot(
        isInitialized: isInitialized ?? _snapshot.isInitialized,
        isPlaying: isPlaying ?? _snapshot.isPlaying,
        isBuffering: isBuffering ?? _snapshot.isBuffering,
        position: position ?? _snapshot.position,
        duration: _snapshot.duration,
        aspectRatio: _snapshot.aspectRatio,
        errorDescription: _snapshot.errorDescription,
      );

  void _notify() {
    for (final VoidCallback listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}
