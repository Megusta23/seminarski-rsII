import 'dart:convert';

import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_models.dart';

final class E2EVideoValidationException implements Exception {
  const E2EVideoValidationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

enum E2EVideoFormat {
  mp4('.mp4'),
  quickTime('.mov'),
  webm('.webm');

  const E2EVideoFormat(this.fileExtension);

  final String fileExtension;
}

abstract final class E2EVideoValidator {
  static const int minimumDurationMilliseconds = 300;
  static const int maximumDurationMilliseconds = 2 * 60 * 1000;
  static const int minimumFileBytes = 16;

  static E2EVideoFormat validate({
    required List<int> bytes,
    required int durationMilliseconds,
  }) {
    validateDuration(durationMilliseconds);
    if (bytes.length < minimumFileBytes) {
      throw const E2EVideoValidationException(
        'The selected video is empty or incomplete.',
      );
    }
    if (bytes.length > E2ECryptoConstants.maximumPlainMediaBytes) {
      throw E2EVideoValidationException(
        'The selected video is too large. Encrypted video uploads may be at '
        'most ${E2ECryptoConstants.maximumEncryptedMediaBytes ~/ (1024 * 1024)} MiB.',
      );
    }

    return detectFormat(bytes);
  }

  static E2EVideoFormat detectFormat(List<int> bytes) {
    if (bytes.length < minimumFileBytes) {
      throw const E2EVideoValidationException(
        'The selected video is empty or incomplete.',
      );
    }

    if (_hasIsoBaseMediaSignature(bytes)) {
      final String majorBrand = ascii.decode(
        bytes.sublist(8, 12),
        allowInvalid: true,
      );
      return majorBrand == 'qt  '
          ? E2EVideoFormat.quickTime
          : E2EVideoFormat.mp4;
    }
    if (_hasEbmlSignature(bytes)) {
      return E2EVideoFormat.webm;
    }

    throw const E2EVideoValidationException(
      'The selected file is not a supported MP4, MOV, or WebM video.',
    );
  }

  static void validateDuration(int durationMilliseconds) {
    if (durationMilliseconds < minimumDurationMilliseconds) {
      throw const E2EVideoValidationException(
        'The selected video must be at least 0.3 seconds long.',
      );
    }
    if (durationMilliseconds > maximumDurationMilliseconds) {
      throw const E2EVideoValidationException(
        'Video messages may be at most 2 minutes long.',
      );
    }
  }

  static bool durationsMatch({
    required int authenticatedDurationMilliseconds,
    required int decodedDurationMilliseconds,
  }) {
    if (authenticatedDurationMilliseconds < 1 ||
        decodedDurationMilliseconds < 1) {
      return false;
    }
    final int difference =
        (authenticatedDurationMilliseconds - decodedDurationMilliseconds).abs();
    final int proportionalTolerance =
        (authenticatedDurationMilliseconds * 0.05).round();
    final int tolerance =
        proportionalTolerance > 1500 ? proportionalTolerance : 1500;
    return difference <= tolerance;
  }

  static bool _hasIsoBaseMediaSignature(List<int> bytes) =>
      bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70;

  static bool _hasEbmlSignature(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x1a &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xdf &&
      bytes[3] == 0xa3;
}
