import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/tasks/presentation/proof_composer.dart';

void main() {
  test('proof layouts create the expected number of bounded slots', () {
    const Size size = Size(1080, 1080);

    for (final String code in ProofLayoutCodes.values) {
      final List<Rect> slots = proofLayoutRects(code, size, gap: 8);
      expect(
        slots,
        hasLength(ProofLayoutCodes.requiredPhotoCount(code)),
        reason: code,
      );
      for (final Rect slot in slots) {
        expect(slot.left, greaterThanOrEqualTo(0), reason: code);
        expect(slot.top, greaterThanOrEqualTo(0), reason: code);
        expect(slot.right, lessThanOrEqualTo(size.width), reason: code);
        expect(slot.bottom, lessThanOrEqualTo(size.height), reason: code);
      }
    }
  });

  test('edited proof bytes use matching PNG metadata', () {
    final Uint8List jpeg = Uint8List.fromList(
      <int>[0xFF, 0xD8, 0xFF, 0x00],
    );
    final Uint8List png = Uint8List.fromList(
      <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );

    final EditableProofPhoto original = EditableProofPhoto.fromPicked(
      bytes: jpeg,
      fileName: 'camera-photo.jpg',
    );
    final EditableProofPhoto edited = original.withEditedBytes(png);

    expect(original.contentType, 'image/jpeg');
    expect(original.fileName, endsWith('.jpg'));
    expect(edited.contentType, 'image/png');
    expect(edited.fileName, endsWith('.png'));
    expect(edited.isEdited, isTrue);

    final EditableProofPhoto reset = edited.reset();
    expect(reset.contentType, 'image/jpeg');
    expect(reset.fileName, 'camera-photo.jpg');
    expect(reset.bytes, same(jpeg));
    expect(reset.isEdited, isFalse);
  });

  test('proof content type is detected from magic bytes', () {
    expect(
      proofImageContentType(
        Uint8List.fromList(
          <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
        ),
      ),
      'image/png',
    );
    expect(
      proofImageContentType(
        Uint8List.fromList(
          <int>[
            0x52,
            0x49,
            0x46,
            0x46,
            0x00,
            0x00,
            0x00,
            0x00,
            0x57,
            0x45,
            0x42,
            0x50,
          ],
        ),
      ),
      'image/webp',
    );
  });
}
