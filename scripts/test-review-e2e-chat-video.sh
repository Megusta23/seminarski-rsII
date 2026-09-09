#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$ROOT_DIR/packages/ladder_social_core"
MOBILE_DIR="$ROOT_DIR/apps/ladder_social_mobile"
ADMIN_DIR="$ROOT_DIR/apps/ladder_social_admin"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

command -v flutter >/dev/null 2>&1 || fail 'Flutter SDK is not available in PATH.'
command -v dart >/dev/null 2>&1 || fail 'Dart SDK is not available in PATH.'
command -v python3 >/dev/null 2>&1 || fail 'python3 is not available in PATH.'

printf '\n[1/11] Resolving shared package dependencies\n'
(
  cd "$CORE_DIR"
  flutter pub get
)

printf '\n[2/11] Resolving mobile video dependencies\n'
(
  cd "$MOBILE_DIR"
  flutter pub get
)

printf '\n[3/11] Resolving admin dependencies after shared-package changes\n'
(
  cd "$ADMIN_DIR"
  flutter pub get
)

printf '\n[4/11] Checking Dart formatting\n'
dart format \
  --output=none \
  --set-exit-if-changed \
  "$CORE_DIR/lib/ladder_social_core.dart" \
  "$CORE_DIR/lib/src/chat/chat_repository.dart" \
  "$CORE_DIR/lib/src/chat/e2e" \
  "$CORE_DIR/test/e2e_crypto_service_test.dart" \
  "$CORE_DIR/test/e2e_chat_coordinator_test.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/chat_screen.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/encrypted_image_payload.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/encrypted_voice_payload.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/encrypted_video_payload.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/voice_recording_service.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/video_selection_service.dart" \
  "$MOBILE_DIR/test/encrypted_image_payload_test.dart" \
  "$MOBILE_DIR/test/encrypted_voice_payload_test.dart" \
  "$MOBILE_DIR/test/encrypted_video_payload_test.dart" \
  "$MOBILE_DIR/test/video_selection_service_test.dart"

printf '\n[5/11] Running shared-package analyzer\n'
(
  cd "$CORE_DIR"
  flutter analyze --no-pub
)

printf '\n[6/11] Running mobile analyzer\n'
(
  cd "$MOBILE_DIR"
  flutter analyze --no-pub
)

printf '\n[7/11] Running admin analyzer after shared-package changes\n'
(
  cd "$ADMIN_DIR"
  flutter analyze --no-pub
)

printf '\n[8/11] Running focused E2E Video, Voice, Image, Text, and cryptography tests\n'
(
  cd "$CORE_DIR"
  flutter test \
    --no-pub \
    --reporter expanded \
    test/e2e_crypto_service_test.dart \
    test/e2e_chat_coordinator_test.dart \
    test/chat_models_test.dart \
    test/application_feature_models_test.dart
)

printf '\n[9/11] Running encrypted media and video-selection widget tests\n'
(
  cd "$MOBILE_DIR"
  flutter test \
    --no-pub \
    --reporter expanded \
    test/encrypted_image_payload_test.dart \
    test/encrypted_voice_payload_test.dart \
    test/encrypted_video_payload_test.dart \
    test/video_selection_service_test.dart
)

printf '\n[10/11] Checking Android and video dependency configuration\n'
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
pubspec = (root / 'apps/ladder_social_mobile/pubspec.yaml').read_text()
gradle = (root / 'apps/ladder_social_mobile/android/app/build.gradle.kts').read_text()
manifest = (root / 'apps/ladder_social_mobile/android/app/src/main/AndroidManifest.xml').read_text()

checks = {
    'image_picker dependency remains available for camera and gallery selection': (
        'image_picker: ^1.2.3' in pubspec
    ),
    'video_player dependency is compatible with the project Dart floor': (
        'video_player: ^2.10.0' in pubspec
    ),
    'path_provider remains available for private temporary video files': (
        'path_provider: ^2.1.5' in pubspec
    ),
    'Android minSdk satisfies the current image picker support floor': (
        'minSdk = 24' in gradle
    ),
    'Android keeps network access for API and media transfers': (
        'android.permission.INTERNET' in manifest
    ),
    'Android microphone permission remains available for voice and recorded video': (
        'android.permission.RECORD_AUDIO' in manifest
    ),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    for name in failed:
        print(f'FAIL: {name}', file=sys.stderr)
    raise SystemExit(1)

for name in checks:
    print(f'PASS: {name}')
PY

printf '\n[11/11] Checking E2E Video source contract and static invariants\n'
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
repository = (root / 'packages/ladder_social_core/lib/src/chat/chat_repository.dart').read_text()
coordinator = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_chat_coordinator.dart').read_text()
transport = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_chat_transport.dart').read_text()
crypto = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_crypto_service.dart').read_text()
validator = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_video_validation.dart').read_text()
screen = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/chat_screen.dart').read_text()
selector = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/video_selection_service.dart').read_text()
video_widget = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/encrypted_video_payload.dart').read_text()
exports = (root / 'packages/ladder_social_core/lib/ladder_social_core.dart').read_text()
docs = (root / 'docs/e2e-chat-arhitektura.md').read_text()
backend_rules = (root / 'src/LadderSocial.Application/Features/Chat/E2EChatRules.cs').read_text()
backend_service = (root / 'src/LadderSocial.Infrastructure/Services/ChatService.cs').read_text()
coordinator_tests = (root / 'packages/ladder_social_core/test/e2e_chat_coordinator_test.dart').read_text()
widget_tests = (root / 'apps/ladder_social_mobile/test/encrypted_video_payload_test.dart').read_text()
selection_tests = (root / 'apps/ladder_social_mobile/test/video_selection_service_test.dart').read_text()

checks = {
    'video validator enforces MP4 MOV WebM signatures size and duration': all(
        token in validator
        for token in (
            'E2EVideoFormat.mp4',
            'E2EVideoFormat.quickTime',
            'E2EVideoFormat.webm',
            'minimumDurationMilliseconds',
            'maximumDurationMilliseconds',
            'maximumPlainMediaBytes',
            '_hasIsoBaseMediaSignature',
            '_hasEbmlSignature',
        )
    ),
    'video selection offers camera or gallery and validates decoded duration': all(
        token in selector
        for token in (
            'ImagePicker().pickVideo(',
            'required ImageSource source',
            'maxDuration:',
            'VideoPlayerController.file(',
            'E2EVideoValidator.validate(',
            'getTemporaryDirectory()',
        )
    ),
    'crypto authenticates video type and duration as associated data': all(
        token in crypto
        for token in (
            'durationMilliseconds',
            "'/duration/$durationMilliseconds'",
            '_validateMediaDuration',
            'type.wireValue',
        )
    ),
    'transport exposes encrypted media upload and ciphertext download': all(
        token in transport
        for token in (
            'sendEncryptedMedia',
            'E2ETransferProgress',
            'downloadEncryptedAttachment',
        )
    ),
    'repository uploads only encrypted video bytes as octet-stream': all(
        token in repository
        for token in (
            'payload.cipherTextWithMac',
            'attachmentNonceBase64',
            'durationMilliseconds',
            'onSendProgress: onUploadProgress',
            'E2ECryptoConstants.encryptedMediaContentType',
            "filename: 'encrypted-${type.name}.bin'",
        )
    ),
    'coordinator validates encrypts and sends video locally': all(
        token in coordinator
        for token in (
            'Future<ChatMessage> sendEncryptedVideo(',
            'E2EVideoValidator.validate(',
            'type: E2EPrivateMessageType.video',
            'durationMilliseconds: durationMilliseconds',
            'onUploadProgress: onUploadProgress',
        )
    ),
    'coordinator downloads authenticates decrypts and revalidates video locally': all(
        token in coordinator
        for token in (
            'Future<Uint8List> downloadAndDecryptVideo(',
            '_validateEncryptedVideoMessage',
            '_transport.downloadEncryptedAttachment(',
            '_cryptoService.decryptMedia(',
            'final Uint8List clearVideo',
        )
    ),
    'chat UI offers gallery and camera preview send progress and received playback': all(
        token in screen
        for token in (
            'Video from gallery',
            'Record video',
            '_pickVideo(ImageSource.gallery)',
            '_pickVideo(ImageSource.camera)',
            'VideoDraftPreview(',
            "label: 'video message'",
            '.sendEncryptedVideo(',
            'EncryptedVideoPayload(',
            '.downloadAndDecryptVideo(',
        )
    ),
    'video playback waits for authenticated bytes and supports retry play pause seek': all(
        token in video_widget
        for token in (
            'Downloading and authenticating encrypted video...',
            "label: const Text('Retry')",
            'Play video',
            'Pause video',
            'controller.seek(',
            'attachmentDurationMilliseconds',
            'E2EVideoValidator.durationsMatch(',
            'deleteWhenDone',
        )
    ),
    'video validator is exported by the shared package': (
        "export 'src/chat/e2e/e2e_video_validation.dart';" in exports
    ),
    'production chat contains no legacy private-media submit call': (
        '.sendMessage(' not in screen
    ),
    'backend keeps E2E message plaintext null and generic video notification': (
        'Content = null' in backend_rules
        and 'sent you a video.' in backend_rules
    ),
    'backend encrypted storage remains generic and ciphertext-only': all(
        token in backend_service
        for token in (
            'SaveEncryptedAsync(',
            'message-ciphertext/',
            'CreateEncryptedAttachment(',
        )
    ),
    'architecture document records production E2E Video and final-smoke boundary': all(
        token in docs
        for token in (
            'produkcijski E2E Video tok',
            'Flutter E2E Video orkestracija',
            'scripts/test-review-e2e-chat-video.sh',
            'scripts/test-review-e2e-multimedia-chat.sh',
            'Legacy plaintext write endpoint je uklonjen',
        )
    ),
    'core video tests cover format roundtrip tamper duration and validation': all(
        phrase in coordinator_tests
        for phrase in (
            'video validation accepts MP4 MOV and WebM magic-byte signatures',
            'encrypted video roundtrip authenticates duration and hides clear bytes',
            'tampered encrypted video bytes fail authentication',
            'changed encrypted video duration fails authentication',
            'invalid local video is rejected before crypto or network work',
        )
    ),
    'widget tests prohibit playback before authentication and exercise retry': all(
        phrase in widget_tests
        for phrase in (
            'encrypted video stays unavailable until authenticated bytes are loaded',
            'encrypted video failure exposes retry and reloads ciphertext',
            'decoded video duration mismatch is rejected before playback',
        )
    ),
    'selection tests cover camera gallery cancel and invalid signature': all(
        phrase in selection_tests
        for phrase in (
            'camera or gallery video is validated before a draft is returned',
            'cancelled video picker creates no draft',
            'invalid video signature is rejected before duration probing',
        )
    ),
    'clear video bytes are not added to multipart form fields': not re.search(
        r'(?:clearVideoBytes|videoBytes).*FormData', repository, re.DOTALL
    ),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    for name in failed:
        print(f'FAIL: {name}', file=sys.stderr)
    raise SystemExit(1)

for name in checks:
    print(f'PASS: {name}')
PY

python3 "$ROOT_DIR/scripts/static-source-check.py"
git -C "$ROOT_DIR" diff --check
bash -n "$ROOT_DIR/scripts/test-review-e2e-chat-voice.sh"

printf '\nE2E chat Video integration checks completed successfully.\n'
