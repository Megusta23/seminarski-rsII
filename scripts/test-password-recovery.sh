#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env and run scripts/prepare-password-reset-env.sh first." >&2
  exit 1
fi

for command_name in curl python3; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command '${command_name}' is not installed." >&2
    exit 1
  fi
done

read_env() {
  local key="$1"
  sed -n "s/^${key}=//p" "${ENV_FILE}" | tail -n 1
}

json_string() {
  python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"
}

json_get() {
  local file="$1"
  local key="$2"
  python3 - "$file" "$key" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
value = payload
for part in sys.argv[2].split("."):
    value = value[part]
print(value)
PY
}

request() {
  local method="$1"
  local url="$2"
  local output_file="$3"
  local body="${4:-}"
  local access_token="${5:-}"
  local args=(-sS -o "$output_file" -w "%{http_code}" -X "$method" "$url" -H "Accept: application/json")

  if [[ -n "$body" ]]; then
    args+=(-H "Content-Type: application/json" --data "$body")
  fi
  if [[ -n "$access_token" ]]; then
    args+=(-H "Authorization: Bearer ${access_token}")
  fi

  curl "${args[@]}"
}

expect_status() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  local body_file="$4"

  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: ${label}: expected HTTP ${expected}, got ${actual}" >&2
    if [[ -s "$body_file" ]]; then
      cat "$body_file" >&2
      echo >&2
    fi
    exit 1
  fi
  echo "PASS: ${label} (HTTP ${actual})"
}

find_smtp_message_id() {
  local response_file="$1"
  local target_email="$2"
  python3 - "$response_file" "$target_email" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
target = sys.argv[2].lower()

if isinstance(payload, list):
    items = payload
elif isinstance(payload, dict):
    items = []
    for key in ("results", "items", "messages"):
        value = payload.get(key)
        if isinstance(value, list):
            items = value
            break
else:
    items = []

matching = []
for item in items:
    if not isinstance(item, dict):
        continue
    if target in json.dumps(item, ensure_ascii=False).lower():
        matching.append(item)

candidates = matching or [item for item in items if isinstance(item, dict)]
for item in candidates:
    for key in ("id", "Id", "messageId", "MessageId"):
        value = item.get(key)
        if value is not None and str(value).strip():
            print(value)
            raise SystemExit(0)
raise SystemExit(1)
PY
}

extract_reset_code() {
  local body_file="$1"
  python3 - "$body_file" <<'PY'
import json
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
try:
    parsed = json.loads(text)
    if isinstance(parsed, str):
        text = parsed
except json.JSONDecodeError:
    pass

match = re.search(r"(?<!\d)(\d{6})(?!\d)", text)
if not match:
    raise SystemExit("No six-digit reset code was found in the smtp4dev message.")
print(match.group(1))
PY
}

API_PORT="$(read_env API_HOST_PORT)"
API_PORT="${API_PORT:-5001}"
SMTP_WEB_PORT="$(read_env SMTP4DEV_WEB_HOST_PORT)"
SMTP_WEB_PORT="${SMTP_WEB_PORT:-5002}"
BASE_URL="${1:-http://localhost:${API_PORT}}"
SMTP_BASE_URL="${2:-http://localhost:${SMTP_WEB_PORT}}"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

health_status="$(request GET "${BASE_URL}/api/health" "${TEMP_DIR}/health.json")"
expect_status "$health_status" 200 "API health" "${TEMP_DIR}/health.json"

if ! curl -fsS "${SMTP_BASE_URL}/api/messages?pageSize=1" >"${TEMP_DIR}/smtp-health.json"; then
  echo "FAIL: smtp4dev is not reachable at ${SMTP_BASE_URL}. Start the full Docker Compose stack." >&2
  exit 1
fi
echo "PASS: smtp4dev API is reachable"

unique_email="password-recovery-$(date +%s)-$$@example.com"
unknown_email="unknown-$(date +%s)-$$@example.com"
initial_password='Recovery_Initial_220087!'
reset_password='Recovery_Reset_220087!'
final_password='Recovery_Final_220087!'

register_body="$(printf '{"email":%s,"password":%s,"confirmPassword":%s,"firstName":"Recovery","lastName":"Tester"}' \
  "$(json_string "$unique_email")" \
  "$(json_string "$initial_password")" \
  "$(json_string "$initial_password")")"
register_status="$(request POST "${BASE_URL}/api/auth/register" "${TEMP_DIR}/register.json" "$register_body")"
expect_status "$register_status" 201 "register password-recovery user" "${TEMP_DIR}/register.json"
original_access="$(json_get "${TEMP_DIR}/register.json" accessToken)"
original_refresh="$(json_get "${TEMP_DIR}/register.json" refreshToken)"

unknown_body="$(printf '{"email":%s}' "$(json_string "$unknown_email")")"
unknown_status="$(request POST "${BASE_URL}/api/auth/forgot-password" "${TEMP_DIR}/unknown-forgot.json" "$unknown_body")"
expect_status "$unknown_status" 202 "unknown email receives generic recovery response" "${TEMP_DIR}/unknown-forgot.json"
unknown_message="$(json_get "${TEMP_DIR}/unknown-forgot.json" message)"

forgot_body="$(printf '{"email":%s}' "$(json_string "$unique_email")")"
forgot_status="$(request POST "${BASE_URL}/api/auth/forgot-password" "${TEMP_DIR}/forgot.json" "$forgot_body")"
expect_status "$forgot_status" 202 "request password reset code" "${TEMP_DIR}/forgot.json"
forgot_message="$(json_get "${TEMP_DIR}/forgot.json" message)"
if [[ "$forgot_message" != "$unknown_message" ]]; then
  echo "FAIL: known and unknown forgot-password responses are distinguishable." >&2
  exit 1
fi
echo "PASS: forgot-password response does not reveal account existence"

rate_limited_status="$(request POST "${BASE_URL}/api/auth/forgot-password" "${TEMP_DIR}/rate-limited.json" "$forgot_body")"
expect_status "$rate_limited_status" 202 "repeated reset request receives generic rate-limited response" "${TEMP_DIR}/rate-limited.json"
rate_limited_message="$(json_get "${TEMP_DIR}/rate-limited.json" message)"
if [[ "$rate_limited_message" != "$forgot_message" ]]; then
  echo "FAIL: rate-limited forgot-password response is distinguishable." >&2
  exit 1
fi
echo "PASS: rate-limited response remains generic"

encoded_email="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$unique_email")"
message_id=""
for _ in $(seq 1 30); do
  if curl -fsS "${SMTP_BASE_URL}/api/messages?searchTerms=${encoded_email}&pageSize=100" >"${TEMP_DIR}/messages.json"; then
    message_id="$(find_smtp_message_id "${TEMP_DIR}/messages.json" "$unique_email" 2>/dev/null || true)"
  fi
  if [[ -n "$message_id" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "$message_id" ]]; then
  echo "FAIL: no smtp4dev email arrived for ${unique_email} within 30 seconds." >&2
  echo "Check: docker compose --env-file .env logs --tail=200 worker" >&2
  exit 1
fi
echo "PASS: Worker delivered reset email to smtp4dev (message ${message_id})"

curl -fsS "${SMTP_BASE_URL}/api/messages/${message_id}/plaintext" >"${TEMP_DIR}/message.txt"
reset_code="$(extract_reset_code "${TEMP_DIR}/message.txt")"
if [[ ! "$reset_code" =~ ^[0-9]{6}$ ]]; then
  echo "FAIL: smtp4dev reset code has an invalid format." >&2
  exit 1
fi
echo "PASS: six-digit reset code extracted from local development email"

reset_body="$(printf '{"email":%s,"code":%s,"newPassword":%s,"confirmPassword":%s}' \
  "$(json_string "$unique_email")" \
  "$(json_string "$reset_code")" \
  "$(json_string "$reset_password")" \
  "$(json_string "$reset_password")")"
reset_status="$(request POST "${BASE_URL}/api/auth/reset-password" "${TEMP_DIR}/reset.json" "$reset_body")"
expect_status "$reset_status" 204 "reset password with emailed code" "${TEMP_DIR}/reset.json"

old_access_status="$(request GET "${BASE_URL}/api/profile/me" "${TEMP_DIR}/old-access.json" '' "$original_access")"
expect_status "$old_access_status" 401 "password reset invalidates existing access token" "${TEMP_DIR}/old-access.json"

original_refresh_body="$(printf '{"refreshToken":%s}' "$(json_string "$original_refresh")")"
original_refresh_status="$(request POST "${BASE_URL}/api/auth/refresh" "${TEMP_DIR}/old-refresh.json" "$original_refresh_body")"
expect_status "$original_refresh_status" 401 "password reset revokes existing refresh token" "${TEMP_DIR}/old-refresh.json"

reuse_status="$(request POST "${BASE_URL}/api/auth/reset-password" "${TEMP_DIR}/reuse-code.json" "$reset_body")"
expect_status "$reuse_status" 400 "reset code is single-use" "${TEMP_DIR}/reuse-code.json"

old_login_body="$(printf '{"email":%s,"password":%s}' \
  "$(json_string "$unique_email")" \
  "$(json_string "$initial_password")")"
old_login_status="$(request POST "${BASE_URL}/api/auth/login" "${TEMP_DIR}/old-login.json" "$old_login_body")"
expect_status "$old_login_status" 401 "old password rejected after reset" "${TEMP_DIR}/old-login.json"

reset_login_body="$(printf '{"email":%s,"password":%s}' \
  "$(json_string "$unique_email")" \
  "$(json_string "$reset_password")")"
reset_login_status="$(request POST "${BASE_URL}/api/auth/login" "${TEMP_DIR}/reset-login.json" "$reset_login_body")"
expect_status "$reset_login_status" 200 "new password accepted after reset" "${TEMP_DIR}/reset-login.json"
reset_access="$(json_get "${TEMP_DIR}/reset-login.json" accessToken)"
reset_refresh="$(json_get "${TEMP_DIR}/reset-login.json" refreshToken)"

change_body="$(printf '{"currentPassword":%s,"newPassword":%s,"confirmPassword":%s}' \
  "$(json_string "$reset_password")" \
  "$(json_string "$final_password")" \
  "$(json_string "$final_password")")"
change_status="$(request POST "${BASE_URL}/api/profile/change-password" "${TEMP_DIR}/change.json" "$change_body" "$reset_access")"
expect_status "$change_status" 204 "authenticated password change" "${TEMP_DIR}/change.json"

changed_access_status="$(request GET "${BASE_URL}/api/profile/me" "${TEMP_DIR}/changed-access.json" '' "$reset_access")"
expect_status "$changed_access_status" 401 "password change invalidates current access token" "${TEMP_DIR}/changed-access.json"

reset_refresh_body="$(printf '{"refreshToken":%s}' "$(json_string "$reset_refresh")")"
reset_refresh_status="$(request POST "${BASE_URL}/api/auth/refresh" "${TEMP_DIR}/changed-refresh.json" "$reset_refresh_body")"
expect_status "$reset_refresh_status" 401 "password change revokes current refresh token" "${TEMP_DIR}/changed-refresh.json"

reset_password_login_status="$(request POST "${BASE_URL}/api/auth/login" "${TEMP_DIR}/reset-password-login.json" "$reset_login_body")"
expect_status "$reset_password_login_status" 401 "previous password rejected after change" "${TEMP_DIR}/reset-password-login.json"

final_login_body="$(printf '{"email":%s,"password":%s}' \
  "$(json_string "$unique_email")" \
  "$(json_string "$final_password")")"
final_login_status="$(request POST "${BASE_URL}/api/auth/login" "${TEMP_DIR}/final-login.json" "$final_login_body")"
expect_status "$final_login_status" 200 "final password accepted" "${TEMP_DIR}/final-login.json"
final_access="$(json_get "${TEMP_DIR}/final-login.json" accessToken)"
final_refresh="$(json_get "${TEMP_DIR}/final-login.json" refreshToken)"

final_logout_body="$(printf '{"refreshToken":%s}' "$(json_string "$final_refresh")")"
final_logout_status="$(request POST "${BASE_URL}/api/auth/logout" "${TEMP_DIR}/final-logout.json" "$final_logout_body" "$final_access")"
expect_status "$final_logout_status" 204 "clean up final password-recovery session" "${TEMP_DIR}/final-logout.json"

echo
echo "Password recovery and password-change smoke test completed successfully."
echo "API: ${BASE_URL}"
echo "smtp4dev: ${SMTP_BASE_URL}"
