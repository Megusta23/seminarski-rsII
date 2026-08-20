#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env first." >&2
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

expect_exact_roles() {
  local file="$1"
  shift
  python3 - "$file" "$@" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
actual = sorted(payload.get("roles", []))
expected = sorted(sys.argv[2:])
if actual != expected:
    raise SystemExit(f"Expected roles {expected}, got {actual}")
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

API_PORT="$(read_env API_HOST_PORT)"
API_PORT="${API_PORT:-5001}"
BASE_URL="${1:-http://localhost:${API_PORT}}"
MOBILE_EMAIL="$(read_env SEED_MOBILE_EMAIL)"
MOBILE_PASSWORD="$(read_env SEED_MOBILE_PASSWORD)"
ADMIN_EMAIL="$(read_env SEED_ADMIN_EMAIL)"
ADMIN_PASSWORD="$(read_env SEED_ADMIN_PASSWORD)"

for value_name in MOBILE_EMAIL MOBILE_PASSWORD ADMIN_EMAIL ADMIN_PASSWORD; do
  if [[ -z "${!value_name}" ]]; then
    echo "${value_name} is missing from .env" >&2
    exit 1
  fi
done

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

health_status="$(request GET "${BASE_URL}/api/health" "${TEMP_DIR}/health.json")"
expect_status "$health_status" 200 "API health" "${TEMP_DIR}/health.json"

anonymous_profile_status="$(request GET "${BASE_URL}/api/profile/me" "${TEMP_DIR}/anonymous-profile.json")"
expect_status "$anonymous_profile_status" 401 "protected profile rejects anonymous access" "${TEMP_DIR}/anonymous-profile.json"

unique_email="auth-test-$(date +%s)-$$@example.com"
test_password='Auth_Test_220087!'
register_body="$(printf '{"email":%s,"password":%s,"confirmPassword":%s,"firstName":"Auth","lastName":"Tester","role":"Admin","isAdmin":true}' \
  "$(json_string "$unique_email")" \
  "$(json_string "$test_password")" \
  "$(json_string "$test_password")")"
register_status="$(request POST "${BASE_URL}/api/auth/register" "${TEMP_DIR}/register.json" "$register_body")"
expect_status "$register_status" 201 "register regular user" "${TEMP_DIR}/register.json"
expect_exact_roles "${TEMP_DIR}/register.json" User
echo "PASS: registration cannot self-assign the Admin role"

register_access="$(json_get "${TEMP_DIR}/register.json" accessToken)"
register_refresh="$(json_get "${TEMP_DIR}/register.json" refreshToken)"

duplicate_status="$(request POST "${BASE_URL}/api/auth/register" "${TEMP_DIR}/duplicate.json" "$register_body")"
expect_status "$duplicate_status" 409 "duplicate email rejected" "${TEMP_DIR}/duplicate.json"

wrong_password_body="$(printf '{"email":%s,"password":%s}' \
  "$(json_string "$unique_email")" \
  "$(json_string 'Definitely_Wrong_220087!')")"
wrong_password_status="$(request POST "${BASE_URL}/api/auth/login" "${TEMP_DIR}/wrong-password.json" "$wrong_password_body")"
expect_status "$wrong_password_status" 401 "wrong password rejected" "${TEMP_DIR}/wrong-password.json"

profile_status="$(request GET "${BASE_URL}/api/profile/me" "${TEMP_DIR}/profile.json" '' "$register_access")"
expect_status "$profile_status" 200 "protected current profile" "${TEMP_DIR}/profile.json"

user_admin_status="$(request GET "${BASE_URL}/api/admin/access" "${TEMP_DIR}/user-admin.json" '' "$register_access")"
expect_status "$user_admin_status" 403 "regular user blocked from admin endpoint" "${TEMP_DIR}/user-admin.json"

refresh_body="$(printf '{"refreshToken":%s}' "$(json_string "$register_refresh")")"
refresh_status="$(request POST "${BASE_URL}/api/auth/refresh" "${TEMP_DIR}/refresh.json" "$refresh_body")"
expect_status "$refresh_status" 200 "refresh-token rotation" "${TEMP_DIR}/refresh.json"

rotated_access="$(json_get "${TEMP_DIR}/refresh.json" accessToken)"
rotated_refresh="$(json_get "${TEMP_DIR}/refresh.json" refreshToken)"

reuse_status="$(request POST "${BASE_URL}/api/auth/refresh" "${TEMP_DIR}/reuse.json" "$refresh_body")"
expect_status "$reuse_status" 401 "old refresh token rejected" "${TEMP_DIR}/reuse.json"

logout_body="$(printf '{"refreshToken":%s}' "$(json_string "$rotated_refresh")")"
logout_status="$(request POST "${BASE_URL}/api/auth/logout" "${TEMP_DIR}/logout.json" "$logout_body" "$rotated_access")"
expect_status "$logout_status" 204 "server-side logout" "${TEMP_DIR}/logout.json"

invalidated_status="$(request GET "${BASE_URL}/api/profile/me" "${TEMP_DIR}/invalidated.json" '' "$rotated_access")"
expect_status "$invalidated_status" 401 "logged-out access token invalidated" "${TEMP_DIR}/invalidated.json"

refresh_after_logout_status="$(request POST "${BASE_URL}/api/auth/refresh" "${TEMP_DIR}/refresh-after-logout.json" "$logout_body")"
expect_status "$refresh_after_logout_status" 401 "logged-out refresh token invalidated" "${TEMP_DIR}/refresh-after-logout.json"

mobile_login_body="$(printf '{"email":%s,"password":%s}' \
  "$(json_string "$MOBILE_EMAIL")" \
  "$(json_string "$MOBILE_PASSWORD")")"
mobile_login_status="$(request POST "${BASE_URL}/api/auth/login" "${TEMP_DIR}/mobile-login.json" "$mobile_login_body")"
expect_status "$mobile_login_status" 200 "seeded mobile login" "${TEMP_DIR}/mobile-login.json"
expect_exact_roles "${TEMP_DIR}/mobile-login.json" User
mobile_access="$(json_get "${TEMP_DIR}/mobile-login.json" accessToken)"
mobile_refresh="$(json_get "${TEMP_DIR}/mobile-login.json" refreshToken)"

mobile_admin_status="$(request GET "${BASE_URL}/api/admin/access" "${TEMP_DIR}/mobile-admin.json" '' "$mobile_access")"
expect_status "$mobile_admin_status" 403 "seeded mobile user blocked from admin endpoint" "${TEMP_DIR}/mobile-admin.json"

admin_login_body="$(printf '{"email":%s,"password":%s}' \
  "$(json_string "$ADMIN_EMAIL")" \
  "$(json_string "$ADMIN_PASSWORD")")"
admin_login_status="$(request POST "${BASE_URL}/api/auth/login" "${TEMP_DIR}/admin-login.json" "$admin_login_body")"
expect_status "$admin_login_status" 200 "seeded administrator login" "${TEMP_DIR}/admin-login.json"
expect_exact_roles "${TEMP_DIR}/admin-login.json" Admin
admin_access="$(json_get "${TEMP_DIR}/admin-login.json" accessToken)"
admin_refresh="$(json_get "${TEMP_DIR}/admin-login.json" refreshToken)"

admin_check_status="$(request GET "${BASE_URL}/api/admin/access" "${TEMP_DIR}/admin-check.json" '' "$admin_access")"
expect_status "$admin_check_status" 200 "administrator role accepted" "${TEMP_DIR}/admin-check.json"

foreign_logout_body="$(printf '{"refreshToken":%s}' "$(json_string "$admin_refresh")")"
foreign_logout_status="$(request POST "${BASE_URL}/api/auth/logout" "${TEMP_DIR}/foreign-logout.json" "$foreign_logout_body" "$mobile_access")"
expect_status "$foreign_logout_status" 403 "user cannot revoke another user's refresh token" "${TEMP_DIR}/foreign-logout.json"

mobile_logout_body="$(printf '{"refreshToken":%s}' "$(json_string "$mobile_refresh")")"
mobile_logout_status="$(request POST "${BASE_URL}/api/auth/logout" "${TEMP_DIR}/mobile-logout.json" "$mobile_logout_body" "$mobile_access")"
expect_status "$mobile_logout_status" 204 "seeded mobile logout" "${TEMP_DIR}/mobile-logout.json"

admin_logout_body="$(printf '{"refreshToken":%s}' "$(json_string "$admin_refresh")")"
admin_logout_status="$(request POST "${BASE_URL}/api/auth/logout" "${TEMP_DIR}/admin-logout.json" "$admin_logout_body" "$admin_access")"
expect_status "$admin_logout_status" 204 "seeded administrator logout" "${TEMP_DIR}/admin-logout.json"

echo
echo "Authentication smoke test completed successfully against ${BASE_URL}."
