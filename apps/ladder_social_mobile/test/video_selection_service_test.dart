import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/chat/presentation/video_selection_service.dart';

void main() {
  test('camera or gallery video is validated before a draft is returned',
      () async {
    final Uint8List bytes = _mp4Bytes('selected video');
    ImageSource? capturedSource;
    Duration? capturedMaximum;
    E2EVideoFormat? capturedFormat;

    final VideoSelectionService service = VideoSelectionService(
      picker: ({required ImageSource source, Duration? maxDuration}) async {
        capturedSource = source;
        capturedMaximum = maxDuration;
        return XFile.fromData(bytes, name: 'selected.mp4');
      },
      durationProbe: (String path) async {
        expect(path, '/tmp/selected-video.mp4');
        return const Duration(milliseconds: 4200);
      },
      materializer: (Uint8List clearBytes, E2EVideoFormat format) async {
        expect(clearBytes, orderedEquals(bytes));
        capturedFormat = format;
        return '/tmp/selected-video.mp4';
      },
    );

    final VideoDraft? draft = await service.pick(source: ImageSource.camera);

    expect(capturedSource, ImageSource.camera);
    expect(
      capturedMaximum,
      const Duration(
        milliseconds: E2EVideoValidator.maximumDurationMilliseconds,
      ),
    );
    expect(capturedFormat, E2EVideoFormat.mp4);
    expect(draft, isNotNull);
    expect(draft!.bytes, orderedEquals(bytes));
    expect(draft.durationMilliseconds, 4200);
    expect(draft.format, E2EVideoFormat.mp4);
  });

  test('cancelled video picker creates no draft', () async {
    final VideoSelectionService service = VideoSelectionService(
      picker: ({required ImageSource source, Duration? maxDuration}) async =>
          null,
      durationProbe: (_) async => throw StateError('must not run'),
      materializer: (Uint8List bytes, E2EVideoFormat format) async =>
          throw StateError('must not run'),
    );

    expect(await service.pick(source: ImageSource.gallery), isNull);
  });

  test('invalid video signature is rejected before duration probing', () async {
    var durationProbeCalls = 0;
    var materializerCalls = 0;
    final VideoSelectionService service = VideoSelectionService(
      picker: ({required ImageSource source, Duration? maxDuration}) async =>
          XFile.fromData(
        Uint8List.fromList(utf8.encode('renamed-not-video.mp4')),
        name: 'renamed.mp4',
      ),
      durationProbe: (_) async {
        durationProbeCalls += 1;
        return const Duration(seconds: 2);
      },
      materializer: (Uint8List bytes, E2EVideoFormat format) async {
        materializerCalls += 1;
        return '/tmp/invalid.mp4';
      },
    );

    await expectLater(
      service.pick(source: ImageSource.gallery),
      throwsA(isA<E2EVideoValidationException>()),
    );
    expect(durationProbeCalls, 0);
    expect(materializerCalls, 0);
  });
}

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
