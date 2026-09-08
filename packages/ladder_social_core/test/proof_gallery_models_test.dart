import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('proof gallery parses layout and ordered items', () {
    final ProofGallery gallery = ProofGallery.fromJson(<String, dynamic>{
      'taskCompletionId': 'completion-id',
      'layoutCode': 'two-vertical',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'photo-one',
          'url': '/api/proof-galleries/items/photo-one',
          'contentType': 'image/png',
          'orderIndex': 0,
          'layoutSlot': 0,
        },
        <String, dynamic>{
          'id': 'photo-two',
          'url': '/api/proof-galleries/items/photo-two',
          'contentType': 'image/png',
          'orderIndex': 1,
          'layoutSlot': 1,
        },
      ],
    });

    expect(gallery.layoutCode, ProofLayoutCodes.twoVertical);
    expect(gallery.items, hasLength(2));
    expect(gallery.items.first.orderIndex, 0);
    expect(gallery.items.last.layoutSlot, 1);
  });

  test('proof layout codes require the expected number of photos', () {
    expect(ProofLayoutCodes.requiredPhotoCount(ProofLayoutCodes.single), 1);
    expect(
      ProofLayoutCodes.requiredPhotoCount(ProofLayoutCodes.twoVertical),
      2,
    );
    expect(
      ProofLayoutCodes.requiredPhotoCount(ProofLayoutCodes.twoHorizontal),
      2,
    );
    expect(ProofLayoutCodes.requiredPhotoCount(ProofLayoutCodes.threeGrid), 3);
    expect(ProofLayoutCodes.requiredPhotoCount(ProofLayoutCodes.fourGrid), 4);
  });
}
