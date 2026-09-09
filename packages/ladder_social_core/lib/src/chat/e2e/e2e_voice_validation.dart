import 'dart:typed_data';

import 'package:ladder_social_core/src/chat/e2e/e2e_crypto_models.dart';

final class E2EVoiceValidationException implements Exception {
  const E2EVoiceValidationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

enum E2EVoiceFormat {
  m4a('.m4a'),
  aacAdts('.aac');

  const E2EVoiceFormat(this.fileExtension);

  final String fileExtension;
}

abstract final class E2EVoiceValidator {
  static const int minimumDurationMilliseconds = 300;
  static const int maximumDurationMilliseconds = 5 * 60 * 1000;
  static const int minimumFileBytes = 16;

  static E2EVoiceFormat validate({
    required List<int> bytes,
    required int durationMilliseconds,
  }) {
    validateDuration(durationMilliseconds);
    if (bytes.length < minimumFileBytes) {
      throw const E2EVoiceValidationException(
        'The recorded voice message is empty or incomplete.',
      );
    }
    if (bytes.length > E2ECryptoConstants.maximumPlainMediaBytes) {
      throw E2EVoiceValidationException(
        'The recorded voice message is too large. The maximum clear media '
        'size is ${E2ECryptoConstants.maximumPlainMediaBytes ~/ (1024 * 1024)} MiB.',
      );
    }

    final Uint8List normalized = Uint8List.fromList(bytes);
    if (_hasIsoBaseMediaSignature(normalized)) {
      return E2EVoiceFormat.m4a;
    }
    if (_hasAacAdtsSignature(normalized)) {
      return E2EVoiceFormat.aacAdts;
    }

    throw const E2EVoiceValidationException(
      'The recorded voice message is not a supported AAC/M4A audio file.',
    );
  }

  static void validateDuration(int durationMilliseconds) {
    if (durationMilliseconds < minimumDurationMilliseconds) {
      throw const E2EVoiceValidationException(
        'Hold the microphone a little longer. Voice messages must be at '
        'least 0.3 seconds long.',
      );
    }
    if (durationMilliseconds > maximumDurationMilliseconds) {
      throw const E2EVoiceValidationException(
        'Voice messages may be at most 5 minutes long.',
      );
    }
  }

  static bool _hasIsoBaseMediaSignature(Uint8List bytes) =>
      bytes.length >= 12 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70;

  static bool _hasAacAdtsSignature(Uint8List bytes) =>
      bytes.length >= 7 && bytes[0] == 0xff && (bytes[1] & 0xf0) == 0xf0;
}
