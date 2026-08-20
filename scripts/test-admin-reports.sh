#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

ADMIN_EMAIL="$(read_env SEED_ADMIN_EMAIL)"
ADMIN_PASSWORD="$(read_env SEED_ADMIN_PASSWORD)"
[[ -n "$ADMIN_EMAIL" && -n "$ADMIN_PASSWORD" ]] || { echo "Seed administrator credentials are missing from .env" >&2; exit 1; }
login_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "${TEMP_DIR}/admin-login.json"
ADMIN_TOKEN="$(json_get "${TEMP_DIR}/admin-login.json" accessToken)"

suffix="$(date +%s)-$$"
USER_EMAIL="admin-report-user-${suffix}@example.com"
USER_PASSWORD='Admin_Report_220087!'
register_test_user "$USER_EMAIL" "$USER_PASSWORD" Report User "${TEMP_DIR}/user.json"
USER_TOKEN="$(json_get "${TEMP_DIR}/user.json" accessToken)"
USER_ID="$(json_get "${TEMP_DIR}/user.json" userId)"

status="$(http_request GET "${BASE_URL}/api/admin/dashboard" "${TEMP_DIR}/user-dashboard.json" '' "$USER_TOKEN")"
expect_status "$status" 403 "regular user blocked from admin dashboard" "${TEMP_DIR}/user-dashboard.json"
status="$(http_request GET "${BASE_URL}/api/admin/dashboard" "${TEMP_DIR}/dashboard.json" '' "$ADMIN_TOKEN")"
expect_status "$status" 200 "administrator dashboard analytics" "${TEMP_DIR}/dashboard.json"
status="$(http_request GET "${BASE_URL}/api/admin/users?search=$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$USER_EMAIL")&page=1&pageSize=10" "${TEMP_DIR}/users.json" '' "$ADMIN_TOKEN")"
expect_status "$status" 200 "administrator user search and pagination" "${TEMP_DIR}/users.json"
json_array_contains "${TEMP_DIR}/users.json" items id "$USER_ID"
status="$(http_request GET "${BASE_URL}/api/admin/users/${USER_ID}" "${TEMP_DIR}/user-detail.json" '' "$ADMIN_TOKEN")"
expect_status "$status" 200 "administrator user details" "${TEMP_DIR}/user-detail.json"

# Create a shared post so moderation and reports have deterministic data.
status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$USER_TOKEN")"
expect_status "$status" 200 "load category for report fixture" "${TEMP_DIR}/categories.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories.json" 0.id)"
status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$USER_TOKEN")"
expect_status "$status" 200 "load recurrence for report fixture" "${TEMP_DIR}/recurrences.json"
NONE_ID="$(python3 - "${TEMP_DIR}/recurrences.json" <<'PY'
import json,sys
with open(sys.argv[1],encoding='utf-8') as h: items=json.load(h)
print(next(item['id'] for item in items if item['code'].lower()=='none'))
PY
)"
create_body="$(printf '{"title":%s,"description":null,"taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":true}' \
  "$(json_string "Admin report fixture ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/task.json" "$create_body" "$USER_TOKEN")"
expect_status "$status" 201 "create report fixture task" "${TEMP_DIR}/task.json"
TASK_ID="$(json_get "${TEMP_DIR}/task.json" id)"
TODAY="$(date -u +%F)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${TASK_ID}/complete" "${TEMP_DIR}/completion.json" "$USER_TOKEN" \
  -F "occurrenceDate=${TODAY}" -F "caption=Moderation fixture")"
expect_status "$status" 201 "complete report fixture task" "${TEMP_DIR}/completion.json"
POST_ID="$(json_get "${TEMP_DIR}/completion.json" postId)"

status="$(http_request GET "${BASE_URL}/api/admin/posts?search=Moderation&page=1&pageSize=20" "${TEMP_DIR}/posts.json" '' "$ADMIN_TOKEN")"
expect_status "$status" 200 "administrator post moderation list" "${TEMP_DIR}/posts.json"
json_array_contains "${TEMP_DIR}/posts.json" items id "$POST_ID"
status="$(http_request PUT "${BASE_URL}/api/admin/posts/${POST_ID}/visibility" "${TEMP_DIR}/hide-post.json" '{"isVisible":false}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator hides post" "${TEMP_DIR}/hide-post.json"
status="$(http_request PUT "${BASE_URL}/api/admin/posts/${POST_ID}/visibility" "${TEMP_DIR}/show-post.json" '{"isVisible":true}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator restores post" "${TEMP_DIR}/show-post.json"

FROM_DATE="$(python3 - <<'PY'
from datetime import date,timedelta
print(date.today()-timedelta(days=7))
PY
)"
status="$(curl -sS -o "${TEMP_DIR}/activity.pdf" -w "%{http_code}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BASE_URL}/api/admin/reports/activity?fromDate=${FROM_DATE}&toDate=${TODAY}")"
expect_status "$status" 200 "download application activity PDF" "${TEMP_DIR}/activity.pdf"
head -c 5 "${TEMP_DIR}/activity.pdf" | grep -q '%PDF-' || { echo "FAIL: activity report is not a PDF" >&2; exit 1; }
echo "PASS: activity report has a valid PDF header"

status="$(curl -sS -o "${TEMP_DIR}/user.pdf" -w "%{http_code}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${BASE_URL}/api/admin/reports/users/${USER_ID}")"
expect_status "$status" 200 "download individual user PDF" "${TEMP_DIR}/user.pdf"
head -c 5 "${TEMP_DIR}/user.pdf" | grep -q '%PDF-' || { echo "FAIL: user report is not a PDF" >&2; exit 1; }
echo "PASS: user report has a valid PDF header"

status="$(http_request PUT "${BASE_URL}/api/admin/users/${USER_ID}/active" "${TEMP_DIR}/deactivate-user.json" '{"isActive":false}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator deactivates test user" "${TEMP_DIR}/deactivate-user.json"
status="$(http_request PUT "${BASE_URL}/api/admin/users/${USER_ID}/active" "${TEMP_DIR}/reactivate-user.json" '{"isActive":true}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator reactivates test user" "${TEMP_DIR}/reactivate-user.json"

echo
echo "Administrator analytics, moderation and PDF-report smoke test completed successfully against ${BASE_URL}."
