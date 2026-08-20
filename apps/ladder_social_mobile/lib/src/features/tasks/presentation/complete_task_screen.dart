import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/core/providers/core_providers.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class CompleteTaskScreen extends ConsumerStatefulWidget {
  const CompleteTaskScreen({required this.task, super.key});
  final TaskDetail task;

  @override
  ConsumerState<CompleteTaskScreen> createState() => _CompleteTaskScreenState();
}

final class _CompleteTaskScreenState extends ConsumerState<CompleteTaskScreen> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  DateTime _occurrenceDate = DateTime.now();
  ImageUpload? _proof;
  Uint8List? _preview;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1920,
    );
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _preview = bytes;
      _proof = ImageUpload(
        bytes: bytes,
        fileName: file.name,
        contentType: imageContentType(file.name, file.mimeType),
      );
    });
  }

  Future<void> _selectSource() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pickDate() async {
    final DateTime? value = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _occurrenceDate,
    );
    if (value != null) setState(() => _occurrenceDate = value);
  }

  Future<void> _complete() async {
    if (widget.task.requiresProofImage && _proof == null) {
      setState(() => _error = 'This task requires a proof image.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final TaskCompletionItem completion =
          await ref.read(taskRepositoryProvider).completeTask(
                taskId: widget.task.id,
                occurrenceDate: _occurrenceDate,
                note: _noteController.text,
                caption: _captionController.text,
                proof: _proof,
              );
      if (!mounted) return;
      Navigator.of(context).pop<TaskCompletionItem>(completion);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = ApiException.from(error).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete task')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(widget.task.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('${widget.task.categoryName} • ${widget.task.recurrenceName}'),
          const SizedBox(height: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.today_outlined),
            title: const Text('Occurrence date'),
            subtitle: Text(formatDate(_occurrenceDate)),
            trailing: IconButton(
              onPressed: _pickDate,
              icon: const Icon(Icons.edit_calendar_outlined),
            ),
          ),
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Private completion note',
              prefixIcon: Icon(Icons.notes),
              alignLabelWithHint: true,
            ),
          ),
          if (widget.task.shareWithFriends) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Feed caption',
                prefixIcon: Icon(Icons.dynamic_feed_outlined),
                alignLabelWithHint: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _selectSource,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(
              _proof == null
                  ? widget.task.requiresProofImage
                      ? 'Add required proof image'
                      : 'Add optional proof image'
                  : 'Replace proof image',
            ),
          ),
          if (_preview != null) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_preview!, height: 260, fit: BoxFit.cover),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _preview = null;
                _proof = null;
              }),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove image'),
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _complete,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Mark completed'),
          ),
        ],
      ),
    );
  }
}
