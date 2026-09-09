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

printf '\n[2/11] Resolving mobile voice dependencies\n'
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
  "$MOBILE_DIR/lib/src/features/chat/presentation/voice_recording_service.dart" \
  "$MOBILE_DIR/test/encrypted_image_payload_test.dart" \
  "$MOBILE_DIR/test/encrypted_voice_payload_test.dart"

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

printf '\n[8/11] Running focused E2E Voice, Image, Text, and cryptography tests\n'
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

printf '\n[9/11] Running encrypted media widget tests\n'
(
  cd "$MOBILE_DIR"
  flutter test \
    --no-pub \
    --reporter expanded \
    test/encrypted_image_payload_test.dart \
    test/encrypted_voice_payload_test.dart
)

printf '\n[10/11] Checking Android microphone configuration\n'
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
pubspec = (root / 'apps/ladder_social_mobile/pubspec.yaml').read_text()
gradle = (root / 'apps/ladder_social_mobile/android/app/build.gradle.kts').read_text()
manifest = (root / 'apps/ladder_social_mobile/android/app/src/main/AndroidManifest.xml').read_text()

checks = {
    'record dependency is pinned to the compatible major version': 'record: ^6.2.1' in pubspec,
    'just_audio dependency is present': 'just_audio: ^0.10.6' in pubspec,
    'path_provider dependency is present': 'path_provider: ^2.1.5' in pubspec,
    'Android minSdk supports the recorder plugin': (
        'minSdk = 23' in gradle or 'minSdk = 24' in gradle
    ),
    'Android manifest requests microphone permission': (
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

printf '\n[11/11] Checking E2E Voice source contract and static invariants\n'
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
repository = (root / 'packages/ladder_social_core/lib/src/chat/chat_repository.dart').read_text()
coordinator = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_chat_coordinator.dart').read_text()
transport = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_chat_transport.dart').read_text()
crypto = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_crypto_service.dart').read_text()
validator = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_voice_validation.dart').read_text()
screen = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/chat_screen.dart').read_text()
recorder = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/voice_recording_service.dart').read_text()
voice_widget = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/encrypted_voice_payload.dart').read_text()
exports = (root / 'packages/ladder_social_core/lib/ladder_social_core.dart').read_text()
docs = (root / 'docs/e2e-chat-arhitektura.md').read_text()
backend_rules = (root / 'src/LadderSocial.Application/Features/Chat/E2EChatRules.cs').read_text()

checks = {
    'voice validator enforces signature size and duration': all(
        token in validator
        for token in (
            'E2EVoiceFormat.m4a',
            'E2EVoiceFormat.aacAdts',
            'minimumDurationMilliseconds',
            'maximumDurationMilliseconds',
            'maximumPlainMediaBytes',
        )
    ),
    'crypto authenticates voice duration as associated data': all(
        token in crypto
        for token in (
            'durationMilliseconds',
            "'/duration/$durationMilliseconds'",
            '_validateMediaDuration',
        )
    ),
    'transport exposes upload progress without plaintext': all(
        token in transport
        for token in ('E2ETransferProgress', 'onUploadProgress')
    ),
    'repository uploads encrypted voice bytes as octet-stream': all(
        token in repository
        for token in (
            'sendEncryptedMedia',
            'payload.cipherTextWithMac',
            'attachmentNonceBase64',
            'durationMilliseconds',
            'onSendProgress: onUploadProgress',
            'E2ECryptoConstants.encryptedMediaContentType',
        )
    ),
    'coordinator validates encrypts and sends voice locally': all(
        token in coordinator
        for token in (
            'Future<ChatMessage> sendEncryptedVoice(',
            'E2EVoiceValidator.validate(',
            'type: E2EPrivateMessageType.voice',
            'durationMilliseconds: durationMilliseconds',
            'onUploadProgress: onUploadProgress',
        )
    ),
    'coordinator downloads authenticates and validates voice locally': all(
        token in coordinator
        for token in (
            'Future<Uint8List> downloadAndDecryptVoice(',
            '_transport.downloadEncryptedAttachment(',
            '_cryptoService.decryptMedia(',
            '_validateEncryptedVoiceMessage',
        )
    ),
    'recorder supports permission record stop cancel and measured duration': all(
        token in recorder
        for token in (
            'hasPermission()',
            'AudioEncoder.aacLc',
            '_recorder.start(',
            '_recorder.stop()',
            '_recorder.cancel()',
            '_resolveDurationMilliseconds',
        )
    ),
    'chat UI exposes record stop cancel preview and upload progress': all(
        token in screen
        for token in (
            '_startVoiceRecording',
            '_stopVoiceRecording',
            '_cancelVoiceRecording',
            'VoiceDraftPreview(',
            '_MediaUploadProgress(',
            "label: 'voice message'",
            '.sendEncryptedVoice(',
            'EncryptedVoicePayload(',
        )
    ),
    'voice playback supports authenticated loading retry play pause and seek': all(
        token in voice_widget
        for token in (
            'Downloading and authenticating encrypted voice...',
            "label: const Text('Retry')",
            'Play voice message',
            'Pause voice message',
            '_player.seek(',
            'attachmentDurationMilliseconds',
        )
    ),
    'voice validator is exported by shared package': (
        "export 'src/chat/e2e/e2e_voice_validation.dart';" in exports
    ),
    'production chat has no legacy submit call': '.sendMessage(' not in screen,
    'backend still stores E2E plaintext content as null': 'Content = null' in backend_rules,
    'architecture document records the production E2E Voice flow': (
        'produkcijski E2E Voice tok' in docs
        and 'Flutter E2E Voice orkestracija' in docs
    ),
    'voice tests include roundtrip tamper duration and local validation': all(
        phrase in (root / 'packages/ladder_social_core/test/e2e_chat_coordinator_test.dart').read_text()
        for phrase in (
            'encrypted voice roundtrip authenticates duration and hides clear bytes',
            'tampered encrypted voice bytes fail authentication',
            'changed encrypted voice duration fails authentication',
            'invalid local voice is rejected before crypto or network work',
        )
    ),
    'private recording bytes are not sent as a text field': not re.search(
        r"(?:clearVoiceBytes|voiceBytes).*FormData", repository, re.DOTALL
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

printf '\nE2E chat Voice integration checks completed successfully.\n'
