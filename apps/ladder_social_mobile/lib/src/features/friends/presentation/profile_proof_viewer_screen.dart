import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class ProfileProofViewerScreen extends ConsumerStatefulWidget {
  const ProfileProofViewerScreen({
    required this.post,
    required this.ownerDisplayName,
    this.ownerAvatarUrl,
    super.key,
  });

  final HighlightedPost post;
  final String ownerDisplayName;
  final String? ownerAvatarUrl;

  @override
  ConsumerState<ProfileProofViewerScreen> createState() =>
      _ProfileProofViewerScreenState();
}

final class _ProfileProofViewerScreenState
    extends ConsumerState<ProfileProofViewerScreen> {
  late final Future<_ProfileProofResult> _future = _load();

  Future<_ProfileProofResult> _load() async {
    final Uint8List bytes = await ref
        .read(mediaRepositoryProvider)
        .loadBytes(widget.post.proofUrl);
    Object? viewedError;
    try {
      await ref.read(feedRepositoryProvider).markProofViewed(widget.post.postId);
    } catch (error) {
      viewedError = error;
    }
    return _ProfileProofResult(bytes, viewedError);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<_ProfileProofResult>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<_ProfileProofResult> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      color: Colors.white,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return _ProofFailureView(onClose: () => Navigator.of(context).pop());
          }

          final _ProfileProofResult result = snapshot.data!;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(
                      result.bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              const IgnorePointer(child: _ViewerGradients()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          UserAvatar(
                            displayName: widget.ownerDisplayName,
                            avatarUrl: widget.ownerAvatarUrl,
                            radius: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  widget.ownerDisplayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatDateTime(widget.post.completedAtUtc),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close image',
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black26,
                            ),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (result.viewedError != null) ...<Widget>[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .errorContainer
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'The image opened, but its viewed state could not be saved.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        widget.post.taskTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          shadows: <Shadow>[
                            Shadow(color: Colors.black87, blurRadius: 8),
                          ],
                        ),
                      ),
                      if (widget.post.caption != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          widget.post.caption!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.3,
                            shadows: <Shadow>[
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 9),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.category_outlined,
                            color: Colors.white70,
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.post.categoryName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _ViewerGradients extends StatelessWidget {
  const _ViewerGradients();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 180,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Colors.black87, Colors.transparent],
            ),
          ),
        ),
        const Spacer(),
        Container(
          height: 280,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: <Color>[Colors.black87, Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}

final class _ProofFailureView extends StatelessWidget {
  const _ProofFailureView({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 54,
            ),
            const SizedBox(height: 14),
            const Text(
              'This highlighted image could not be loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProfileProofResult {
  const _ProfileProofResult(this.bytes, this.viewedError);

  final Uint8List bytes;
  final Object? viewedError;
}
