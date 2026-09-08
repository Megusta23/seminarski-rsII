import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

const int _maximumEditedImageDimension = 1024;

final class EditableProofPhoto {
  const EditableProofPhoto({
    required this.originalBytes,
    required this.originalFileName,
    required this.originalContentType,
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.isEdited,
  });

  factory EditableProofPhoto.fromPicked({
    required Uint8List bytes,
    required String fileName,
  }) {
    final String contentType = proofImageContentType(bytes);
    final String normalizedFileName = proofImageFileName(fileName, contentType);
    return EditableProofPhoto(
      originalBytes: bytes,
      originalFileName: normalizedFileName,
      originalContentType: contentType,
      bytes: bytes,
      fileName: normalizedFileName,
      contentType: contentType,
      isEdited: false,
    );
  }

  final Uint8List originalBytes;
  final String originalFileName;
  final String originalContentType;
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final bool isEdited;

  EditableProofPhoto withEditedBytes(Uint8List editedBytes) {
    final String contentType = proofImageContentType(editedBytes);
    return EditableProofPhoto(
      originalBytes: originalBytes,
      originalFileName: originalFileName,
      originalContentType: originalContentType,
      bytes: editedBytes,
      fileName: proofImageFileName(
        'edited-proof-${DateTime.now().microsecondsSinceEpoch}',
        contentType,
      ),
      contentType: contentType,
      isEdited: true,
    );
  }

  EditableProofPhoto reset() => EditableProofPhoto(
        originalBytes: originalBytes,
        originalFileName: originalFileName,
        originalContentType: originalContentType,
        bytes: originalBytes,
        fileName: originalFileName,
        contentType: originalContentType,
        isEdited: false,
      );
}

final class ProofComposition {
  const ProofComposition({
    required this.layoutCode,
    required this.photos,
    required this.coverBytes,
  });

  final String layoutCode;
  final List<EditableProofPhoto> photos;
  final Uint8List coverBytes;
}

String proofImageContentType(Uint8List bytes) {
  if (_matchesPng(bytes)) {
    return 'image/png';
  }
  if (_matchesJpeg(bytes)) {
    return 'image/jpeg';
  }
  if (_matchesWebp(bytes)) {
    return 'image/webp';
  }

  throw const FormatException(
    'Only JPEG, PNG, and WebP proof images are supported.',
  );
}

String proofImageFileName(String fileName, String contentType) {
  final String extension = switch (contentType.toLowerCase()) {
    'image/png' => '.png',
    'image/webp' => '.webp',
    _ => '.jpg',
  };
  final String trimmed = fileName.trim();
  final int dotIndex = trimmed.lastIndexOf('.');
  final String stem = dotIndex > 0 ? trimmed.substring(0, dotIndex) : trimmed;
  final String safeStem = stem.isEmpty ? 'proof-photo' : stem;
  return '$safeStem$extension';
}

Future<Uint8List> rotateProofPhotoClockwise(Uint8List bytes) async {
  final ui.Image source = await _decodeImage(bytes);
  try {
    final double scale = _editingScale(source.width, source.height);
    final int scaledWidth = math.max(1, (source.width * scale).round());
    final int scaledHeight = math.max(1, (source.height * scale).round());
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.translate(scaledHeight.toDouble(), 0);
    canvas.rotate(math.pi / 2);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(
        0,
        0,
        source.width.toDouble(),
        source.height.toDouble(),
      ),
      Rect.fromLTWH(
        0,
        0,
        scaledWidth.toDouble(),
        scaledHeight.toDouble(),
      ),
      Paint()..filterQuality = FilterQuality.high,
    );
    final ui.Image result = await recorder.endRecording().toImage(
          scaledHeight,
          scaledWidth,
        );
    try {
      return await _encodePng(result);
    } finally {
      result.dispose();
    }
  } finally {
    source.dispose();
  }
}

Future<Uint8List> cropProofPhotoSquare(Uint8List bytes) async {
  final ui.Image source = await _decodeImage(bytes);
  try {
    final int sourceSide = math.min(source.width, source.height);
    final int outputSide = math.min(
      sourceSide,
      _maximumEditedImageDimension,
    );
    final double left = (source.width - sourceSide) / 2;
    final double top = (source.height - sourceSide) / 2;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(
        left,
        top,
        sourceSide.toDouble(),
        sourceSide.toDouble(),
      ),
      Rect.fromLTWH(
        0,
        0,
        outputSide.toDouble(),
        outputSide.toDouble(),
      ),
      Paint()..filterQuality = FilterQuality.high,
    );
    final ui.Image result = await recorder.endRecording().toImage(
          outputSide,
          outputSide,
        );
    try {
      return await _encodePng(result);
    } finally {
      result.dispose();
    }
  } finally {
    source.dispose();
  }
}

Future<Uint8List> addProofTextOverlay(
  Uint8List bytes,
  String text,
) async {
  final String normalized = text.trim();
  if (normalized.isEmpty) {
    return bytes;
  }

  final ui.Image source = await _decodeImage(bytes);
  try {
    final double scale = _editingScale(source.width, source.height);
    final int outputWidth = math.max(1, (source.width * scale).round());
    final int outputHeight = math.max(1, (source.height * scale).round());
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(
        0,
        0,
        source.width.toDouble(),
        source.height.toDouble(),
      ),
      Rect.fromLTWH(
        0,
        0,
        outputWidth.toDouble(),
        outputHeight.toDouble(),
      ),
      Paint()..filterQuality = FilterQuality.high,
    );

    final double horizontalPadding = math.max(18.0, outputWidth * 0.035);
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: normalized,
        style: TextStyle(
          color: Colors.white,
          fontSize: math.max(22.0, outputWidth * 0.055),
          fontWeight: FontWeight.w800,
          shadows: const <Shadow>[
            Shadow(color: Colors.black87, blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 4,
      ellipsis: '…',
      textAlign: TextAlign.center,
    )..layout(maxWidth: outputWidth - (horizontalPadding * 2));

    final double verticalPadding = math.max(12.0, outputHeight * 0.02);
    final double top = outputHeight - painter.height - (verticalPadding * 2);
    final Rect background = Rect.fromLTWH(
      horizontalPadding / 2,
      math.max(0.0, top),
      outputWidth - horizontalPadding,
      painter.height + (verticalPadding * 2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(background, const Radius.circular(18)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    painter.paint(
      canvas,
      Offset(
        (outputWidth - painter.width) / 2,
        math.max(verticalPadding, top + verticalPadding),
      ),
    );

    final ui.Image result = await recorder.endRecording().toImage(
          outputWidth,
          outputHeight,
        );
    try {
      return await _encodePng(result);
    } finally {
      result.dispose();
    }
  } finally {
    source.dispose();
  }
}

Future<Uint8List> composeProofCover(
  String layoutCode,
  List<Uint8List> photos,
) async {
  final int required = ProofLayoutCodes.requiredPhotoCount(layoutCode);
  if (photos.length != required) {
    throw ArgumentError(
      'The $layoutCode layout requires exactly $required photos.',
    );
  }

  const int canvasSize = 1080;
  const double gap = 8;
  final List<ui.Image> images = <ui.Image>[];
  try {
    for (final Uint8List photo in photos) {
      images.add(await _decodeImage(photo));
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.toDouble(), canvasSize.toDouble()),
      Paint()..color = const Color(0xFFF3EFFA),
    );

    final List<Rect> slots = proofLayoutRects(
      layoutCode,
      Size(canvasSize.toDouble(), canvasSize.toDouble()),
      gap: gap,
    );
    for (var index = 0; index < images.length; index++) {
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(slots[index], const Radius.circular(14)),
      );
      paintImage(
        canvas: canvas,
        rect: slots[index],
        image: images[index],
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
      canvas.restore();
    }

    final ui.Image result = await recorder.endRecording().toImage(
          canvasSize,
          canvasSize,
        );
    try {
      return await _encodePng(result);
    } finally {
      result.dispose();
    }
  } finally {
    for (final ui.Image image in images) {
      image.dispose();
    }
  }
}

List<Rect> proofLayoutRects(
  String layoutCode,
  Size size, {
  double gap = 6,
}) {
  final double width = size.width;
  final double height = size.height;
  final double halfWidth = (width - gap) / 2;
  final double halfHeight = (height - gap) / 2;

  return switch (layoutCode) {
    ProofLayoutCodes.single => <Rect>[Rect.fromLTWH(0, 0, width, height)],
    ProofLayoutCodes.twoVertical => <Rect>[
        Rect.fromLTWH(0, 0, halfWidth, height),
        Rect.fromLTWH(halfWidth + gap, 0, halfWidth, height),
      ],
    ProofLayoutCodes.twoHorizontal => <Rect>[
        Rect.fromLTWH(0, 0, width, halfHeight),
        Rect.fromLTWH(0, halfHeight + gap, width, halfHeight),
      ],
    ProofLayoutCodes.threeGrid => <Rect>[
        Rect.fromLTWH(0, 0, halfWidth, height),
        Rect.fromLTWH(halfWidth + gap, 0, halfWidth, halfHeight),
        Rect.fromLTWH(
          halfWidth + gap,
          halfHeight + gap,
          halfWidth,
          halfHeight,
        ),
      ],
    ProofLayoutCodes.fourGrid => <Rect>[
        Rect.fromLTWH(0, 0, halfWidth, halfHeight),
        Rect.fromLTWH(halfWidth + gap, 0, halfWidth, halfHeight),
        Rect.fromLTWH(0, halfHeight + gap, halfWidth, halfHeight),
        Rect.fromLTWH(
          halfWidth + gap,
          halfHeight + gap,
          halfWidth,
          halfHeight,
        ),
      ],
    _ => throw ArgumentError.value(
        layoutCode,
        'layoutCode',
        'Unsupported proof layout.',
      ),
  };
}

double _editingScale(int width, int height) {
  final int largestDimension = math.max(width, height);
  if (largestDimension <= _maximumEditedImageDimension) {
    return 1;
  }
  return _maximumEditedImageDimension / largestDimension;
}

Future<ui.Image> _decodeImage(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  try {
    final ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _encodePng(ui.Image image) async {
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) {
    throw StateError('The edited proof image could not be encoded.');
  }
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

bool _matchesJpeg(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xFF &&
    bytes[1] == 0xD8 &&
    bytes[2] == 0xFF;

bool _matchesPng(Uint8List bytes) =>
    bytes.length >= 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47 &&
    bytes[4] == 0x0D &&
    bytes[5] == 0x0A &&
    bytes[6] == 0x1A &&
    bytes[7] == 0x0A;

bool _matchesWebp(Uint8List bytes) =>
    bytes.length >= 12 &&
    bytes[0] == 0x52 &&
    bytes[1] == 0x49 &&
    bytes[2] == 0x46 &&
    bytes[3] == 0x46 &&
    bytes[8] == 0x57 &&
    bytes[9] == 0x45 &&
    bytes[10] == 0x42 &&
    bytes[11] == 0x50;
