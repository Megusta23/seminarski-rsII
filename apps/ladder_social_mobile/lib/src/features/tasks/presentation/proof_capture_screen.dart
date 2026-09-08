import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/proof_composer.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/proof_photo_editor_screen.dart';

const Color _proofOrange = Color(0xFFFFA62B);
const Color _proofPurple = Color(0xFFA64EC4);
const Color _proofBackground = Color(0xFFFFF8FF);
const Color _proofCanvasTop = Color(0xFF2F415F);
const Color _proofCanvasBottom = Color(0xFF1F2B42);

final class ProofCaptureScreen extends StatefulWidget {
  const ProofCaptureScreen({
    this.initialComposition,
    super.key,
  });

  final ProofComposition? initialComposition;

  @override
  State<ProofCaptureScreen> createState() => _ProofCaptureScreenState();
}

final class _ProofCaptureScreenState extends State<ProofCaptureScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  late String _layoutCode =
      widget.initialComposition?.layoutCode ?? ProofLayoutCodes.single;
  late List<EditableProofPhoto?> _photos = _initialPhotos();
  late bool _choosingLayout = widget.initialComposition == null;
  int _selectedIndex = 0;
  bool _busy = false;
  String? _error;

  int get _requiredPhotoCount =>
      ProofLayoutCodes.requiredPhotoCount(_layoutCode);

  bool get _allSlotsFilled =>
      _photos.length == _requiredPhotoCount &&
      _photos.every((EditableProofPhoto? photo) => photo != null);

  List<EditableProofPhoto?> _initialPhotos() {
    final ProofComposition? initial = widget.initialComposition;
    if (initial == null) {
      return <EditableProofPhoto?>[null];
    }
    final int count = ProofLayoutCodes.requiredPhotoCount(initial.layoutCode);
    return List<EditableProofPhoto?>.generate(
      count,
      (int index) =>
          index < initial.photos.length ? initial.photos[index] : null,
      growable: false,
    );
  }

  void _selectLayout(String code) {
    if (_busy || code == _layoutCode) {
      return;
    }
    final int nextCount = ProofLayoutCodes.requiredPhotoCount(code);
    final List<EditableProofPhoto?> next = List<EditableProofPhoto?>.filled(
      nextCount,
      null,
    );
    for (var index = 0; index < math.min(nextCount, _photos.length); index++) {
      next[index] = _photos[index];
    }
    setState(() {
      _layoutCode = code;
      _photos = next;
      _selectedIndex = math.min(_selectedIndex, nextCount - 1);
      _error = null;
    });
  }

  Future<void> _pickForSelected(ImageSource source) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2200,
      );
      if (file == null) {
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      final EditableProofPhoto photo = EditableProofPhoto.fromPicked(
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _photos[_selectedIndex] = photo;
        _selectedIndex = _nextOpenSlot() ?? _selectedIndex;
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

  int? _nextOpenSlot() {
    for (var offset = 1; offset <= _photos.length; offset++) {
      final int candidate = (_selectedIndex + offset) % _photos.length;
      if (_photos[candidate] == null) {
        return candidate;
      }
    }
    return null;
  }

  Future<void> _editSelected() async {
    final EditableProofPhoto? photo = _photos[_selectedIndex];
    if (photo == null || _busy) {
      return;
    }
    final EditableProofPhoto? edited = await Navigator.of(context).push(
      MaterialPageRoute<EditableProofPhoto>(
        builder: (_) => ProofPhotoEditorScreen(photo: photo),
      ),
    );
    if (edited != null && mounted) {
      setState(() {
        _photos[_selectedIndex] = edited;
        _error = null;
      });
    }
  }

  void _removeSelected() {
    if (_busy || _photos[_selectedIndex] == null) {
      return;
    }
    setState(() {
      _photos[_selectedIndex] = null;
      _error = null;
    });
  }

  Future<void> _finish() async {
    if (!_allSlotsFilled || _busy) {
      setState(() {
        _error = 'Fill every photo slot before continuing.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    var finished = false;
    try {
      final List<EditableProofPhoto> photos =
          _photos.whereType<EditableProofPhoto>().toList(growable: false);
      final Uint8List coverBytes = await composeProofCover(
        _layoutCode,
        photos.map((EditableProofPhoto photo) => photo.bytes).toList(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        ProofComposition(
          layoutCode: _layoutCode,
          photos: List<EditableProofPhoto>.unmodifiable(photos),
          coverBytes: coverBytes,
        ),
      );
      finished = true;
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && !finished) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _choosingLayout
        ? _buildLayoutPicker(context)
        : _buildComposer(context);
  }

  Widget _buildLayoutPicker(BuildContext context) {
    return Scaffold(
      backgroundColor: _proofBackground,
      appBar: AppBar(
        backgroundColor: _proofBackground,
        title: const Text('Choose a layout'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Choose a layout for your photos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: ProofLayoutCodes.values.length,
                itemBuilder: (BuildContext context, int index) {
                  final String code = ProofLayoutCodes.values[index];
                  return ProofDocumentLayoutTile(
                    code: code,
                    selected: code == _layoutCode,
                    onTap: () => _selectLayout(code),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _choosingLayout = false;
                          _error = null;
                        }),
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  'Continue with ${ProofLayoutCodes.requiredPhotoCount(_layoutCode)} photo(s)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Scaffold(
      backgroundColor: _proofCanvasBottom,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _choosingLayout = true;
                    _error = null;
                  }),
          tooltip: 'Change layout',
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(ProofLayoutCodes.label(_layoutCode)),
        actions: <Widget>[
          IconButton(
            onPressed: _busy || _photos.every((photo) => photo == null)
                ? null
                : () => setState(() {
                      _photos = List<EditableProofPhoto?>.filled(
                        _requiredPhotoCount,
                        null,
                      );
                      _selectedIndex = 0;
                      _error = null;
                    }),
            tooltip: 'Clear photos',
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Tap a slot, then use Gallery or Camera. Edit the selected photo before finishing.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 13,
                    child: ProofStoryCanvas(
                      layoutCode: _layoutCode,
                      photos: _photos,
                      selectedIndex: _selectedIndex,
                      enabled: !_busy,
                      onSelected: (int index) {
                        setState(() {
                          _selectedIndex = index;
                          _error = null;
                        });
                      },
                      onRemove: (int index) {
                        setState(() {
                          _selectedIndex = index;
                          _photos[index] = null;
                          _error = null;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${_photos.whereType<EditableProofPhoto>().length}/$_requiredPhotoCount photos',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFB4AB)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _ComposerControl(
                    key: const Key('proof-gallery-action'),
                    tooltip: 'Choose from gallery',
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onPressed: _busy
                        ? null
                        : () => _pickForSelected(ImageSource.gallery),
                  ),
                  Semantics(
                    button: true,
                    label: 'Take a photo for selected proof slot',
                    child: InkResponse(
                      onTap: _busy
                          ? null
                          : () => _pickForSelected(ImageSource.camera),
                      radius: 42,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white70, width: 4),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          color: _proofCanvasBottom,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  _ComposerControl(
                    key: const Key('proof-edit-action'),
                    tooltip: 'Edit selected photo',
                    icon: Icons.tune,
                    label: 'Edit',
                    onPressed: _busy || _photos[_selectedIndex] == null
                        ? null
                        : _editSelected,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: _busy || _photos[_selectedIndex] == null
                        ? null
                        : _removeSelected,
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.white70),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove selected'),
                  ),
                  const Spacer(),
                  FloatingActionButton(
                    heroTag: 'proof-finish',
                    onPressed: _allSlotsFilled && !_busy ? _finish : null,
                    tooltip: 'Use this proof',
                    backgroundColor:
                        _allSlotsFilled ? _proofOrange : Colors.white24,
                    foregroundColor: Colors.white,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class ProofDocumentLayoutTile extends StatelessWidget {
  const ProofDocumentLayoutTile({
    required this.code,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${ProofLayoutCodes.label(code)} proof layout',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _proofOrange,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xFF5C3A70) : Colors.transparent,
                width: selected ? 3 : 1,
              ),
              boxShadow: selected
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x335C3A70),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 8,
                  right: 8,
                  top: 8,
                  bottom: 30,
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      final List<Rect> slots = proofLayoutRects(
                        code,
                        Size(constraints.maxWidth, constraints.maxHeight),
                        gap: 5,
                      );
                      return Stack(
                        children: <Widget>[
                          for (final Rect rect in slots)
                            Positioned.fromRect(
                              rect: rect,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _proofPurple,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 2,
                    right: 2,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.check,
                        size: 15,
                        color: Color(0xFF5C3A70),
                      ),
                    ),
                  ),
                Positioned(
                  left: 3,
                  right: 3,
                  bottom: 0,
                  child: Text(
                    ProofLayoutCodes.label(code),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF3E2830),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class ProofStoryCanvas extends StatelessWidget {
  const ProofStoryCanvas({
    required this.layoutCode,
    required this.photos,
    required this.selectedIndex,
    required this.enabled,
    required this.onSelected,
    required this.onRemove,
    super.key,
  });

  final String layoutCode;
  final List<EditableProofPhoto?> photos;
  final int selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_proofCanvasTop, _proofCanvasBottom],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final List<Rect> slots = proofLayoutRects(
              layoutCode,
              Size(constraints.maxWidth, constraints.maxHeight),
              gap: 8,
            );
            return Stack(
              children: <Widget>[
                for (var index = 0; index < slots.length; index++)
                  Positioned.fromRect(
                    rect: slots[index],
                    child: _StorySlot(
                      index: index,
                      photo: photos[index],
                      selected: selectedIndex == index,
                      enabled: enabled,
                      onTap: () => onSelected(index),
                      onRemove: () => onRemove(index),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _StorySlot extends StatelessWidget {
  const _StorySlot({
    required this.index,
    required this.photo,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final EditableProofPhoto? photo;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final EditableProofPhoto? value = photo;
    return Material(
      color: value == null ? _proofPurple : Colors.black,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (value == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Photo ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              Image.memory(
                value.bytes,
                key: ValueKey<int>(Object.hash(value.bytes, value.fileName)),
                fit: BoxFit.cover,
                gaplessPlayback: false,
              ),
            IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? _proofOrange : Colors.transparent,
                    width: selected ? 4 : 0,
                  ),
                ),
              ),
            ),
            if (selected)
              const Positioned(
                left: 8,
                top: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xCC000000),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.touch_app, color: Colors.white, size: 17),
                  ),
                ),
              ),
            if (value != null)
              Positioned(
                top: 7,
                right: 7,
                child: IconButton.filledTonal(
                  onPressed: enabled ? onRemove : null,
                  tooltip: 'Remove photo ${index + 1}',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _ComposerControl extends StatelessWidget {
  const _ComposerControl({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
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
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: onPressed == null ? Colors.white38 : Colors.white,
                size: 28,
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
