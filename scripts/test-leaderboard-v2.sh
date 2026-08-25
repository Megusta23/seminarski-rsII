#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

find_reference_id() {
  python3 - "$1" "$2" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    items = json.load(handle)
for item in items:
    if str(item.get("code", "")).lower() == sys.argv[2].lower():
        print(item["id"])
        break
else:
    raise SystemExit(f"Missing reference code {sys.argv[2]!r}")
PY
}

assert_leaderboard() {
  local file="$1" current_id="$2" first_id="$3" second_id="$4" excluded_id="$5" expected_first_score="$6" expected_second_score="$7"
  python3 - "$file" "$current_id" "$first_id" "$second_id" "$excluded_id" "$expected_first_score" "$expected_second_score" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
current_id, first_id, second_id, excluded_id = sys.argv[2:6]
first_score, second_score = map(int, sys.argv[6:8])
entries = payload["entries"]
by_id = {str(item["userId"]): item for item in entries}
if first_id not in by_id or second_id not in by_id or current_id not in by_id:
    raise SystemExit(f"Expected current user and both friends in leaderboard: {entries!r}")
if excluded_id in by_id:
    raise SystemExit(f"Non-friend unexpectedly appeared in leaderboard: {entries!r}")
if int(by_id[first_id]["position"]) != 1 or int(by_id[first_id]["score"]) != first_score:
    raise SystemExit(f"Unexpected first-place entry: {by_id[first_id]!r}")
if int(by_id[second_id]["position"]) != 2 or int(by_id[second_id]["score"]) != second_score:
    raise SystemExit(f"Unexpected second-place entry: {by_id[second_id]!r}")
if not bool(by_id[current_id]["isCurrentUser"]):
    raise SystemExit(f"Current user flag is missing: {by_id[current_id]!r}")
current = payload.get("currentUser")
if not current or str(current.get("userId")) != current_id:
    raise SystemExit(f"Current-user summary is incorrect: {current!r}")
positions = [int(item["position"]) for item in entries]
if positions != list(range(1, len(entries) + 1)):
    raise SystemExit(f"Leaderboard positions are not contiguous: {positions!r}")
PY
}

create_and_complete_task() {
  local token="$1" label="$2" number="$3"
  local task_file="${TEMP_DIR}/${label}-task-${number}.json"
  local completion_file="${TEMP_DIR}/${label}-completion-${number}.json"
  local task_body task_id status
  task_body="$(printf '{"title":%s,"description":"Leaderboard V2 fixture","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false}' \
    "$(json_string "Leaderboard ${label} ${number} ${suffix}")" \
    "$(json_string "$CATEGORY_ID")" \
    "$(json_string "$NONE_ID")")"
  status="$(http_request POST "${BASE_URL}/api/tasks" "$task_file" "$task_body" "$token")"
  expect_status "$status" 201 "create ${label} leaderboard task ${number}" "$task_file"
  task_id="$(json_get "$task_file" id)"
  status="$(multipart_request POST "${BASE_URL}/api/tasks/${task_id}/complete" "$completion_file" "$token" \
    -F "occurrenceDate=${TODAY}" -F "caption=Leaderboard V2 completion")"
  expect_status "$status" 201 "complete ${label} leaderboard task ${number}" "$completion_file"
}

suffix="$(date +%s)-$$"
PASSWORD='Leaderboard_Test_220087!'
A_EMAIL="ranking-a-${suffix}@example.com"
B_EMAIL="ranking-b-${suffix}@example.com"
C_EMAIL="ranking-c-${suffix}@example.com"
D_EMAIL="ranking-outsider-${suffix}@example.com"
register_test_user "$A_EMAIL" "$PASSWORD" Alice Ranking "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Bob Ranking "${TEMP_DIR}/b.json"
register_test_user "$C_EMAIL" "$PASSWORD" Carol Ranking "${TEMP_DIR}/c.json"
register_test_user "$D_EMAIL" "$PASSWORD" Derek Outsider "${TEMP_DIR}/d.json"
A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"; A_ID="$(json_get "${TEMP_DIR}/a.json" userId)"
B_TOKEN="$(json_get "${TEMP_DIR}/b.json" accessToken)"; B_ID="$(json_get "${TEMP_DIR}/b.json" userId)"
C_TOKEN="$(json_get "${TEMP_DIR}/c.json" accessToken)"; C_ID="$(json_get "${TEMP_DIR}/c.json" userId)"
D_TOKEN="$(json_get "${TEMP_DIR}/d.json" accessToken)"; D_ID="$(json_get "${TEMP_DIR}/d.json" userId)"

status="$(http_request GET "${BASE_URL}/api/leaderboard/daily" "${TEMP_DIR}/anonymous.json")"
expect_status "$status" 401 "anonymous leaderboard access is rejected" "${TEMP_DIR}/anonymous.json"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${B_ID}" "${TEMP_DIR}/a-b-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice sends Bob a friend request" "${TEMP_DIR}/a-b-request.json"
AB_REQUEST_ID="$(json_get "${TEMP_DIR}/a-b-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${AB_REQUEST_ID}/accept" "${TEMP_DIR}/a-b-accept.json" '' "$B_TOKEN")"
expect_status "$status" 204 "Bob accepts Alice" "${TEMP_DIR}/a-b-accept.json"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${C_ID}" "${TEMP_DIR}/a-c-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice sends Carol a friend request" "${TEMP_DIR}/a-c-request.json"
AC_REQUEST_ID="$(json_get "${TEMP_DIR}/a-c-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${AC_REQUEST_ID}/accept" "${TEMP_DIR}/a-c-accept.json" '' "$C_TOKEN")"
expect_status "$status" 204 "Carol accepts Alice" "${TEMP_DIR}/a-c-accept.json"

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load leaderboard task category" "${TEMP_DIR}/categories.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories.json" 0.id)"
status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load leaderboard recurrence" "${TEMP_DIR}/recurrences.json"
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"
TODAY="$(date -u +%F)"

create_and_complete_task "$B_TOKEN" bob 1
create_and_complete_task "$B_TOKEN" bob 2
create_and_complete_task "$C_TOKEN" carol 1
create_and_complete_task "$D_TOKEN" outsider 1
create_and_complete_task "$D_TOKEN" outsider 2
create_and_complete_task "$D_TOKEN" outsider 3

status="$(http_request GET "${BASE_URL}/api/leaderboard/daily?date=${TODAY}" "${TEMP_DIR}/daily.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load document-aligned daily leaderboard" "${TEMP_DIR}/daily.json"
assert_leaderboard "${TEMP_DIR}/daily.json" "$A_ID" "$B_ID" "$C_ID" "$D_ID" 2 1
echo "PASS: daily ranking includes current user and accepted friends only"

status="$(http_request GET "${BASE_URL}/api/leaderboard/weekly?weekContaining=${TODAY}" "${TEMP_DIR}/weekly.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load weekly leaderboard" "${TEMP_DIR}/weekly.json"
assert_leaderboard "${TEMP_DIR}/weekly.json" "$A_ID" "$B_ID" "$C_ID" "$D_ID" 2 1
echo "PASS: weekly ranking preserves server-calculated scores and positions"

status="$(http_request DELETE "${BASE_URL}/api/friends/${B_ID}" "${TEMP_DIR}/remove-bob.json" '' "$A_TOKEN")"
expect_status "$status" 204 "Alice removes Bob" "${TEMP_DIR}/remove-bob.json"
status="$(http_request GET "${BASE_URL}/api/leaderboard/daily?date=${TODAY}" "${TEMP_DIR}/after-remove.json" '' "$A_TOKEN")"
expect_status "$status" 200 "reload leaderboard after friendship removal" "${TEMP_DIR}/after-remove.json"
python3 - "${TEMP_DIR}/after-remove.json" "$B_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if any(str(item.get("userId")) == sys.argv[2] for item in payload["entries"]):
    raise SystemExit("Removed friend still appears in the leaderboard")
PY
echo "PASS: removed friends immediately disappear from ranking"

echo
echo "Leaderboard V2 daily/weekly score, friendship and current-user smoke test completed successfully against ${BASE_URL}."
