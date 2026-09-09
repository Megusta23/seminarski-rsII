#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/e2e-chat-smoke-helpers.sh"
initialize_smoke_test "${1:-}"

suffix="$(date +%s)-$$"
PASSWORD='Review_Page_220087!'
A_EMAIL="review-page-a-${suffix}@example.com"
B_EMAIL="review-page-b-${suffix}@example.com"
C_EMAIL="review-page-c-${suffix}@example.com"

register_test_user "$A_EMAIL" "$PASSWORD" Paging Alice "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Paging Bob "${TEMP_DIR}/b.json"
register_test_user "$C_EMAIL" "$PASSWORD" Paging Carol "${TEMP_DIR}/c.json"
A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"
A_ID="$(json_get "${TEMP_DIR}/a.json" userId)"
B_TOKEN="$(json_get "${TEMP_DIR}/b.json" accessToken)"
B_ID="$(json_get "${TEMP_DIR}/b.json" userId)"
C_TOKEN="$(json_get "${TEMP_DIR}/c.json" accessToken)"
C_ID="$(json_get "${TEMP_DIR}/c.json" userId)"

make_friends() {
  local sender_token="$1"
  local receiver_token="$2"
  local receiver_id="$3"
  local label="$4"
  local request_file="${TEMP_DIR}/${label}-request.json"
  local accept_file="${TEMP_DIR}/${label}-accept.json"
  local status
  status="$(http_request POST "${BASE_URL}/api/friends/requests/${receiver_id}" "$request_file" '' "$sender_token")"
  expect_status "$status" 201 "create ${label} friendship request" "$request_file"
  local request_id
  request_id="$(json_get "$request_file" id)"
  status="$(http_request POST "${BASE_URL}/api/friends/requests/${request_id}/accept" "$accept_file" '' "$receiver_token")"
  expect_status "$status" 204 "accept ${label} friendship request" "$accept_file"
}

make_friends "$A_TOKEN" "$B_TOKEN" "$B_ID" ab
make_friends "$A_TOKEN" "$C_TOKEN" "$C_ID" ac

status="$(http_request POST "${BASE_URL}/api/conversations/direct/${B_ID}" "${TEMP_DIR}/ab-conversation.json" '' "$A_TOKEN")"
expect_status "$status" 201 "start first paged conversation" "${TEMP_DIR}/ab-conversation.json"
AB_CONVERSATION="$(json_get "${TEMP_DIR}/ab-conversation.json" id)"
status="$(http_request POST "${BASE_URL}/api/conversations/direct/${C_ID}" "${TEMP_DIR}/ac-conversation.json" '' "$A_TOKEN")"
expect_status "$status" 201 "start second paged conversation" "${TEMP_DIR}/ac-conversation.json"
AC_CONVERSATION="$(json_get "${TEMP_DIR}/ac-conversation.json" id)"

status="$(e2e_register_device "$A_TOKEN" "pagination-alice-${suffix}" "$(e2e_base64_sequence 1 32)" "${TEMP_DIR}/alice-device.json")"
expect_status "$status" 200 "Alice registers a public chat device key" "${TEMP_DIR}/alice-device.json"
A_DEVICE_KEY_ID="$(json_get "${TEMP_DIR}/alice-device.json" id)"
status="$(e2e_register_device "$B_TOKEN" "pagination-bob-${suffix}" "$(e2e_base64_sequence 40 32)" "${TEMP_DIR}/bob-device.json")"
expect_status "$status" 200 "Bob registers a public chat device key" "${TEMP_DIR}/bob-device.json"
B_DEVICE_KEY_ID="$(json_get "${TEMP_DIR}/bob-device.json" id)"
status="$(e2e_register_device "$C_TOKEN" "pagination-carol-${suffix}" "$(e2e_base64_sequence 80 32)" "${TEMP_DIR}/carol-device.json")"
expect_status "$status" 200 "Carol registers a public chat device key" "${TEMP_DIR}/carol-device.json"
C_DEVICE_KEY_ID="$(json_get "${TEMP_DIR}/carol-device.json" id)"

status="$(e2e_put_envelope "$AB_CONVERSATION" "$A_TOKEN" "$A_DEVICE_KEY_ID" "$A_DEVICE_KEY_ID" "$(e2e_base64_sequence 120 48)" "$(e2e_base64_sequence 170 12)" "${TEMP_DIR}/ab-alice-envelope.json")"
expect_status "$status" 200 "Alice creates her AB conversation-key envelope" "${TEMP_DIR}/ab-alice-envelope.json"
status="$(e2e_put_envelope "$AB_CONVERSATION" "$A_TOKEN" "$A_DEVICE_KEY_ID" "$B_DEVICE_KEY_ID" "$(e2e_base64_sequence 190 48)" "$(e2e_base64_sequence 240 12)" "${TEMP_DIR}/ab-bob-envelope.json")"
expect_status "$status" 200 "Alice creates Bob's AB conversation-key envelope" "${TEMP_DIR}/ab-bob-envelope.json"

status="$(e2e_put_envelope "$AC_CONVERSATION" "$A_TOKEN" "$A_DEVICE_KEY_ID" "$A_DEVICE_KEY_ID" "$(e2e_base64_sequence 20 48)" "$(e2e_base64_sequence 70 12)" "${TEMP_DIR}/ac-alice-envelope.json")"
expect_status "$status" 200 "Alice creates her AC conversation-key envelope" "${TEMP_DIR}/ac-alice-envelope.json"
status="$(e2e_put_envelope "$AC_CONVERSATION" "$A_TOKEN" "$A_DEVICE_KEY_ID" "$C_DEVICE_KEY_ID" "$(e2e_base64_sequence 90 48)" "$(e2e_base64_sequence 140 12)" "${TEMP_DIR}/ac-carol-envelope.json")"
expect_status "$status" 200 "Alice creates Carol's AC conversation-key envelope" "${TEMP_DIR}/ac-carol-envelope.json"

for index in 1 2 3 4 5; do
  status="$(e2e_send_text \
    "$AB_CONVERSATION" \
    "$A_TOKEN" \
    "$A_DEVICE_KEY_ID" \
    "$(e2e_base64_text "pagination-e2e-ciphertext-${index}-${suffix}-authentication-tag")" \
    "$(e2e_base64_sequence "$((10 + index * 13))" 12)" \
    "${TEMP_DIR}/message-${index}.json")"
  expect_status "$status" 201 "create encrypted paged message ${index}" "${TEMP_DIR}/message-${index}.json"
done
status="$(e2e_send_text \
  "$AC_CONVERSATION" \
  "$A_TOKEN" \
  "$A_DEVICE_KEY_ID" \
  "$(e2e_base64_text "pagination-second-conversation-${suffix}-authentication-tag")" \
  "$(e2e_base64_sequence 210 12)" \
  "${TEMP_DIR}/message-c.json")"
expect_status "$status" 201 "create encrypted second-conversation message" "${TEMP_DIR}/message-c.json"

status="$(http_request GET "${BASE_URL}/api/conversations?page=1&pageSize=1" "${TEMP_DIR}/conversations-1.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load first conversation page" "${TEMP_DIR}/conversations-1.json"
status="$(http_request GET "${BASE_URL}/api/conversations?page=2&pageSize=1" "${TEMP_DIR}/conversations-2.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load second conversation page" "${TEMP_DIR}/conversations-2.json"
python3 - "${TEMP_DIR}/conversations-1.json" "${TEMP_DIR}/conversations-2.json" <<'PY'
import json, sys
pages=[json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
if any(len(page.get('items', [])) != 1 for page in pages):
    raise SystemExit('FAIL: conversation pages did not respect pageSize=1')
ids=[page['items'][0]['id'] for page in pages]
if len(set(ids)) != 2:
    raise SystemExit(f'FAIL: duplicate conversation across pages: {ids!r}')
if pages[0].get('totalPages', 0) < 2:
    raise SystemExit('FAIL: conversation pagination metadata is incomplete')
print('PASS: conversation load-more pages are distinct and bounded')
PY

status="$(http_request GET "${BASE_URL}/api/conversations/${AB_CONVERSATION}/messages?page=1&pageSize=2" "${TEMP_DIR}/messages-1.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load newest message page" "${TEMP_DIR}/messages-1.json"
status="$(http_request GET "${BASE_URL}/api/conversations/${AB_CONVERSATION}/messages?page=2&pageSize=2" "${TEMP_DIR}/messages-2.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load older message page" "${TEMP_DIR}/messages-2.json"
python3 - "${TEMP_DIR}/messages-1.json" "${TEMP_DIR}/messages-2.json" <<'PY'
import datetime as dt, json, sys
pages=[json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
items=[item for page in pages for item in page.get('items', [])]
ids=[item['id'] for item in items]
if len(items) != 4 or len(set(ids)) != 4:
    raise SystemExit(f'FAIL: message pages are not distinct: {ids!r}')
for page in pages:
    values=[(item['sentAtUtc'], item['id']) for item in page['items']]
    if values != sorted(values, reverse=True):
        raise SystemExit(f'FAIL: message page is not stably newest-first: {values!r}')
print('PASS: message history pages are stable and non-duplicated')
PY

status="$(http_request GET "${BASE_URL}/api/notifications?page=1&pageSize=2" "${TEMP_DIR}/notifications-1.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load first notification page" "${TEMP_DIR}/notifications-1.json"
status="$(http_request GET "${BASE_URL}/api/notifications?page=2&pageSize=2" "${TEMP_DIR}/notifications-2.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load second notification page" "${TEMP_DIR}/notifications-2.json"
python3 - "${TEMP_DIR}/notifications-1.json" "${TEMP_DIR}/notifications-2.json" <<'PY'
import json, sys
pages=[json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
ids=[item['id'] for page in pages for item in page.get('items', [])]
if len(ids) < 3:
    raise SystemExit(f'FAIL: not enough notification fixtures were created: {ids!r}')
if len(ids) != len(set(ids)):
    raise SystemExit(f'FAIL: duplicate notification across pages: {ids!r}')
print('PASS: notification load-more pages are distinct')
PY

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories?page=1&pageSize=1" "${TEMP_DIR}/categories-1.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load first bounded lookup page" "${TEMP_DIR}/categories-1.json"
status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories?page=2&pageSize=1" "${TEMP_DIR}/categories-2.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load second bounded lookup page" "${TEMP_DIR}/categories-2.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories-1.json" 0.id)"
python3 - "${TEMP_DIR}/categories-1.json" "${TEMP_DIR}/categories-2.json" <<'PY'
import json, sys
pages=[json.load(open(path, encoding='utf-8')) for path in sys.argv[1:]]
if any(len(page) > 1 for page in pages):
    raise SystemExit('FAIL: public reference-data endpoint ignored pageSize=1')
if len(pages[0]) != 1 or len(pages[1]) != 1 or pages[0][0]['id'] == pages[1][0]['id']:
    raise SystemExit(f'FAIL: public reference-data pages are invalid: {pages!r}')
print('PASS: public reference data is server-paged without breaking list clients')
PY
curl -sS -D "${TEMP_DIR}/reference-headers.txt" -o "${TEMP_DIR}/reference-max.json" \
  -H "Authorization: Bearer ${A_TOKEN}" \
  "${BASE_URL}/api/reference-data/task-categories?page=1&pageSize=1000"
python3 - "${TEMP_DIR}/reference-headers.txt" <<'PY'
import re, sys
headers=open(sys.argv[1], encoding='utf-8').read()
match=re.search(r'^X-Page-Size:\s*(\d+)\s*$', headers, re.I | re.M)
if not match or int(match.group(1)) != 100:
    raise SystemExit(f'FAIL: expected X-Page-Size 100, got headers:\n{headers}')
print('PASS: public reference pageSize is capped at 100')
PY

status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types?page=1&pageSize=100" "${TEMP_DIR}/recurrences.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load bounded recurrence lookup" "${TEMP_DIR}/recurrences.json"
find_reference_id() {
  python3 - "$1" "$2" <<'PY'
import json, sys
items=json.load(open(sys.argv[1], encoding='utf-8'))
for item in items:
    if item.get('code', '').lower() == sys.argv[2].lower():
        print(item['id'])
        break
else:
    raise SystemExit(f'No reference code {sys.argv[2]!r}')
PY
}
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"
DAILY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" daily)"
WEEKLY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" weekly)"

create_task() {
  local title="$1"
  local recurrence_id="$2"
  local output="$3"
  local body status
  body="$(printf '{"title":%s,"description":null,"taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false}' \
    "$(json_string "$title")" "$(json_string "$CATEGORY_ID")" "$(json_string "$recurrence_id")")"
  status="$(http_request POST "${BASE_URL}/api/tasks" "$output" "$body" "$A_TOKEN")"
  expect_status "$status" 201 "create ${title}" "$output"
}
create_task "Paged todo ${suffix}" "$NONE_ID" "${TEMP_DIR}/todo.json"
create_task "Paged daily ${suffix}" "$DAILY_ID" "${TEMP_DIR}/daily.json"
create_task "Paged habit ${suffix}" "$WEEKLY_ID" "${TEMP_DIR}/habit.json"
TODO_ID="$(json_get "${TEMP_DIR}/todo.json" id)"
DAILY_TASK_ID="$(json_get "${TEMP_DIR}/daily.json" id)"
HABIT_ID="$(json_get "${TEMP_DIR}/habit.json" id)"

for section in 1 2 3; do
  status="$(http_request GET "${BASE_URL}/api/tasks?section=${section}&page=1&pageSize=10" "${TEMP_DIR}/tasks-${section}.json" '' "$A_TOKEN")"
  expect_status "$status" 200 "load task board section ${section}" "${TEMP_DIR}/tasks-${section}.json"
done
status="$(http_request GET "${BASE_URL}/api/tasks?section=999&page=1&pageSize=10" "${TEMP_DIR}/tasks-invalid-section.json" '' "$A_TOKEN")"
expect_status "$status" 400 "reject unsupported task board section" "${TEMP_DIR}/tasks-invalid-section.json"
python3 - "${TEMP_DIR}/tasks-1.json" "${TEMP_DIR}/tasks-2.json" "${TEMP_DIR}/tasks-3.json" "$TODO_ID" "$DAILY_TASK_ID" "$HABIT_ID" <<'PY'
import json, sys
pages=[json.load(open(path, encoding='utf-8')) for path in sys.argv[1:4]]
expected=sys.argv[4:7]
for index, (page, task_id) in enumerate(zip(pages, expected), start=1):
    ids=[item['id'] for item in page.get('items', [])]
    if task_id not in ids:
        raise SystemExit(f'FAIL: task {task_id} missing from section {index}: {ids!r}')
    recurrence={item['recurrenceCode'].lower() for item in page.get('items', [])}
    allowed={1:{'none'}, 2:{'daily'}, 3:{'weekly','monthly'}}[index]
    if not recurrence.issubset(allowed):
        raise SystemExit(f'FAIL: section {index} contains unsupported recurrence: {recurrence!r}')
print('PASS: To-do board requests only the selected server-side section')
PY

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grep -q 'printing:' "${ROOT_DIR}/apps/ladder_social_admin/pubspec.yaml" || {
  echo 'FAIL: desktop printing dependency is missing' >&2
  exit 1
}
grep -R -q 'Printing.layoutPdf' "${ROOT_DIR}/apps/ladder_social_admin/lib/src/features/reports" || {
  echo 'FAIL: native PDF print implementation is missing' >&2
  exit 1
}
echo 'PASS: desktop reports have a native print implementation'

echo
echo "Pagination and report-printing review test completed successfully against ${BASE_URL}."
