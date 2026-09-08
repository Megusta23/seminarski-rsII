import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/proof_composer.dart';

final class ProofPhotoEditorScreen extends StatefulWidget {
  const ProofPhotoEditorScreen({required this.photo, super.key});

  final EditableProofPhoto photo;

  @override
  State<ProofPhotoEditorScreen> createState() => _ProofPhotoEditorScreenState();
}

final class _ProofPhotoEditorScreenState extends State<ProofPhotoEditorScreen> {
  late Uint8List _bytes = widget.photo.bytes;
  late bool _hasEdits = widget.photo.isEdited;
  bool _busy = false;
  int _revision = 0;
  String? _error;

  Future<void> _apply(
    Future<Uint8List> Function(Uint8List bytes) transform,
  ) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Uint8List result = await transform(_bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _bytes = result;
        _hasEdits = true;
        _revision++;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addText() async {
    String value = '';
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Text overlay'),
        content: TextField(
          autofocus: true,
          maxLength: 120,
          maxLines: 3,
          onChanged: (String next) => value = next,
          decoration: const InputDecoration(
            hintText: 'Write text to place on the photo',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) {
      return;
    }
    await _apply((Uint8List bytes) => addProofTextOverlay(bytes, text));
  }

  void _reset() {
    final EditableProofPhoto reset = widget.photo.reset();
    setState(() {
      _bytes = reset.bytes;
      _hasEdits = false;
      _revision++;
      _error = null;
    });
  }

  void _save() {
    final EditableProofPhoto result =
        _hasEdits ? widget.photo.withEditedBytes(_bytes) : widget.photo.reset();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF26344D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Edit photo'),
        actions: <Widget>[
          TextButton(
            onPressed: _busy ? null : _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.memory(
                  _bytes,
                  key: ValueKey<int>(_revision),
                  fit: BoxFit.contain,
                  gaplessPlayback: false,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) =>
                      const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'The edited image could not be displayed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFB4AB)),
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _EditorAction(
                    tooltip: 'Rotate photo 90 degrees',
                    icon: Icons.rotate_90_degrees_cw_outlined,
                    label: 'Rotate',
                    onPressed:
                        _busy ? null : () => _apply(rotateProofPhotoClockwise),
                  ),
                  _EditorAction(
                    tooltip: 'Crop photo to a square',
                    icon: Icons.crop_square_outlined,
                    label: 'Crop',
                    onPressed:
                        _busy ? null : () => _apply(cropProofPhotoSquare),
                  ),
                  _EditorAction(
                    tooltip: 'Add text to photo',
                    icon: Icons.text_fields_outlined,
                    label: 'Text',
                    onPressed: _busy ? null : _addText,
                  ),
                  _EditorAction(
                    tooltip: 'Reset all photo edits',
                    icon: Icons.restart_alt,
                    label: 'Reset',
                    onPressed: _busy ? null : _reset,
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

final class _EditorAction extends StatelessWidget {
  const _EditorAction({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 34,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: onPressed == null ? Colors.white38 : Colors.white,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: onPressed == null ? Colors.white38 : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
