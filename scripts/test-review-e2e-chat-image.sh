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

printf '\n[1/10] Resolving shared package dependencies\n'
(
  cd "$CORE_DIR"
  flutter pub get
)

printf '\n[2/10] Resolving mobile dependencies\n'
(
  cd "$MOBILE_DIR"
  flutter pub get
)

printf '\n[3/10] Resolving admin dependencies after shared-package changes\n'
(
  cd "$ADMIN_DIR"
  flutter pub get
)

printf '\n[4/10] Checking Dart formatting\n'
dart format \
  --output=none \
  --set-exit-if-changed \
  "$CORE_DIR/lib/ladder_social_core.dart" \
  "$CORE_DIR/lib/src/chat/chat_repository.dart" \
  "$CORE_DIR/lib/src/chat/e2e" \
  "$CORE_DIR/test/e2e_chat_coordinator_test.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/chat_screen.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/encrypted_image_payload.dart" \
  "$MOBILE_DIR/test/encrypted_image_payload_test.dart"

printf '\n[5/10] Running shared-package analyzer\n'
(
  cd "$CORE_DIR"
  flutter analyze --no-pub
)

printf '\n[6/10] Running mobile analyzer\n'
(
  cd "$MOBILE_DIR"
  flutter analyze --no-pub
)

printf '\n[7/10] Running admin analyzer after shared-package changes\n'
(
  cd "$ADMIN_DIR"
  flutter analyze --no-pub
)

printf '\n[8/10] Running focused E2E Image, Text, and cryptography tests\n'
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

printf '\n[9/10] Running encrypted-image widget tests\n'
(
  cd "$MOBILE_DIR"
  flutter test \
    --no-pub \
    --reporter expanded \
    test/encrypted_image_payload_test.dart
)

printf '\n[10/10] Checking E2E Image source contract\n'
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
repository = (root / 'packages/ladder_social_core/lib/src/chat/chat_repository.dart').read_text()
coordinator = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_chat_coordinator.dart').read_text()
transport = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_chat_transport.dart').read_text()
validator = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_image_validation.dart').read_text()
screen = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/chat_screen.dart').read_text()
image_widget = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/encrypted_image_payload.dart').read_text()
backend_rules = (root / 'src/LadderSocial.Application/Features/Chat/E2EChatRules.cs').read_text()
backend_service = (root / 'src/LadderSocial.Infrastructure/Services/ChatService.cs').read_text()
exports = (root / 'packages/ladder_social_core/lib/ladder_social_core.dart').read_text()
docs = (root / 'docs/e2e-chat-arhitektura.md').read_text()

checks = {
    'repository sends encrypted media to the E2E endpoint': all(
        token in repository
        for token in (
            'Future<ChatMessage> sendEncryptedMedia(',
            "'/api/conversations/$conversationId/messages/e2e'",
            "'attachmentNonceBase64'",
            'payload.cipherTextWithMac',
        )
    ),
    'repository labels encrypted media as generic octet-stream': (
        'E2ECryptoConstants.encryptedMediaContentType' in repository
        and "filename: 'encrypted-${type.name}.bin'" in repository
    ),
    'repository downloads raw ciphertext bytes': all(
        token in repository
        for token in (
            'Future<Uint8List> downloadEncryptedAttachment(',
            '_client.getBytes(normalizedUrl)',
        )
    ),
    'transport exposes encrypted media upload and byte download': all(
        token in transport
        for token in (
            'sendEncryptedMedia',
            'downloadEncryptedAttachment',
        )
    ),
    'coordinator validates and encrypts selected image locally': all(
        token in coordinator
        for token in (
            'Future<ChatMessage> sendEncryptedImage(',
            'E2EImageValidator.validate(localImageBytes)',
            '_cryptoService.encryptMedia(',
            'type: E2EPrivateMessageType.image',
        )
    ),
    'coordinator downloads, authenticates, and decrypts image locally': all(
        token in coordinator
        for token in (
            'Future<Uint8List> downloadAndDecryptImage(',
            '_transport.downloadEncryptedAttachment(',
            '_cryptoService.decryptMedia(',
            'E2EImageValidator.validate(clearImage)',
        )
    ),
    'coordinator validates ciphertext-only attachment metadata': all(
        token in coordinator
        for token in (
            '_validateEncryptedMediaResponse(',
            'response.content != null',
            'response.encryptedContent != null',
            'response.contentNonce != null',
            '_isExpectedAttachmentUrl',
            'uri.isAbsolute',
        )
    ),
    'image validator checks JPEG PNG and WebP signatures': all(
        token in validator
        for token in ('E2EImageFormat.jpeg', 'E2EImageFormat.png', 'E2EImageFormat.webp')
    ),
    'mobile validates actual image decoding before selection': all(
        token in screen
        for token in (
            'E2EImageValidator.validate(bytes)',
            'ui.instantiateImageCodec(bytes)',
            'await codec.getNextFrame()',
        )
    ),
    'mobile sends new images only through E2E coordinator': (
        '.sendEncryptedImage(' in screen and '.sendMessage(' not in screen
    ),
    'mobile loads received image through local E2E decryption': (
        '.downloadAndDecryptImage(' in screen
        and 'EncryptedImagePayload(' in screen
    ),
    'encrypted image widget waits for authenticated bytes': all(
        token in image_widget
        for token in (
            'FutureBuilder<Uint8List>',
            'if (snapshot.hasData)',
            'Image.memory(',
            'Downloading and authenticating encrypted image...',
            "label: const Text('Retry')",
        )
    ),
    'backend E2E message keeps plaintext content null': 'Content = null' in backend_rules,
    'backend stores encrypted attachment through encrypted storage path': all(
        token in backend_service
        for token in (
            'SaveEncryptedAsync(',
            'message-ciphertext/',
            'CreateEncryptedAttachment(',
        )
    ),
    'image validator is exported by shared package': (
        "export 'src/chat/e2e/e2e_image_validation.dart';" in exports
    ),
    'architecture document records production E2E Image flow': (
        'produkcijski E2E Image tok' in docs
        and 'Flutter E2E Image orkestracija' in docs
    ),
    'chat source contains no legacy image submit pattern': not re.search(
        r'sendMessage\s*\([^)]*attachment\s*:', screen, re.DOTALL
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

printf '\nE2E chat Image integration checks completed successfully.\n'
