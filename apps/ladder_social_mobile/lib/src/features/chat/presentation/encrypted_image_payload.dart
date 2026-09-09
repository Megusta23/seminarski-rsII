import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

typedef EncryptedImageLoader = Future<Uint8List> Function(
  ChatMessage message, {
  bool forceReload,
});

typedef EncryptedImageErrorText = String Function(Object error);

final class EncryptedImagePayload extends StatefulWidget {
  const EncryptedImagePayload({
    required this.message,
    required this.load,
    required this.errorText,
    super.key,
  });

  final ChatMessage message;
  final EncryptedImageLoader load;
  final EncryptedImageErrorText errorText;

  @override
  State<EncryptedImagePayload> createState() => _EncryptedImagePayloadState();
}

final class _EncryptedImagePayloadState extends State<EncryptedImagePayload> {
  late Future<Uint8List> _imageLoad;

  @override
  void initState() {
    super.initState();
    _imageLoad = widget.load(widget.message);
  }

  @override
  void didUpdateWidget(covariant EncryptedImagePayload oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loadIdentity(oldWidget.message) != _loadIdentity(widget.message)) {
      _imageLoad = widget.load(widget.message);
    }
  }

  String _loadIdentity(ChatMessage message) => <Object?>[
        message.id,
        message.attachmentId,
        message.attachmentUrl,
        message.attachmentKeyVersion,
        message.attachmentSizeBytes,
        message.attachmentNonce?.join(','),
      ].join('|');

  void _retry() {
    setState(() {
      _imageLoad = widget.load(widget.message, forceReload: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageLoad,
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              snapshot.data!,
              width: 280,
              height: 210,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) =>
                  const _EncryptedImageProblem(
                message: 'The authenticated bytes are not a decodable image.',
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _EncryptedImageProblem(
            message: widget.errorText(snapshot.error!),
            onRetry: _retry,
          );
        }

        return Container(
          width: 280,
          height: 210,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircularProgressIndicator(strokeWidth: 2.4),
              SizedBox(height: 12),
              Text(
                'Downloading and authenticating encrypted image...',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _EncryptedImageProblem extends StatelessWidget {
  const _EncryptedImageProblem({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, color: colors.onErrorContainer),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onErrorContainer),
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
}
