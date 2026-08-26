import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/todo_visuals.dart';

final class TaskProofViewerScreen extends ConsumerStatefulWidget {
  const TaskProofViewerScreen({
    required this.task,
    required this.completion,
    super.key,
  });

  final TaskDetail task;
  final TaskCompletionItem completion;

  @override
  ConsumerState<TaskProofViewerScreen> createState() =>
      _TaskProofViewerScreenState();
}

final class _TaskProofViewerScreenState
    extends ConsumerState<TaskProofViewerScreen> {
  Future<Uint8List>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? path = widget.completion.proofUrl;
    if (path != null && path.isNotEmpty) {
      _future ??= ref.read(mediaRepositoryProvider).loadBytes(path);
    }
  }

  void _retry() {
    final String? path = widget.completion.proofUrl;
    if (path == null || path.isEmpty) {
      return;
    }
    setState(() {
      _future = ref.read(mediaRepositoryProvider).loadBytes(path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final TodoCategoryPalette palette =
        todoCategoryPalette(widget.task.categoryCode);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Completed task'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_future == null)
            const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white70,
                size: 54,
              ),
            )
          else
            FutureBuilder<Uint8List>(
              future: _future,
              builder: (
                BuildContext context,
                AsyncSnapshot<Uint8List> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white70,
                            size: 56,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'The proof image could not be loaded.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                );
              },
            ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x77000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                  stops: <double>[0, 0.22, 0.60, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.task.categoryName,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.task.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Completed ${formatDateTime(widget.completion.completedAtUtc)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  if (widget.completion.note != null &&
                      widget.completion.note!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      widget.completion.note!.trim(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
