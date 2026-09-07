import 'package:flutter/material.dart';

final class ReportActionButtons extends StatelessWidget {
  const ReportActionButtons({
    required this.onSave,
    required this.onPrint,
    this.compact = false,
    super.key,
  });

  final VoidCallback? onSave;
  final VoidCallback? onPrint;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Save PDF',
            onPressed: onSave,
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: 'Print PDF',
            onPressed: onPrint,
            icon: const Icon(Icons.print_outlined),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Save PDF'),
        ),
        FilledButton.icon(
          onPressed: onPrint,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print PDF'),
        ),
      ],
    );
  }
}
