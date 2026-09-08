import 'package:ladder_social_core/src/auth/auth_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';

abstract final class ProofLayoutCodes {
  static const String single = 'single';
  static const String twoVertical = 'two-vertical';
  static const String twoHorizontal = 'two-horizontal';
  static const String threeGrid = 'three-grid';
  static const String fourGrid = 'four-grid';

  static const List<String> values = <String>[
    single,
    twoVertical,
    twoHorizontal,
    threeGrid,
    fourGrid,
  ];

  static int requiredPhotoCount(String code) => switch (code) {
        single => 1,
        twoVertical || twoHorizontal => 2,
        threeGrid => 3,
        fourGrid => 4,
        _ => throw ArgumentError.value(code, 'code', 'Unsupported proof layout.'),
      };

  static String label(String code) => switch (code) {
        single => 'Single',
        twoVertical => 'Two vertical',
        twoHorizontal => 'Two horizontal',
        threeGrid => 'Three grid',
        fourGrid => 'Four grid',
        _ => 'Unknown',
      };
}

final class ProofGalleryItem {
  const ProofGalleryItem({
    required this.id,
    required this.url,
    required this.contentType,
    required this.orderIndex,
    required this.layoutSlot,
  });

  factory ProofGalleryItem.fromJson(Map<String, dynamic> json) {
    return ProofGalleryItem(
      id: requiredString(json, 'id'),
      url: requiredString(json, 'url'),
      contentType: requiredString(json, 'contentType'),
      orderIndex: requiredInt(json, 'orderIndex'),
      layoutSlot: requiredInt(json, 'layoutSlot'),
    );
  }

  final String id;
  final String url;
  final String contentType;
  final int orderIndex;
  final int layoutSlot;
}

final class ProofGallery {
  const ProofGallery({
    required this.taskCompletionId,
    required this.layoutCode,
    required this.items,
  });

  factory ProofGallery.fromJson(Map<String, dynamic> json) {
    return ProofGallery(
      taskCompletionId: requiredString(json, 'taskCompletionId'),
      layoutCode: nullableString(json['layoutCode']) ?? ProofLayoutCodes.single,
      items: List<ProofGalleryItem>.unmodifiable(
        jsonList(json['items'], context: 'proof gallery items').map(
          (Object? item) => ProofGalleryItem.fromJson(
            jsonMap(item, context: 'proof gallery item'),
          ),
        ),
      ),
    );
  }

  final String taskCompletionId;
  final String layoutCode;
  final List<ProofGalleryItem> items;
}
