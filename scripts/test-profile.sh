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
    value = json.load(handle)
for part in sys.argv[2].split("."):
    value = value[part]
print(value)
PY
}

first_city_id() {
  python3 - "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    cities = json.load(handle)
if not isinstance(cities, list) or not cities:
    raise SystemExit("No active cities were returned. Verify seed data.")
print(cities[0]["id"])
PY
}

verify_profile() {
  python3 - "$1" "$2" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    profile = json.load(handle)
expected_city = sys.argv[2]
expected = {
    "firstName": "Updated",
    "lastName": "Profile",
    "bio": "Profile smoke test biography.",
    "cityId": expected_city,
    "dateOfBirth": "2000-01-15",
}
for key, value in expected.items():
    if profile.get(key) != value:
        raise SystemExit(f"Expected {key}={value!r}, got {profile.get(key)!r}")
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
    [[ -s "$body_file" ]] && cat "$body_file" >&2 && echo >&2
    exit 1
  fi
  echo "PASS: ${label} (HTTP ${actual})"
}

API_PORT="$(read_env API_HOST_PORT)"
API_PORT="${API_PORT:-5001}"
BASE_URL="${1:-http://localhost:${API_PORT}}"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

unique_email="profile-test-$(date +%s)-$$@example.com"
password='Profile_Test_220087!'
register_body="$(printf '{"email":%s,"password":%s,"confirmPassword":%s,"firstName":"Profile","lastName":"Tester"}' \
  "$(json_string "$unique_email")" \
  "$(json_string "$password")" \
  "$(json_string "$password")")"
register_status="$(request POST "${BASE_URL}/api/auth/register" "${TEMP_DIR}/register.json" "$register_body")"
expect_status "$register_status" 201 "register profile test user" "${TEMP_DIR}/register.json"
access_token="$(json_get "${TEMP_DIR}/register.json" accessToken)"
refresh_token="$(json_get "${TEMP_DIR}/register.json" refreshToken)"

countries_status="$(request GET "${BASE_URL}/api/reference-data/countries" "${TEMP_DIR}/countries.json" '' "$access_token")"
expect_status "$countries_status" 200 "load active countries" "${TEMP_DIR}/countries.json"

cities_status="$(request GET "${BASE_URL}/api/reference-data/cities" "${TEMP_DIR}/cities.json" '' "$access_token")"
expect_status "$cities_status" 200 "load active cities" "${TEMP_DIR}/cities.json"
city_id="$(first_city_id "${TEMP_DIR}/cities.json")"

categories_status="$(request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$access_token")"
expect_status "$categories_status" 200 "load active task categories" "${TEMP_DIR}/categories.json"

recurrence_status="$(request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrence.json" '' "$access_token")"
expect_status "$recurrence_status" 200 "load active recurrence types" "${TEMP_DIR}/recurrence.json"

update_body="$(printf '{"firstName":"Updated","lastName":"Profile","bio":"Profile smoke test biography.","cityId":%s,"dateOfBirth":"2000-01-15"}' \
  "$(json_string "$city_id")")"
update_status="$(request PUT "${BASE_URL}/api/profile/me" "${TEMP_DIR}/updated-profile.json" "$update_body" "$access_token")"
expect_status "$update_status" 200 "update current profile" "${TEMP_DIR}/updated-profile.json"
verify_profile "${TEMP_DIR}/updated-profile.json" "$city_id"
echo "PASS: updated profile response contains saved values"

get_status="$(request GET "${BASE_URL}/api/profile/me" "${TEMP_DIR}/current-profile.json" '' "$access_token")"
expect_status "$get_status" 200 "reload updated profile" "${TEMP_DIR}/current-profile.json"
verify_profile "${TEMP_DIR}/current-profile.json" "$city_id"
echo "PASS: profile changes persisted"

future_body='{"firstName":"Updated","lastName":"Profile","bio":null,"cityId":null,"dateOfBirth":"2999-01-01"}'
future_status="$(request PUT "${BASE_URL}/api/profile/me" "${TEMP_DIR}/future-date.json" "$future_body" "$access_token")"
expect_status "$future_status" 400 "future date of birth rejected" "${TEMP_DIR}/future-date.json"

invalid_city_body='{"firstName":"Updated","lastName":"Profile","bio":null,"cityId":"00000000-0000-0000-0000-000000000001","dateOfBirth":null}'
invalid_city_status="$(request PUT "${BASE_URL}/api/profile/me" "${TEMP_DIR}/invalid-city.json" "$invalid_city_body" "$access_token")"
expect_status "$invalid_city_status" 400 "unknown city rejected" "${TEMP_DIR}/invalid-city.json"

logout_body="$(printf '{"refreshToken":%s}' "$(json_string "$refresh_token")")"
logout_status="$(request POST "${BASE_URL}/api/auth/logout" "${TEMP_DIR}/logout.json" "$logout_body" "$access_token")"
expect_status "$logout_status" 204 "profile test user logout" "${TEMP_DIR}/logout.json"

echo
echo "Profile and reference-data smoke test completed successfully against ${BASE_URL}."
