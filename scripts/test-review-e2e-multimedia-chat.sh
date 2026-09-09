#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

read_env() {
  local key="$1"
  sed -n "s/^${key}=//p" "$ENV_FILE" | tail -n 1
}

wait_for_api_health() {
  local health_url="$1"
  local timeout_seconds="${2:-180}"
  local delay_seconds="${3:-2}"
  local started_at="$SECONDS"
  local deadline=$((SECONDS + timeout_seconds))
  local attempt=0
  local elapsed

  while ((SECONDS < deadline)); do
    attempt=$((attempt + 1))
    if curl \
      --connect-timeout 2 \
      --max-time 5 \
      -fsS \
      "$health_url" >/dev/null 2>&1; then
      return 0
    fi

    elapsed=$((SECONDS - started_at))
    if ((attempt == 1 || attempt % 5 == 0)); then
      printf 'API is not ready yet (attempt %d, elapsed %ds); retrying...\n' \
        "$attempt" "$elapsed"
    fi

    if ((SECONDS + delay_seconds >= deadline)); then
      break
    fi
    sleep "$delay_seconds"
  done

  printf 'ERROR: API health did not return HTTP 200 within %d seconds.\n' \
    "$timeout_seconds" >&2
  printf 'Docker service status:\n' >&2
  docker compose --env-file "$ENV_FILE" ps >&2 || true
  printf '\nLast API logs:\n' >&2
  docker compose --env-file "$ENV_FILE" logs --tail=200 api >&2 || true
  return 1
}

for command_name in bash curl dart docker dotnet flutter git python3; do
  command -v "$command_name" >/dev/null 2>&1 || \
    fail "Required command '${command_name}' is not installed or is not on PATH."
done

[[ -f "$ENV_FILE" ]] || fail "Missing ${ENV_FILE}. Restore the private .env file before the final test."

API_PORT="$(read_env API_HOST_PORT)"
API_PORT="${API_PORT:-5001}"
BASE_URL="${1:-http://localhost:${API_PORT}}"
DATABASE_NAME="$(read_env DATABASE_NAME)"
DATABASE_NAME="${DATABASE_NAME:-220087}"
SQL_HOST_PORT="$(read_env SQL_HOST_PORT)"
SQL_HOST_PORT="${SQL_HOST_PORT:-14333}"
SQL_SA_PASSWORD="$(read_env SQL_SA_PASSWORD)"
[[ -n "$SQL_SA_PASSWORD" ]] || fail 'SQL_SA_PASSWORD is missing from .env.'
[[ "$DATABASE_NAME" =~ ^[A-Za-z0-9_]+$ ]] || fail 'DATABASE_NAME may contain only letters, digits, and underscores.'

cd "$ROOT_DIR"

printf '\n[1/9] Checking final E2E source contract, shell syntax, and static invariants\n'
python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
controller = (root / 'src/LadderSocial.Api/Controllers/ChatController.cs').read_text()
contracts = (root / 'src/LadderSocial.Application/Features/Chat/ChatContracts.cs').read_text()
service = (root / 'src/LadderSocial.Infrastructure/Services/ChatService.cs').read_text()
rules = (root / 'src/LadderSocial.Application/Features/Chat/E2EChatRules.cs').read_text()
constants = (root / 'src/LadderSocial.Domain/Constants/ChatCryptoConstants.cs').read_text()
crypto_models = (root / 'packages/ladder_social_core/lib/src/chat/e2e/e2e_crypto_models.dart').read_text()
repository = (root / 'packages/ladder_social_core/lib/src/chat/chat_repository.dart').read_text()
screen = (root / 'apps/ladder_social_mobile/lib/src/features/chat/presentation/chat_screen.dart').read_text()
docs = (root / 'docs/e2e-chat-arhitektura.md').read_text()
readme = (root / 'README.md').read_text()
backend_smoke = (root / 'scripts/test-review-e2e-chat-backend.sh').read_text()
legacy_smoke = (root / 'scripts/test-review-chat-notifications.sh').read_text()
social_smoke = (root / 'scripts/test-social-features.sh').read_text()
pagination_smoke = (root / 'scripts/test-review-pagination-print.sh').read_text()
request_collection = (root / 'requests/application.http').read_text()
legacy_form = root / 'src/LadderSocial.Api/Models/SendMessageForm.cs'

checks = {
    'legacy plaintext API form is removed': not legacy_form.exists(),
    'controller exposes ciphertext write route': (
        '[HttpPost("{conversationId:guid}/messages/e2e")]' in controller
    ),
    'controller does not expose legacy plaintext POST route': (
        '[HttpPost("{conversationId:guid}/messages")]' not in controller
    ),
    'application contract exposes only encrypted private write': (
        'SendEncryptedMessageAsync' in contracts
        and 'SendMessageCommand' not in contracts
        and 'SendMessageRequest' not in contracts
        and 'Task<MessageResponse> SendMessageAsync' not in contracts
    ),
    'service has no legacy plaintext persistence method': (
        'public async Task<MessageResponse> SendMessageAsync(' not in service
        and 'SaveImageAsync(' not in service
    ),
    'Flutter repository has no legacy private write method': (
        'Future<ChatMessage> sendMessage({' not in repository
        and "'/api/conversations/$conversationId/messages/e2e'" in repository
    ),
    'production chat has no legacy submit call': '.sendMessage(' not in screen,
    'E2E factory always clears plaintext content': 'Content = null' in rules,
    'server and client duration limits match voice and video contracts': all(
        token in constants
        for token in (
            'MinimumMediaDurationMilliseconds = 300',
            'MaximumVoiceDurationMilliseconds = 5 * 60 * 1000',
            'MaximumVideoDurationMilliseconds = 2 * 60 * 1000',
        )
    ) and all(
        token in crypto_models
        for token in (
            'minimumMediaDurationMilliseconds = 300',
            'maximumVoiceDurationMilliseconds = 5 * 60 * 1000',
            'maximumVideoDurationMilliseconds = 2 * 60 * 1000',
        )
    ),
    'backend smoke rejects legacy text and image writes': (
        'legacy plaintext text endpoint is absent' in backend_smoke
        and 'legacy plaintext image endpoint is absent' in backend_smoke
        and 'expect_status "$status" 405' in backend_smoke
    ),
    'legacy regression rejects writes before and after refriending': (
        'legacy plaintext text write is unavailable' in legacy_smoke
        and 'refriending does not restore the removed plaintext route' in legacy_smoke
    ),
    'existing social and pagination smoke tests create E2E chat fixtures': (
        'e2e_send_text' in social_smoke
        and 'e2e_send_text' in pagination_smoke
        and 'create encrypted paged message' in pagination_smoke
    ),
    'REST request collection documents only the ciphertext write route': (
        'POST {{baseUrl}}/api/conversations/{{conversationId}}/messages/e2e' in request_collection
        and 'encryptedContentBase64' in request_collection
        and 'POST {{baseUrl}}/api/conversations/{{conversationId}}/messages\n' not in request_collection
    ),
    'architecture document records final test and legacy closure': (
        'scripts/test-review-e2e-multimedia-chat.sh' in docs
        and 'Legacy plaintext write endpoint je uklonjen' in docs
    ),
    'README advertises all E2E multimedia types': (
        'End-to-end enkriptovani chat za tekst, slike, glasovne poruke i video' in readme
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

python3 scripts/static-source-check.py
while IFS= read -r -d '' script_file; do
  bash -n "$script_file"
done < <(find scripts -type f -name '*.sh' -print0)
git diff --check

printf '\n[2/9] Restoring, building, and testing the .NET solution\n'
dotnet tool restore
dotnet restore LadderSocial.sln
dotnet build LadderSocial.sln --no-restore
dotnet test \
  tests/LadderSocial.UnitTests/LadderSocial.UnitTests.csproj \
  --no-build \
  --filter "FullyQualifiedName~E2EChatFoundationTests|FullyQualifiedName~E2EChatBackendContractTests" \
  --logger "console;verbosity=normal"
dotnet test LadderSocial.sln --no-build --logger "console;verbosity=normal"

printf '\n[3/9] Verifying the EF Core migration snapshot\n'
export DATABASE_CONNECTION_STRING="Server=localhost,${SQL_HOST_PORT};Database=${DATABASE_NAME};User Id=sa;Password=${SQL_SA_PASSWORD};Encrypt=False;TrustServerCertificate=True"
dotnet tool run dotnet-ef migrations has-pending-model-changes \
  --project src/LadderSocial.Infrastructure/LadderSocial.Infrastructure.csproj \
  --startup-project src/LadderSocial.Api/LadderSocial.Api.csproj

printf '\n[4/9] Running focused Flutter E2E Text/Image/Voice/Video checks\n'
bash scripts/test-review-e2e-chat-video.sh

printf '\n[5/9] Running all Flutter tests\n'
(
  cd packages/ladder_social_core
  flutter test --no-pub
)
(
  cd apps/ladder_social_mobile
  flutter test --no-pub
)
(
  cd apps/ladder_social_admin
  flutter test --no-pub
)

printf '\n[6/9] Rebuilding and starting the Docker runtime\n'
docker compose --env-file .env config >/dev/null
if [[ "${E2E_FINAL_SKIP_DOCKER_BUILD:-0}" == "1" ]]; then
  echo 'Skipping docker compose up --build because E2E_FINAL_SKIP_DOCKER_BUILD=1.'
else
  docker compose --env-file .env up --build -d
fi

echo "Waiting for ${BASE_URL}/api/health ..."
wait_for_api_health "${BASE_URL}/api/health"
echo 'PASS: API health returned HTTP 200.'
docker compose --env-file .env ps

printf '\n[7/9] Running HTTP authorization, notification, friendship, and ciphertext smoke tests\n'
bash scripts/test-review-chat-notifications.sh "$BASE_URL"
bash scripts/test-review-e2e-chat-backend.sh "$BASE_URL"
bash scripts/test-social-features.sh "$BASE_URL"
bash scripts/test-review-pagination-print.sh "$BASE_URL"

printf '\n[8/9] Verifying ciphertext-only persistence directly in SQL Server\n'
{
  printf 'USE [%s];\n' "$DATABASE_NAME"
  cat <<'SQL'
SET NOCOUNT ON;

IF NOT EXISTS (
    SELECT 1
    FROM __EFMigrationsHistory
    WHERE MigrationId = '20260909123000_AddE2EChatFoundation'
)
    RAISERROR('The E2E chat foundation migration is not applied.', 16, 1);

IF EXISTS (
    SELECT 1
    FROM Messages
    WHERE EncryptionVersion = 1
      AND Content IS NOT NULL
)
    RAISERROR('An E2E message contains plaintext in Message.Content.', 16, 1);

IF EXISTS (
    SELECT 1
    FROM Messages
    WHERE EncryptionVersion = 1
      AND Type = 1
      AND (
          EncryptedContent IS NULL
          OR DATALENGTH(EncryptedContent) <= 16
          OR ContentNonce IS NULL
          OR DATALENGTH(ContentNonce) <> 12
          OR KeyVersion IS NULL
      )
)
    RAISERROR('An E2E text message has incomplete ciphertext metadata.', 16, 1);

IF EXISTS (
    SELECT 1
    FROM Messages AS m
    LEFT JOIN MessageAttachments AS a ON a.MessageId = m.Id
    WHERE m.EncryptionVersion = 1
      AND m.Type IN (2, 4, 5)
      AND (
          m.Content IS NOT NULL
          OR m.EncryptedContent IS NOT NULL
          OR m.ContentNonce IS NOT NULL
          OR m.KeyVersion IS NULL
          OR a.Id IS NULL
          OR a.MimeType <> 'application/octet-stream'
          OR a.SizeBytes <= 16
          OR a.ContentNonce IS NULL
          OR DATALENGTH(a.ContentNonce) <> 12
          OR a.EncryptionVersion <> 1
          OR a.KeyVersion IS NULL
          OR a.KeyVersion <> m.KeyVersion
          OR (m.Type = 2 AND a.DurationMilliseconds IS NOT NULL)
          OR (m.Type = 4 AND (
              a.DurationMilliseconds IS NULL
              OR a.DurationMilliseconds < 300
              OR a.DurationMilliseconds > 300000
          ))
          OR (m.Type = 5 AND (
              a.DurationMilliseconds IS NULL
              OR a.DurationMilliseconds < 300
              OR a.DurationMilliseconds > 120000
          ))
      )
)
    RAISERROR('An E2E media message has invalid ciphertext metadata.', 16, 1);

IF EXISTS (
    SELECT 1
    FROM Messages
    WHERE Content LIKE '%KNOWN-PLAINTEXT-MARKER-220087%'
       OR Content LIKE '%LEGACY-PLAINTEXT-MUST-NOT-BE-STORED-220087%'
)
    RAISERROR('A known plaintext smoke-test marker was persisted.', 16, 1);

IF EXISTS (
    SELECT 1
    FROM Messages
    WHERE EncryptedContent IS NOT NULL
      AND (
          CHARINDEX(
              '4B4E4F574E2D504C41494E544558542D4D41524B45522D323230303837',
              CONVERT(varchar(max), EncryptedContent, 2)
          ) > 0
          OR CHARINDEX(
              '4C45474143592D504C41494E544558542D4D5553542D4E4F542D42452D53544F5245442D323230303837',
              CONVERT(varchar(max), EncryptedContent, 2)
          ) > 0
      )
)
    RAISERROR('Known plaintext marker bytes appear inside encrypted message storage.', 16, 1);

IF EXISTS (
    SELECT 1
    FROM Notifications
    WHERE Body LIKE '%KNOWN-PLAINTEXT-MARKER-220087%'
       OR Body LIKE '%LEGACY-PLAINTEXT-MUST-NOT-BE-STORED-220087%'
)
    RAISERROR('A notification contains a known plaintext smoke-test marker.', 16, 1);

PRINT 'PASS: migration, ciphertext metadata, duration limits, plaintext markers, and notifications are valid.';
GO
SQL
} | docker compose --env-file .env exec -T database bash -lc \
  '/opt/mssql-tools18/bin/sqlcmd \
    -S 127.0.0.1 \
    -U sa \
    -P "$MSSQL_SA_PASSWORD" \
    -C \
    -b'

printf '\n[9/9] Final repository checks\n'
python3 scripts/static-source-check.py
git diff --check
if git status --short | grep -E '(^|/)(\.env|build|bin|obj|\.dart_tool|\.gradle)(/|$)' >/dev/null; then
  git status --short >&2
  fail 'Generated output or a secret-bearing path is present in Git status.'
fi

echo
echo "E2E multimedia chat final verification completed successfully against ${BASE_URL}."
