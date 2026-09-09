import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

typedef VideoPicker = Future<XFile?> Function({
  required ImageSource source,
  Duration? maxDuration,
});
typedef VideoDurationProbe = Future<Duration> Function(String path);
typedef VideoDraftMaterializer = Future<String> Function(
  Uint8List bytes,
  E2EVideoFormat format,
);

final class VideoDraft {
  VideoDraft({
    required this.filePath,
    required List<int> bytes,
    required this.durationMilliseconds,
    required this.format,
  }) : _bytes = Uint8List.fromList(bytes);

  final String filePath;
  final Uint8List _bytes;
  final int durationMilliseconds;
  final E2EVideoFormat format;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  Future<void> delete() async {
    final File file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

final class VideoSelectionService {
  VideoSelectionService({
    VideoPicker? picker,
    VideoDurationProbe? durationProbe,
    VideoDraftMaterializer? materializer,
  })  : _picker = picker ?? _defaultPicker,
        _durationProbe = durationProbe ?? _probeDuration,
        _materializer = materializer ?? _materializeDraft;

  final VideoPicker _picker;
  final VideoDurationProbe _durationProbe;
  final VideoDraftMaterializer _materializer;

  Future<VideoDraft?> pick({required ImageSource source}) async {
    String? materializedPath;
    try {
      final XFile? selected = await _picker(
        source: source,
        maxDuration: const Duration(
          milliseconds: E2EVideoValidator.maximumDurationMilliseconds,
        ),
      );
      if (selected == null) {
        return null;
      }

      final int selectedLength = await selected.length();
      if (selectedLength > E2ECryptoConstants.maximumPlainMediaBytes) {
        throw E2EVideoValidationException(
          'The selected video is too large. Encrypted video uploads may be at '
          'most ${E2ECryptoConstants.maximumEncryptedMediaBytes ~/ (1024 * 1024)} MiB.',
        );
      }

      final Uint8List bytes = await selected.readAsBytes();
      final E2EVideoFormat format = E2EVideoValidator.detectFormat(bytes);
      materializedPath = await _materializer(bytes, format);
      final Duration duration = await _durationProbe(materializedPath);
      final int durationMilliseconds = duration.inMilliseconds;
      E2EVideoValidator.validate(
        bytes: bytes,
        durationMilliseconds: durationMilliseconds,
      );

      return VideoDraft(
        filePath: materializedPath,
        bytes: bytes,
        durationMilliseconds: durationMilliseconds,
        format: format,
      );
    } on E2EVideoValidationException {
      if (materializedPath != null) {
        await _deleteIfPresent(materializedPath);
      }
      rethrow;
    } catch (error) {
      if (materializedPath != null) {
        await _deleteIfPresent(materializedPath);
      }
      throw E2EVideoValidationException(
        'The selected video could not be prepared for encrypted messaging.',
        error,
      );
    }
  }

  static Future<XFile?> _defaultPicker({
    required ImageSource source,
    Duration? maxDuration,
  }) =>
      ImagePicker().pickVideo(
        source: source,
        maxDuration: maxDuration,
      );

  static Future<Duration> _probeDuration(String path) async {
    final VideoPlayerController controller =
        VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      if (!controller.value.isInitialized || controller.value.hasError) {
        throw E2EVideoValidationException(
          controller.value.errorDescription ??
              'The selected video could not be decoded.',
        );
      }
      final Duration duration = controller.value.duration;
      if (duration <= Duration.zero) {
        throw const E2EVideoValidationException(
          'The selected video has no valid duration.',
        );
      }
      return duration;
    } finally {
      await controller.dispose();
    }
  }

  static Future<String> _materializeDraft(
    Uint8List bytes,
    E2EVideoFormat format,
  ) async {
    final Directory temporary = await getTemporaryDirectory();
    final Directory drafts = Directory(
      '${temporary.path}${Platform.pathSeparator}ladder-social-video-drafts',
    );
    await drafts.create(recursive: true);
    final String path = '${drafts.path}${Platform.pathSeparator}'
        'video-${DateTime.now().microsecondsSinceEpoch}${format.fileExtension}';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  static Future<void> _deleteIfPresent(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
