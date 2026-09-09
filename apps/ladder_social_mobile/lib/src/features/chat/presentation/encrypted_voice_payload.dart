import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:path_provider/path_provider.dart';

// Clear voice bytes are materialized only in the app's temporary directory and
// deleted when the playback widget is disposed or retried.
typedef EncryptedVoiceLoader = Future<Uint8List> Function(
  ChatMessage message, {
  bool forceReload,
});
typedef EncryptedVoiceErrorText = String Function(Object error);
typedef VoiceAudioPlayerFactory = VoiceAudioPlayer Function();
typedef VoiceFileMaterializer = Future<VoiceMaterializedFile> Function(
  Uint8List bytes,
  E2EVoiceFormat format,
  String identity,
);

final class VoiceMaterializedFile {
  const VoiceMaterializedFile({
    required this.path,
    required this.deleteWhenDone,
  });

  final String path;
  final bool deleteWhenDone;
}

final class VoicePlayerSnapshot {
  const VoicePlayerSnapshot({
    required this.isPlaying,
    required this.isLoading,
    required this.isCompleted,
  });

  final bool isPlaying;
  final bool isLoading;
  final bool isCompleted;
}

abstract interface class VoiceAudioPlayer {
  Stream<Duration> get positionStream;
  Stream<VoicePlayerSnapshot> get stateStream;
  Stream<Object> get errorStream;

  Future<Duration?> loadFile(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

final class JustAudioVoicePlayer implements VoiceAudioPlayer {
  JustAudioVoicePlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<VoicePlayerSnapshot> get stateStream => _player.playerStateStream.map(
        (PlayerState state) => VoicePlayerSnapshot(
          isPlaying: state.playing,
          isLoading: state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering,
          isCompleted: state.processingState == ProcessingState.completed,
        ),
      );

  @override
  Stream<Object> get errorStream => _player.errorStream;

  @override
  Future<Duration?> loadFile(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final class EncryptedVoicePayload extends StatefulWidget {
  const EncryptedVoicePayload({
    required this.message,
    required this.load,
    required this.errorText,
    this.playerFactory,
    this.materializer,
    super.key,
  });

  final ChatMessage message;
  final EncryptedVoiceLoader load;
  final EncryptedVoiceErrorText errorText;
  final VoiceAudioPlayerFactory? playerFactory;
  final VoiceFileMaterializer? materializer;

  @override
  State<EncryptedVoicePayload> createState() => _EncryptedVoicePayloadState();
}

final class VoiceDraftPreview extends StatelessWidget {
  const VoiceDraftPreview({
    required this.path,
    required this.durationMilliseconds,
    this.playerFactory,
    super.key,
  });

  final String path;
  final int durationMilliseconds;
  final VoiceAudioPlayerFactory? playerFactory;

  @override
  Widget build(BuildContext context) => _VoicePlaybackPanel(
        key: ValueKey<String>('voice-draft-$path'),
        expectedDurationMilliseconds: durationMilliseconds,
        loadingLabel: 'Preparing voice preview...',
        playerFactory: playerFactory ?? JustAudioVoicePlayer.new,
        loadSource: (_) async => VoiceMaterializedFile(
          path: path,
          deleteWhenDone: false,
        ),
      );
}

final class _EncryptedVoicePayloadState extends State<EncryptedVoicePayload> {
  @override
  Widget build(BuildContext context) {
    final int? durationMilliseconds =
        widget.message.attachmentDurationMilliseconds;
    if (durationMilliseconds == null || durationMilliseconds < 1) {
      return const _VoiceErrorCard(
        message: 'Encrypted voice metadata is incomplete.',
      );
    }

    return _VoicePlaybackPanel(
      key: ValueKey<String>(
        'encrypted-voice-${widget.message.id}-'
        '${widget.message.attachmentId}-'
        '${widget.message.attachmentUrl}-'
        '${widget.message.attachmentKeyVersion}-'
        '${widget.message.attachmentSizeBytes}-'
        '$durationMilliseconds-'
        '${widget.message.attachmentNonce?.join(',')}',
      ),
      expectedDurationMilliseconds: durationMilliseconds,
      loadingLabel: 'Downloading and authenticating encrypted voice...',
      playerFactory: widget.playerFactory ?? JustAudioVoicePlayer.new,
      errorText: widget.errorText,
      loadSource: (bool forceReload) async {
        final Uint8List bytes = await widget.load(
          widget.message,
          forceReload: forceReload,
        );
        final E2EVoiceFormat format = E2EVoiceValidator.validate(
          bytes: bytes,
          durationMilliseconds: durationMilliseconds,
        );
        final VoiceFileMaterializer materialize =
            widget.materializer ?? materializeVoiceFile;
        return materialize(bytes, format, widget.message.id);
      },
    );
  }
}

typedef _VoiceSourceLoader = Future<VoiceMaterializedFile> Function(
  bool forceReload,
);

final class _VoicePlaybackPanel extends StatefulWidget {
  const _VoicePlaybackPanel({
    required this.expectedDurationMilliseconds,
    required this.loadingLabel,
    required this.playerFactory,
    required this.loadSource,
    this.errorText,
    super.key,
  });

  final int expectedDurationMilliseconds;
  final String loadingLabel;
  final VoiceAudioPlayerFactory playerFactory;
  final _VoiceSourceLoader loadSource;
  final EncryptedVoiceErrorText? errorText;

  @override
  State<_VoicePlaybackPanel> createState() => _VoicePlaybackPanelState();
}

final class _VoicePlaybackPanelState extends State<_VoicePlaybackPanel> {
  late final VoiceAudioPlayer _player;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<VoicePlayerSnapshot>? _stateSubscription;
  StreamSubscription<Object>? _errorSubscription;
  VoiceMaterializedFile? _source;
  Duration _position = Duration.zero;
  late Duration _duration;
  bool _loading = true;
  bool _playing = false;
  bool _playerLoading = false;
  bool _completed = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.expectedDurationMilliseconds);
    _player = widget.playerFactory();
    _positionSubscription = _player.positionStream.listen((Duration value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = _clampDuration(value, _duration);
      });
    });
    _stateSubscription =
        _player.stateStream.listen((VoicePlayerSnapshot value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playing = value.isPlaying;
        _playerLoading = value.isLoading;
        _completed = value.isCompleted;
        if (_completed) {
          _position = _duration;
        }
      });
    });
    _errorSubscription = _player.errorStream.listen((Object error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _playing = false;
      });
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    final VoiceMaterializedFile? source = _source;
    _source = null;
    unawaited(_disposeResources(source));
    super.dispose();
  }

  Future<void> _disposeResources(VoiceMaterializedFile? source) async {
    await _positionSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _errorSubscription?.cancel();
    try {
      await _player.dispose();
    } finally {
      if (source != null && source.deleteWhenDone) {
        await _deleteVoiceFile(source.path);
      }
    }
  }

  Future<void> _load({bool forceReload = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _position = Duration.zero;
        _playing = false;
        _completed = false;
      });
    }

    final VoiceMaterializedFile? oldSource = _source;
    _source = null;
    VoiceMaterializedFile? pendingSource;
    try {
      await _player.stop();
      if (oldSource != null && oldSource.deleteWhenDone) {
        await _deleteVoiceFile(oldSource.path);
      }
      final VoiceMaterializedFile source = await widget.loadSource(forceReload);
      pendingSource = source;
      final Duration? decodedDuration = await _player.loadFile(source.path);
      final Duration expected =
          Duration(milliseconds: widget.expectedDurationMilliseconds);
      if (decodedDuration != null && decodedDuration > Duration.zero) {
        final int difference =
            (decodedDuration.inMilliseconds - expected.inMilliseconds).abs();
        if (difference > 1500) {
          throw const E2EVoiceValidationException(
            'The decoded voice duration does not match authenticated message metadata.',
          );
        }
      }
      if (!mounted) {
        if (source.deleteWhenDone) {
          await _deleteVoiceFile(source.path);
        }
        return;
      }
      setState(() {
        _source = source;
        _duration = decodedDuration != null && decodedDuration > Duration.zero
            ? decodedDuration
            : expected;
        _loading = false;
      });
      pendingSource = null;
    } catch (error) {
      final VoiceMaterializedFile? failedSource = pendingSource;
      if (failedSource != null && failedSource.deleteWhenDone) {
        await _deleteVoiceFile(failedSource.path);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_loading || _error != null || _source == null) {
      return;
    }
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      if (_completed || _position >= _duration) {
        await _player.seek(Duration.zero);
        if (mounted) {
          setState(() {
            _position = Duration.zero;
            _completed = false;
          });
        }
      }
      unawaited(_player.play());
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _seek(double milliseconds) async {
    final Duration target = Duration(milliseconds: milliseconds.round());
    try {
      await _player.seek(target);
      if (mounted) {
        setState(() {
          _position = target;
          _completed = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Object? error = _error;
    if (error != null) {
      return _VoiceErrorCard(
        message: widget.errorText?.call(error) ??
            'The voice message could not be prepared for playback.',
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

    final double maximum =
        _duration.inMilliseconds <= 0 ? 1 : _duration.inMilliseconds.toDouble();
    final double current =
        _position.inMilliseconds.clamp(0, maximum.toInt()).toDouble();
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
      decoration: _cardDecoration(context),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton.filledTonal(
                tooltip:
                    _playing ? 'Pause voice message' : 'Play voice message',
                onPressed: _playerLoading ? null : _togglePlayback,
                icon: _playerLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Slider(
                  value: current,
                  max: maximum,
                  onChanged: _playerLoading
                      ? null
                      : (double value) => unawaited(_seek(value)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  formatVoiceDuration(_position),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  formatVoiceDuration(_duration),
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

final class _VoiceErrorCard extends StatelessWidget {
  const _VoiceErrorCard({required this.message, this.onRetry});

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

Future<VoiceMaterializedFile> materializeVoiceFile(
  Uint8List bytes,
  E2EVoiceFormat format,
  String identity,
) async {
  final Directory temporary = await getTemporaryDirectory();
  final Directory playback = Directory(
    '${temporary.path}${Platform.pathSeparator}ladder-social-voice-playback',
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
  return VoiceMaterializedFile(path: path, deleteWhenDone: true);
}

Future<void> _deleteVoiceFile(String path) async {
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

String formatVoiceDuration(Duration duration) {
  final int totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
