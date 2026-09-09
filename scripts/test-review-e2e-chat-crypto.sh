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

printf '\n[1/8] Resolving shared package dependencies\n'
(
  cd "$CORE_DIR"
  flutter pub get
)

printf '\n[2/8] Resolving mobile dependencies\n'
(
  cd "$MOBILE_DIR"
  flutter pub get
)

printf '\n[3/8] Resolving admin dependencies after shared-package change\n'
(
  cd "$ADMIN_DIR"
  flutter pub get
)

printf '\n[4/8] Checking Dart formatting\n'
dart format \
  --output=none \
  --set-exit-if-changed \
  "$CORE_DIR/lib/ladder_social_core.dart" \
  "$CORE_DIR/lib/src/chat/chat_models.dart" \
  "$CORE_DIR/lib/src/chat/e2e" \
  "$CORE_DIR/test/e2e_crypto_service_test.dart" \
  "$MOBILE_DIR/lib/src/core/providers/core_providers.dart"

printf '\n[5/8] Running shared-package analyzer\n'
(
  cd "$CORE_DIR"
  flutter analyze --no-pub
)

printf '\n[6/8] Running mobile analyzer\n'
(
  cd "$MOBILE_DIR"
  flutter analyze --no-pub
)

printf '\n[7/8] Running admin analyzer after shared-package change\n'
(
  cd "$ADMIN_DIR"
  flutter analyze --no-pub
)

printf '\n[8/8] Running focused E2E cryptography tests\n'
(
  cd "$CORE_DIR"
  flutter test --no-pub test/e2e_crypto_service_test.dart
)

python3 "$ROOT_DIR/scripts/static-source-check.py"

git -C "$ROOT_DIR" diff --check

printf '\nE2E chat Flutter cryptography checks completed successfully.\n'
