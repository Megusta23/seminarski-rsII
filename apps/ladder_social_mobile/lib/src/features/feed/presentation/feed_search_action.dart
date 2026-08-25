import 'package:flutter/material.dart';

final class FeedSearchController extends ValueNotifier<String> {
  FeedSearchController([String initialQuery = '']) : super(initialQuery.trim());

  bool get hasQuery => value.isNotEmpty;

  void submit(String query) {
    final String normalizedQuery = query.trim();
    if (normalizedQuery == value) {
      notifyListeners();
      return;
    }
    value = normalizedQuery;
  }

  void clear() => submit('');
}

final class FeedSearchAction extends StatelessWidget {
  const FeedSearchAction({
    required this.controller,
    super.key,
  });

  final FeedSearchController controller;

  Future<void> _openSearch(BuildContext context) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _FeedSearchDialog(initialQuery: controller.value);
      },
    );

    if (result == null || !context.mounted) return;
    controller.submit(result);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
        valueListenable: controller,
        builder: (BuildContext context, String query, Widget? child) {
          final String tooltip =
              query.isEmpty ? 'Search feed' : 'Search feed: $query';
          return Badge(
            isLabelVisible: query.isNotEmpty,
            smallSize: 8,
            child: IconButton(
              tooltip: tooltip,
              onPressed: () => _openSearch(context),
              icon: const Icon(Icons.search),
            ),
          );
        },
      );
}

final class _FeedSearchDialog extends StatefulWidget {
  const _FeedSearchDialog({required this.initialQuery});

  final String initialQuery;

  @override
  State<_FeedSearchDialog> createState() => _FeedSearchDialogState();
}

final class _FeedSearchDialogState extends State<_FeedSearchDialog> {
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop<String>(_inputController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Search feed'),
      content: TextField(
        key: const ValueKey<String>('feed-search-field'),
        controller: _inputController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: 'Friend name, task or caption',
          prefixIcon: Icon(Icons.search),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('feed-search-clear'),
          onPressed: () => Navigator.of(context).pop<String>(''),
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey<String>('feed-search-submit'),
          onPressed: _submit,
          child: const Text('Search'),
        ),
      ],
    );
  }
}
