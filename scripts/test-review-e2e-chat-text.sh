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

printf '\n[1/9] Resolving shared package dependencies\n'
(
  cd "$CORE_DIR"
  flutter pub get
)

printf '\n[2/9] Resolving mobile dependencies\n'
(
  cd "$MOBILE_DIR"
  flutter pub get
)

printf '\n[3/9] Resolving admin dependencies after shared-package changes\n'
(
  cd "$ADMIN_DIR"
  flutter pub get
)

printf '\n[4/9] Checking Dart formatting\n'
dart format \
  --output=none \
  --set-exit-if-changed \
  "$CORE_DIR/lib/ladder_social_core.dart" \
  "$CORE_DIR/lib/src/chat/chat_models.dart" \
  "$CORE_DIR/lib/src/chat/chat_repository.dart" \
  "$CORE_DIR/lib/src/chat/e2e" \
  "$CORE_DIR/test/application_feature_models_test.dart" \
  "$CORE_DIR/test/chat_models_test.dart" \
  "$CORE_DIR/test/e2e_chat_coordinator_test.dart" \
  "$MOBILE_DIR/lib/src/core/providers/core_providers.dart" \
  "$MOBILE_DIR/lib/src/features/auth/presentation/authenticated_home_screen.dart" \
  "$MOBILE_DIR/lib/src/features/chat/presentation/chat_screen.dart"

printf '\n[5/9] Running shared-package analyzer\n'
(
  cd "$CORE_DIR"
  flutter analyze --no-pub
)

printf '\n[6/9] Running mobile analyzer\n'
(
  cd "$MOBILE_DIR"
  flutter analyze --no-pub
)

printf '\n[7/9] Running admin analyzer after shared-package changes\n'
(
  cd "$ADMIN_DIR"
  flutter analyze --no-pub
)

printf '\n[8/9] Running focused E2E Text and cryptography tests\n'
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

printf '\n[9/9] Checking E2E Text source contract\n'
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
repository = (root / 'packages/ladder_social_core/lib/src/chat/chat_repository.dart').read_text()
coordinator = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_chat_coordinator.dart').read_text()
models = (root / 'packages/ladder_social_core/lib/src/chat/chat_models.dart').read_text()
screen = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/chat_screen.dart').read_text()
home = (root / 'apps/ladder_social_mobile/lib/src/features/auth/presentation/authenticated_home_screen.dart').read_text()
backend_rules = (root / 'src/LadderSocial.Application/Features/Chat/E2EChatRules.cs').read_text()
exports = (root / 'packages/ladder_social_core/lib/ladder_social_core.dart').read_text()
docs = (root / 'docs/e2e-chat-arhitektura.md').read_text()

checks = {
    'repository uses the E2E message endpoint': '/messages/e2e' in repository,
    'repository sends ciphertext instead of a content field': all(
        token in repository
        for token in (
            "'encryptedContentBase64'",
            "'contentNonceBase64'",
            "'senderDeviceKeyId'",
        )
    ),
    'coordinator performs local text encryption': '_cryptoService.encryptText(' in coordinator,
    'coordinator performs local text decryption': '_cryptoService.decryptText(' in coordinator,
    'coordinator verifies TOFU peer keys': '_keyTrustStore.verifyOrTrust(' in coordinator,
    'coordinator rejects non-participant device keys': 'device key for a non-participant' in coordinator,
    'coordinator rejects attachment metadata on E2E Text': '_hasAttachmentMetadata(message)' in coordinator,
    'chat screen sends text through E2E coordinator': '.sendEncryptedText(' in screen,
    'chat screen never sends the typed text to the legacy repository': not re.search(
        r'sendMessage\s*\([^)]*content\s*:\s*text', screen, re.DOTALL
    ),
    'device registration starts after authentication': 'ensureDeviceRegistered(userId: userId)' in home,
    'message model distinguishes legacy and E2E versions': all(
        token in models
        for token in ('legacyPlaintext = 0', 'clientE2E = 1', 'visibleContent')
    ),
    'message parser rejects server plaintext for E2E responses': (
        'An E2E message response may not contain plaintext content.' in models
    ),
    'backend E2E factory keeps Message.Content null': 'Content = null' in backend_rules,
    'new coordinator is exported': "export 'src/chat/e2e/e2e_chat_coordinator.dart';" in exports,
    'architecture document states E2E Text status': 'produkcijski E2E Text tok' in docs,
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

printf '\nE2E chat Text integration checks completed successfully.\n'
