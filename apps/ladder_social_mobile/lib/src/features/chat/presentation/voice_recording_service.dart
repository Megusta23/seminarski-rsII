import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

final class VoiceRecordingDraft {
  VoiceRecordingDraft({
    required this.filePath,
    required List<int> bytes,
    required this.durationMilliseconds,
    required this.format,
  }) : _bytes = Uint8List.fromList(bytes);

  final String filePath;
  final Uint8List _bytes;
  final int durationMilliseconds;
  final E2EVoiceFormat format;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  Future<void> delete() async {
    final File file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

final class VoiceRecordingService {
  VoiceRecordingService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
    autoGain: true,
    echoCancel: true,
    noiseSuppress: true,
  );

  final AudioRecorder _recorder;
  Future<void> _operationTail = Future<void>.value();
  Future<void>? _disposeFuture;
  String? _activePath;
  bool _disposeRequested = false;
  bool _disposed = false;

  Future<bool> requestPermission() {
    _ensureAvailable();
    return _enqueue<bool>(() async {
      _ensureAvailable();
      return _recorder.hasPermission();
    });
  }

  Future<void> start() {
    _ensureAvailable();
    return _enqueue<void>(() async {
      _ensureAvailable();
      if (_activePath != null) {
        throw const E2EVoiceValidationException(
          'A voice recording is already in progress.',
        );
      }
      if (!await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
        throw const E2EVoiceValidationException(
          'This device does not support AAC voice recording.',
        );
      }

      final Directory temporary = await getTemporaryDirectory();
      final Directory drafts = Directory(
        '${temporary.path}${Platform.pathSeparator}ladder-social-voice-drafts',
      );
      await drafts.create(recursive: true);
      final String path = '${drafts.path}${Platform.pathSeparator}'
          'voice-${DateTime.now().microsecondsSinceEpoch}.m4a';

      try {
        await _recorder.start(_recordConfig, path: path);
        _activePath = path;
      } catch (error) {
        await _deleteIfPresent(path);
        throw E2EVoiceValidationException(
          'Voice recording could not be started.',
          error,
        );
      }
    });
  }

  Future<VoiceRecordingDraft> stop({required Duration elapsed}) {
    _ensureAvailable();
    return _enqueue<VoiceRecordingDraft>(() async {
      _ensureAvailable();
      final String? expectedPath = _activePath;
      if (expectedPath == null) {
        throw const E2EVoiceValidationException(
          'No voice recording is currently in progress.',
        );
      }

      String? outputPath;
      try {
        outputPath = await _recorder.stop();
        _activePath = null;
        final String path = outputPath?.trim().isNotEmpty == true
            ? outputPath!.trim()
            : expectedPath;
        final File file = File(path);
        if (!await file.exists()) {
          throw const E2EVoiceValidationException(
            'The recorded voice file could not be found.',
          );
        }

        final Uint8List bytes = await file.readAsBytes();
        final int durationMilliseconds = await _resolveDurationMilliseconds(
          path: path,
          elapsed: elapsed,
        );
        final E2EVoiceFormat format = E2EVoiceValidator.validate(
          bytes: bytes,
          durationMilliseconds: durationMilliseconds,
        );
        return VoiceRecordingDraft(
          filePath: path,
          bytes: bytes,
          durationMilliseconds: durationMilliseconds,
          format: format,
        );
      } catch (error) {
        _activePath = null;
        await _deleteIfPresent(outputPath ?? expectedPath);
        if (error is E2EVoiceValidationException) {
          rethrow;
        }
        throw E2EVoiceValidationException(
          'Voice recording could not be finalized.',
          error,
        );
      }
    });
  }

  Future<void> cancel() {
    if (_disposed || _disposeRequested) {
      return Future<void>.value();
    }
    return _enqueue<void>(_cancelActiveRecording);
  }

  Future<void> dispose() {
    final Future<void>? existing = _disposeFuture;
    if (existing != null) {
      return existing;
    }

    _disposeRequested = true;
    final Future<void> future = _enqueue<void>(() async {
      try {
        await _cancelActiveRecording();
      } finally {
        _disposed = true;
        await _recorder.dispose();
      }
    });
    _disposeFuture = future;
    return future;
  }

  Future<void> _cancelActiveRecording() async {
    final String? path = _activePath;
    _activePath = null;
    if (path == null) {
      return;
    }
    try {
      await _recorder.cancel();
    } finally {
      await _deleteIfPresent(path);
    }
  }

  Future<int> _resolveDurationMilliseconds({
    required String path,
    required Duration elapsed,
  }) async {
    final AudioPlayer probe = AudioPlayer();
    try {
      final Duration? decoded = await probe.setFilePath(path);
      final int decodedMilliseconds = decoded?.inMilliseconds ?? 0;
      if (decodedMilliseconds > 0) {
        return decodedMilliseconds;
      }
      return elapsed.inMilliseconds;
    } finally {
      await probe.dispose();
    }
  }

  Future<void> _deleteIfPresent(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final Future<void> previous = _operationTail;
    final Completer<T> completer = Completer<T>();

    Future<void> execute() async {
      try {
        await previous;
      } catch (_) {
        // A caller receives the original operation error through its completer.
      }
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    _operationTail = execute();
    return completer.future;
  }

  void _ensureAvailable() {
    if (_disposed || _disposeRequested) {
      throw StateError('VoiceRecordingService has already been disposed.');
    }
  }
}
