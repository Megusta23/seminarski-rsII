import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

// Clear video bytes are materialized only in the app's temporary directory and
// removed when the playback widget is disposed or retried.
typedef EncryptedVideoLoader = Future<Uint8List> Function(
  ChatMessage message, {
  bool forceReload,
});
typedef EncryptedVideoErrorText = String Function(Object error);
typedef VideoPlaybackControllerFactory = VideoPlaybackController Function(
  String path,
);
typedef VideoFileMaterializer = Future<VideoMaterializedFile> Function(
  Uint8List bytes,
  E2EVideoFormat format,
  String identity,
);

final class VideoMaterializedFile {
  const VideoMaterializedFile({
    required this.path,
    required this.deleteWhenDone,
  });

  final String path;
  final bool deleteWhenDone;
}

final class VideoPlaybackSnapshot {
  const VideoPlaybackSnapshot({
    required this.isInitialized,
    required this.isPlaying,
    required this.isBuffering,
    required this.position,
    required this.duration,
    required this.aspectRatio,
    this.errorDescription,
  });

  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
  final String? errorDescription;

  bool get hasError => errorDescription?.trim().isNotEmpty == true;
}

abstract interface class VideoPlaybackController {
  VideoPlaybackSnapshot get snapshot;

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Widget buildVideo();
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

final class FlutterVideoPlaybackController implements VideoPlaybackController {
  FlutterVideoPlaybackController(String path)
      : _controller = VideoPlayerController.file(File(path));

  final VideoPlayerController _controller;

  @override
  VideoPlaybackSnapshot get snapshot {
    final VideoPlayerValue value = _controller.value;
    return VideoPlaybackSnapshot(
      isInitialized: value.isInitialized,
      isPlaying: value.isPlaying,
      isBuffering: value.isBuffering,
      position: value.position,
      duration: value.duration,
      aspectRatio: value.aspectRatio,
      errorDescription: value.hasError ? value.errorDescription : null,
    );
  }

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  Widget buildVideo() => VideoPlayer(_controller);

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> play() => _controller.play();

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  @override
  Future<void> seek(Duration position) => _controller.seekTo(position);
}

final class EncryptedVideoPayload extends StatefulWidget {
  const EncryptedVideoPayload({
    required this.message,
    required this.load,
    required this.errorText,
    this.controllerFactory,
    this.materializer,
    super.key,
  });

  final ChatMessage message;
  final EncryptedVideoLoader load;
  final EncryptedVideoErrorText errorText;
  final VideoPlaybackControllerFactory? controllerFactory;
  final VideoFileMaterializer? materializer;

  @override
  State<EncryptedVideoPayload> createState() => _EncryptedVideoPayloadState();
}

final class VideoDraftPreview extends StatelessWidget {
  const VideoDraftPreview({
    required this.path,
    required this.durationMilliseconds,
    this.controllerFactory,
    super.key,
  });

  final String path;
  final int durationMilliseconds;
  final VideoPlaybackControllerFactory? controllerFactory;

  @override
  Widget build(BuildContext context) => _VideoPlaybackPanel(
        key: ValueKey<String>('video-draft-$path'),
        expectedDurationMilliseconds: durationMilliseconds,
        loadingLabel: 'Preparing video preview...',
        controllerFactory:
            controllerFactory ?? FlutterVideoPlaybackController.new,
        loadSource: (_) async => VideoMaterializedFile(
          path: path,
          deleteWhenDone: false,
        ),
      );
}

final class _EncryptedVideoPayloadState extends State<EncryptedVideoPayload> {
  @override
  Widget build(BuildContext context) {
    final int? durationMilliseconds =
        widget.message.attachmentDurationMilliseconds;
    if (durationMilliseconds == null || durationMilliseconds < 1) {
      return const _VideoErrorCard(
        message: 'Encrypted video metadata is incomplete.',
      );
    }

    return _VideoPlaybackPanel(
      key: ValueKey<String>(
        'encrypted-video-${widget.message.id}-'
        '${widget.message.attachmentId}-'
        '${widget.message.attachmentUrl}-'
        '${widget.message.attachmentKeyVersion}-'
        '${widget.message.attachmentSizeBytes}-'
        '$durationMilliseconds-'
        '${widget.message.attachmentNonce?.join(',')}',
      ),
      expectedDurationMilliseconds: durationMilliseconds,
      loadingLabel: 'Downloading and authenticating encrypted video...',
      controllerFactory:
          widget.controllerFactory ?? FlutterVideoPlaybackController.new,
      errorText: widget.errorText,
      loadSource: (bool forceReload) async {
        final Uint8List bytes = await widget.load(
          widget.message,
          forceReload: forceReload,
        );
        final E2EVideoFormat format = E2EVideoValidator.validate(
          bytes: bytes,
          durationMilliseconds: durationMilliseconds,
        );
        final VideoFileMaterializer materialize =
            widget.materializer ?? materializeVideoFile;
        return materialize(bytes, format, widget.message.id);
      },
    );
  }
}

typedef _VideoSourceLoader = Future<VideoMaterializedFile> Function(
  bool forceReload,
);

final class _VideoPlaybackPanel extends StatefulWidget {
  const _VideoPlaybackPanel({
    required this.expectedDurationMilliseconds,
    required this.loadingLabel,
    required this.controllerFactory,
    required this.loadSource,
    this.errorText,
    super.key,
  });

  final int expectedDurationMilliseconds;
  final String loadingLabel;
  final VideoPlaybackControllerFactory controllerFactory;
  final _VideoSourceLoader loadSource;
  final EncryptedVideoErrorText? errorText;

  @override
  State<_VideoPlaybackPanel> createState() => _VideoPlaybackPanelState();
}

final class _VideoPlaybackPanelState extends State<_VideoPlaybackPanel> {
  VideoPlaybackController? _controller;
  VideoMaterializedFile? _source;
  Duration _position = Duration.zero;
  late Duration _duration;
  double _aspectRatio = 16 / 9;
  bool _loading = true;
  bool _playing = false;
  bool _buffering = false;
  Object? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.expectedDurationMilliseconds);
    unawaited(_load());
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    final VideoPlaybackController? controller = _controller;
    final VideoMaterializedFile? source = _source;
    _controller = null;
    _source = null;
    unawaited(_disposeResources(controller: controller, source: source));
    super.dispose();
  }

  Future<void> _load({bool forceReload = false}) async {
    final int generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _position = Duration.zero;
        _playing = false;
        _buffering = false;
      });
    }

    final VideoPlaybackController? oldController = _controller;
    final VideoMaterializedFile? oldSource = _source;
    _controller = null;
    _source = null;
    await _disposeResources(controller: oldController, source: oldSource);

    VideoMaterializedFile? pendingSource;
    VideoPlaybackController? pendingController;
    try {
      final VideoMaterializedFile source = await widget.loadSource(forceReload);
      pendingSource = source;
      if (!mounted || generation != _loadGeneration) {
        await _disposeResources(source: source);
        return;
      }

      final VideoPlaybackController controller =
          widget.controllerFactory(source.path);
      pendingController = controller;
      await controller.initialize();
      final VideoPlaybackSnapshot snapshot = controller.snapshot;
      if (!snapshot.isInitialized || snapshot.hasError) {
        throw E2EVideoValidationException(
          snapshot.errorDescription ?? 'The video could not be decoded.',
        );
      }
      final int decodedDurationMilliseconds = snapshot.duration.inMilliseconds;
      if (!E2EVideoValidator.durationsMatch(
        authenticatedDurationMilliseconds: widget.expectedDurationMilliseconds,
        decodedDurationMilliseconds: decodedDurationMilliseconds,
      )) {
        throw const E2EVideoValidationException(
          'The decoded video duration does not match authenticated message metadata.',
        );
      }
      if (!mounted || generation != _loadGeneration) {
        await _disposeResources(controller: controller, source: source);
        return;
      }

      controller.addListener(_handleControllerChanged);
      setState(() {
        _controller = controller;
        _source = source;
        _duration = snapshot.duration;
        _position = _clampDuration(snapshot.position, snapshot.duration);
        _aspectRatio = _normalizedAspectRatio(snapshot.aspectRatio);
        _playing = snapshot.isPlaying;
        _buffering = snapshot.isBuffering;
        _loading = false;
      });
      pendingController = null;
      pendingSource = null;
    } catch (error) {
      await _disposeResources(
        controller: pendingController,
        source: pendingSource,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _handleControllerChanged() {
    final VideoPlaybackController? controller = _controller;
    if (!mounted || controller == null) {
      return;
    }
    final VideoPlaybackSnapshot snapshot = controller.snapshot;
    setState(() {
      _position = _clampDuration(snapshot.position, _duration);
      _playing = snapshot.isPlaying;
      _buffering = snapshot.isBuffering;
      if (snapshot.hasError) {
        _error = E2EVideoValidationException(
          snapshot.errorDescription ?? 'Video playback failed.',
        );
      }
    });
  }

  Future<void> _togglePlayback() async {
    final VideoPlaybackController? controller = _controller;
    if (_loading || _error != null || controller == null) {
      return;
    }
    try {
      if (_playing) {
        await controller.pause();
        return;
      }
      if (_duration > Duration.zero && _position >= _duration) {
        await controller.seek(Duration.zero);
      }
      await controller.play();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _seek(double milliseconds) async {
    final VideoPlaybackController? controller = _controller;
    if (controller == null) {
      return;
    }
    final Duration target = Duration(milliseconds: milliseconds.round());
    try {
      await controller.seek(target);
      if (mounted) {
        setState(() => _position = target);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _disposeResources({
    VideoPlaybackController? controller,
    VideoMaterializedFile? source,
  }) async {
    if (controller != null) {
      controller.removeListener(_handleControllerChanged);
      await controller.dispose();
    }
    if (source != null && source.deleteWhenDone) {
      await _deleteVideoFile(source.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Object? error = _error;
    if (error != null) {
      return _VideoErrorCard(
        message: widget.errorText?.call(error) ??
            'The video message could not be prepared for playback.',
        onRetry: () => unawaited(_load(forceReload: true)),
      );
    }
    if (_loading) {
      return Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(context),
        child: Row(
          children: <Widget>[
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.loadingLabel)),
          ],
        ),
      );
    }

    final VideoPlaybackController? controller = _controller;
    if (controller == null) {
      return const _VideoErrorCard(
        message: 'The video player is not available.',
      );
    }

    final double maximum =
        _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds.toDouble();
    final double current =
        _position.inMilliseconds.clamp(0, maximum.toInt()).toDouble();
    final double frameHeight = (280 / _aspectRatio).clamp(150, 240).toDouble();
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: _cardDecoration(context),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 280,
            height: frameHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Center(
                      child: AspectRatio(
                        aspectRatio: _aspectRatio,
                        child: controller.buildVideo(),
                      ),
                    ),
                    Center(
                      child: IconButton.filled(
                        tooltip: _playing ? 'Pause video' : 'Play video',
                        onPressed: _buffering ? null : _togglePlayback,
                        icon: _buffering
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _playing ? Icons.pause : Icons.play_arrow,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Slider(
            value: current,
            max: maximum,
            onChanged:
                _buffering ? null : (double value) => unawaited(_seek(value)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  formatVideoDuration(_position),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  formatVideoDuration(_duration),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _VideoErrorCard extends StatelessWidget {
  const _VideoErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
}

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(12),
    );

Future<VideoMaterializedFile> materializeVideoFile(
  Uint8List bytes,
  E2EVideoFormat format,
  String identity,
) async {
  final Directory temporary = await getTemporaryDirectory();
  final Directory playback = Directory(
    '${temporary.path}${Platform.pathSeparator}ladder-social-video-playback',
  );
  await playback.create(recursive: true);
  final String safeIdentity = identity.replaceAll(
    RegExp('[^A-Za-z0-9_-]'),
    '_',
  );
  final String path = '${playback.path}${Platform.pathSeparator}'
      '$safeIdentity-${DateTime.now().microsecondsSinceEpoch}'
      '${format.fileExtension}';
  await File(path).writeAsBytes(bytes, flush: true);
  return VideoMaterializedFile(path: path, deleteWhenDone: true);
}

Future<void> _deleteVideoFile(String path) async {
  final File file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

Duration _clampDuration(Duration value, Duration maximum) {
  if (value < Duration.zero) {
    return Duration.zero;
  }
  if (maximum > Duration.zero && value > maximum) {
    return maximum;
  }
  return value;
}

double _normalizedAspectRatio(double value) {
  if (!value.isFinite || value <= 0) {
    return 16 / 9;
  }
  return value;
}

String formatVideoDuration(Duration duration) {
  final int totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
