#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

ADMIN_EMAIL="$(read_env SEED_ADMIN_EMAIL)"
ADMIN_PASSWORD="$(read_env SEED_ADMIN_PASSWORD)"
MOBILE_EMAIL="$(read_env SEED_MOBILE_EMAIL)"
MOBILE_PASSWORD="$(read_env SEED_MOBILE_PASSWORD)"
for value_name in ADMIN_EMAIL ADMIN_PASSWORD MOBILE_EMAIL MOBILE_PASSWORD; do
  [[ -n "${!value_name}" ]] || { echo "${value_name} is missing from .env" >&2; exit 1; }
done

login_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "${TEMP_DIR}/admin-login.json"
ADMIN_ACCESS="$(json_get "${TEMP_DIR}/admin-login.json" accessToken)"
login_user "$MOBILE_EMAIL" "$MOBILE_PASSWORD" "${TEMP_DIR}/mobile-login.json"
MOBILE_ACCESS="$(json_get "${TEMP_DIR}/mobile-login.json" accessToken)"

status="$(http_request GET "${BASE_URL}/api/admin/reference-data/countries?page=1&pageSize=10" "${TEMP_DIR}/mobile-admin.json" '' "$MOBILE_ACCESS")"
expect_status "$status" 403 "regular user blocked from reference-data administration" "${TEMP_DIR}/mobile-admin.json"

suffix="$(date +%s)-$$"
iso_code="$(python3 - "$suffix" <<'PY'
import string, sys
value = 0
for character in sys.argv[1]:
    value = (value * 131 + ord(character)) % (26 ** 3)
letters = string.ascii_uppercase
print(
    letters[(value // (26 ** 2)) % 26]
    + letters[(value // 26) % 26]
    + letters[value % 26]
)
PY
)"
country_name="Smoke Country ${suffix}"
country_body="$(printf '{"name":%s,"isoCode":%s,"sortOrder":900}' "$(json_string "$country_name")" "$(json_string "$iso_code")")"
status="$(http_request POST "${BASE_URL}/api/admin/reference-data/countries" "${TEMP_DIR}/country.json" "$country_body" "$ADMIN_ACCESS")"
expect_status "$status" 201 "administrator creates country" "${TEMP_DIR}/country.json"
COUNTRY_ID="$(json_get "${TEMP_DIR}/country.json" id)"

status="$(http_request POST "${BASE_URL}/api/admin/reference-data/countries" "${TEMP_DIR}/country-duplicate.json" "$country_body" "$ADMIN_ACCESS")"
expect_status "$status" 409 "duplicate country rejected" "${TEMP_DIR}/country-duplicate.json"

status="$(http_request GET "${BASE_URL}/api/admin/reference-data/countries?search=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$country_name")&page=1&pageSize=10" "${TEMP_DIR}/country-search.json" '' "$ADMIN_ACCESS")"
expect_status "$status" 200 "country search and pagination" "${TEMP_DIR}/country-search.json"
json_array_contains "${TEMP_DIR}/country-search.json" items id "$COUNTRY_ID"
echo "PASS: created country appears in filtered list"

updated_country="$(printf '{"name":%s,"isoCode":%s,"isActive":true,"sortOrder":901}' "$(json_string "${country_name} Updated")" "$(json_string "$iso_code")")"
status="$(http_request PUT "${BASE_URL}/api/admin/reference-data/countries/${COUNTRY_ID}" "${TEMP_DIR}/country-updated.json" "$updated_country" "$ADMIN_ACCESS")"
expect_status "$status" 200 "administrator updates country" "${TEMP_DIR}/country-updated.json"

city_name="Smoke City ${suffix}"
city_body="$(printf '{"name":%s,"countryId":%s,"sortOrder":900}' "$(json_string "$city_name")" "$(json_string "$COUNTRY_ID")")"
status="$(http_request POST "${BASE_URL}/api/admin/reference-data/cities" "${TEMP_DIR}/city.json" "$city_body" "$ADMIN_ACCESS")"
expect_status "$status" 201 "administrator creates city" "${TEMP_DIR}/city.json"
CITY_ID="$(json_get "${TEMP_DIR}/city.json" id)"

category_code="smoke-category-${suffix}"
category_body="$(printf '{"name":%s,"code":%s,"sortOrder":900}' "$(json_string "Smoke Category ${suffix}")" "$(json_string "$category_code")")"
status="$(http_request POST "${BASE_URL}/api/admin/reference-data/task-categories" "${TEMP_DIR}/category.json" "$category_body" "$ADMIN_ACCESS")"
expect_status "$status" 201 "administrator creates task category" "${TEMP_DIR}/category.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/category.json" id)"

status="$(http_request GET "${BASE_URL}/api/admin/reference-data/recurrence-types?page=1&pageSize=100" "${TEMP_DIR}/recurrences.json" '' "$ADMIN_ACCESS")"
expect_status "$status" 200 "administrator lists supported recurrence types" "${TEMP_DIR}/recurrences.json"
python3 - "${TEMP_DIR}/recurrences.json" "${TEMP_DIR}/monthly-recurrence.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
for item in payload["items"]:
    if str(item.get("code", "")).lower() == "monthly":
        with open(sys.argv[2], "w", encoding="utf-8") as output:
            json.dump(item, output)
        break
else:
    raise SystemExit("The seeded monthly recurrence type was not found")
PY
RECURRENCE_ID="$(json_get "${TEMP_DIR}/monthly-recurrence.json" id)"
RECURRENCE_NAME="$(json_get "${TEMP_DIR}/monthly-recurrence.json" name)"
RECURRENCE_ORDER="$(json_get "${TEMP_DIR}/monthly-recurrence.json" sortOrder)"
RECURRENCE_ACTIVE="$(json_get "${TEMP_DIR}/monthly-recurrence.json" isActive)"
recurrence_update="$(printf '{"name":%s,"code":"monthly","isActive":%s,"sortOrder":%s}' \
  "$(json_string "${RECURRENCE_NAME} ${suffix}")" "$RECURRENCE_ACTIVE" "$RECURRENCE_ORDER")"
status="$(http_request PUT "${BASE_URL}/api/admin/reference-data/recurrence-types/${RECURRENCE_ID}" "${TEMP_DIR}/recurrence-updated.json" "$recurrence_update" "$ADMIN_ACCESS")"
expect_status "$status" 200 "administrator updates recurrence display data without changing its behavior code" "${TEMP_DIR}/recurrence-updated.json"
recurrence_restore="$(printf '{"name":%s,"code":"monthly","isActive":%s,"sortOrder":%s}' \
  "$(json_string "$RECURRENCE_NAME")" "$RECURRENCE_ACTIVE" "$RECURRENCE_ORDER")"
status="$(http_request PUT "${BASE_URL}/api/admin/reference-data/recurrence-types/${RECURRENCE_ID}" "${TEMP_DIR}/recurrence-restored.json" "$recurrence_restore" "$ADMIN_ACCESS")"
expect_status "$status" 200 "administrator restores recurrence display data" "${TEMP_DIR}/recurrence-restored.json"

for resource_id in \
  "cities:${CITY_ID}" \
  "task-categories:${CATEGORY_ID}" \
  "countries:${COUNTRY_ID}"; do
  resource="${resource_id%%:*}"
  id="${resource_id#*:}"
  status="$(http_request DELETE "${BASE_URL}/api/admin/reference-data/${resource}/${id}" "${TEMP_DIR}/deactivate-${resource}.json" '' "$ADMIN_ACCESS")"
  expect_status "$status" 204 "deactivate ${resource}" "${TEMP_DIR}/deactivate-${resource}.json"
done

echo
echo "Reference-data administration smoke test completed successfully against ${BASE_URL}."
