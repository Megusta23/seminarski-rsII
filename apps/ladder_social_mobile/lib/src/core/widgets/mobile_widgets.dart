import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';

String formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

String formatDateTime(DateTime value) {
  final DateTime local = value.toLocal();
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '${formatDate(local)} $hour:$minute';
}

String imageContentType(String fileName, String? supplied) {
  if (supplied != null && supplied.startsWith('image/')) {
    return supplied;
  }
  final String lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
}

final class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ApiException exception = ApiException.from(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 44,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(exception.message, textAlign: TextAlign.center),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.title, this.message, super.key});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class ProtectedImage extends ConsumerStatefulWidget {
  const ProtectedImage({
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  ConsumerState<ProtectedImage> createState() => _ProtectedImageState();
}

final class _ProtectedImageState extends ConsumerState<ProtectedImage> {
  Future<Uint8List>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= ref.read(mediaRepositoryProvider).loadBytes(widget.path);
  }

  @override
  void didUpdateWidget(covariant ProtectedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _future = ref.read(mediaRepositoryProvider).loadBytes(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget image = FutureBuilder<Uint8List>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<Uint8List> snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
          );
        }
        if (snapshot.hasError) {
          return Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
        }
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
    final BorderRadius? radius = widget.borderRadius;
    return radius == null
        ? image
        : ClipRRect(borderRadius: radius, child: image);
  }
}

final class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.displayName,
    this.avatarUrl,
    this.radius = 22,
    super.key,
  });

  final String displayName;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String? url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: ProtectedImage(
          path: url,
          width: radius * 2,
          height: radius * 2,
        ),
      );
    }
    final String initials = displayName
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .map((String part) => part[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      child: Text(initials.isEmpty ? '?' : initials),
    );
  }
}
