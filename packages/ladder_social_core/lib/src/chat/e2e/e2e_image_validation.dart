import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_models.dart';

enum E2EImageFormat {
  jpeg(mimeType: 'image/jpeg', fileExtension: '.jpg'),
  png(mimeType: 'image/png', fileExtension: '.png'),
  webp(mimeType: 'image/webp', fileExtension: '.webp');

  const E2EImageFormat({
    required this.mimeType,
    required this.fileExtension,
  });

  final String mimeType;
  final String fileExtension;
}

final class E2EImageValidationException implements Exception {
  const E2EImageValidationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract final class E2EImageValidator {
  static E2EImageFormat validate(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const E2EImageValidationException(
        'Select a non-empty image file.',
      );
    }
    if (bytes.length > E2ECryptoConstants.maximumPlainMediaBytes) {
      throw E2EImageValidationException(
        'The selected image is too large. The encrypted upload limit is '
        '${E2ECryptoConstants.maximumEncryptedMediaBytes ~/ (1024 * 1024)} MiB.',
      );
    }
    if (bytes.any((int value) => value < 0 || value > 255)) {
      throw const E2EImageValidationException(
        'The selected image contains invalid byte values.',
      );
    }

    if (_startsWith(bytes, const <int>[0xff, 0xd8, 0xff])) {
      return E2EImageFormat.jpeg;
    }
    if (_startsWith(
      bytes,
      const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    )) {
      return E2EImageFormat.png;
    }
    if (bytes.length >= 12 &&
        _asciiAt(bytes, 0, 'RIFF') &&
        _asciiAt(bytes, 8, 'WEBP')) {
      return E2EImageFormat.webp;
    }

    throw const E2EImageValidationException(
      'Only JPEG, PNG, and WebP images are supported. The file signature '
      'does not match a supported image format.',
    );
  }

  static bool _startsWith(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) {
      return false;
    }
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) {
        return false;
      }
    }
    return true;
  }

  static bool _asciiAt(List<int> bytes, int offset, String value) {
    if (bytes.length < offset + value.length) {
      return false;
    }
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) {
        return false;
      }
    }
    return true;
  }
}
