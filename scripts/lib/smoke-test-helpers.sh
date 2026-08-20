#!/usr/bin/env bash
# Shared helpers for Ladder Social HTTP smoke tests.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

require_smoke_prerequisites() {
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
}

read_env() {
  local key="$1"
  sed -n "s/^${key}=//p" "${ENV_FILE}" | tail -n 1
}

json_string() {
  python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"
}

json_get() {
  local file="$1"
  local path="$2"
  python3 - "$file" "$path" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for part in filter(None, sys.argv[2].split('.')):
    if isinstance(value, list):
        value = value[int(part)]
    else:
        value = value[part]
if isinstance(value, bool):
    print(str(value).lower())
elif value is None:
    print("")
else:
    print(value)
PY
}

json_array_length() {
  python3 - "$1" "$2" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for part in filter(None, sys.argv[2].split('.')):
    value = value[int(part)] if isinstance(value, list) else value[part]
print(len(value))
PY
}

json_array_contains() {
  local file="$1"
  local path="$2"
  local key="$3"
  local expected="$4"
  python3 - "$file" "$path" "$key" "$expected" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for part in filter(None, sys.argv[2].split('.')):
    value = value[int(part)] if isinstance(value, list) else value[part]
if not any(str(item.get(sys.argv[3], "")) == sys.argv[4] for item in value):
    raise SystemExit(f"Expected an item where {sys.argv[3]}={sys.argv[4]!r}, got {value!r}")
PY
}

http_request() {
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

multipart_request() {
  local method="$1"
  local url="$2"
  local output_file="$3"
  local access_token="$4"
  shift 4
  curl -sS -o "$output_file" -w "%{http_code}" -X "$method" "$url" \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${access_token}" \
    "$@"
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

register_test_user() {
  local email="$1"
  local password="$2"
  local first_name="$3"
  local last_name="$4"
  local output_file="$5"
  local body
  body="$(printf '{"email":%s,"password":%s,"confirmPassword":%s,"firstName":%s,"lastName":%s}' \
    "$(json_string "$email")" \
    "$(json_string "$password")" \
    "$(json_string "$password")" \
    "$(json_string "$first_name")" \
    "$(json_string "$last_name")")"
  local status
  status="$(http_request POST "${BASE_URL}/api/auth/register" "$output_file" "$body")"
  expect_status "$status" 201 "register ${email}" "$output_file"
}

login_user() {
  local email="$1"
  local password="$2"
  local output_file="$3"
  local body
  body="$(printf '{"email":%s,"password":%s}' "$(json_string "$email")" "$(json_string "$password")")"
  local status
  status="$(http_request POST "${BASE_URL}/api/auth/login" "$output_file" "$body")"
  expect_status "$status" 200 "login ${email}" "$output_file"
}

initialize_smoke_test() {
  require_smoke_prerequisites
  API_PORT="$(read_env API_HOST_PORT)"
  API_PORT="${API_PORT:-5001}"
  BASE_URL="${1:-http://localhost:${API_PORT}}"
  export BASE_URL
  TEMP_DIR="$(mktemp -d)"
  export TEMP_DIR
  trap 'rm -rf "${TEMP_DIR}"' EXIT
  local status
  status="$(http_request GET "${BASE_URL}/api/health" "${TEMP_DIR}/health.json")"
  expect_status "$status" 200 "API health" "${TEMP_DIR}/health.json"
}
