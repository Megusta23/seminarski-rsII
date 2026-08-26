#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

find_reference_id() {
  local file="$1"
  local code="$2"
  python3 - "$file" "$code" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    items = json.load(handle)
for item in items:
    if str(item.get("code", "")).lower() == sys.argv[2].lower():
        print(item["id"])
        break
else:
    raise SystemExit(f"Reference code {sys.argv[2]!r} was not found")
PY
}

suffix="$(date +%s)-$$"
email="todo-v2-${suffix}@example.com"
password='Todo_V2_Test_220087!'
register_test_user "$email" "$password" Todo Board "${TEMP_DIR}/user.json"
access="$(json_get "${TEMP_DIR}/user.json" accessToken)"

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$access")"
expect_status "$status" 200 "load To-do V2 categories" "${TEMP_DIR}/categories.json"
status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$access")"
expect_status "$status" 200 "load To-do V2 recurrence types" "${TEMP_DIR}/recurrences.json"

WORK_ID="$(find_reference_id "${TEMP_DIR}/categories.json" work)"
SOCIAL_ID="$(find_reference_id "${TEMP_DIR}/categories.json" social)"
SELF_CARE_ID="$(find_reference_id "${TEMP_DIR}/categories.json" self-care)"
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"
DAILY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" daily)"
WEEKLY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" weekly)"

create_task() {
  local output="$1"
  local title="$2"
  local category_id="$3"
  local recurrence_id="$4"
  local proof="$5"
  local body
  body="$(printf '{"title":%s,"description":null,"taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":%s,"shareWithFriends":false}' \
    "$(json_string "$title")" "$(json_string "$category_id")" "$(json_string "$recurrence_id")" "$proof")"
  local status
  status="$(http_request POST "${BASE_URL}/api/tasks" "$output" "$body" "$access")"
  expect_status "$status" 201 "create ${title}" "$output"
}

create_task "${TEMP_DIR}/todo.json" "To-do board item ${suffix}" "$WORK_ID" "$NONE_ID" false
create_task "${TEMP_DIR}/daily.json" "Daily board item ${suffix}" "$SELF_CARE_ID" "$DAILY_ID" true
create_task "${TEMP_DIR}/habit.json" "Habit board item ${suffix}" "$SOCIAL_ID" "$WEEKLY_ID" false

TODO_ID="$(json_get "${TEMP_DIR}/todo.json" id)"
DAILY_TASK_ID="$(json_get "${TEMP_DIR}/daily.json" id)"
HABIT_ID="$(json_get "${TEMP_DIR}/habit.json" id)"

status="$(http_request GET "${BASE_URL}/api/tasks?page=1&pageSize=100&sortBy=dueAtUtc&sortDirection=asc" "${TEMP_DIR}/list-before.json" '' "$access")"
expect_status "$status" 200 "load To-do V2 task board data" "${TEMP_DIR}/list-before.json"

python3 - "${TEMP_DIR}/list-before.json" "$TODO_ID" "$DAILY_TASK_ID" "$HABIT_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
items = {item["id"]: item for item in payload["items"]}
expected = {
    sys.argv[2]: ("none", False),
    sys.argv[3]: ("daily", True),
    sys.argv[4]: ("weekly", False),
}
for task_id, (recurrence, proof) in expected.items():
    item = items.get(task_id)
    if item is None:
        raise SystemExit(f"Task {task_id} is missing from the board response")
    if item.get("recurrenceCode", "").lower() != recurrence:
        raise SystemExit(f"Task {task_id} has wrong recurrence: {item}")
    if bool(item.get("requiresProofImage")) != proof:
        raise SystemExit(f"Task {task_id} has wrong proof state: {item}")
    if item.get("isCompletedForToday") is not False:
        raise SystemExit(f"Task {task_id} should initially be unfinished: {item}")
print("PASS: API supplies To-do, Daily and Habit grouping fields")
PY

TODAY="$(date -u +%F)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${TODO_ID}/complete" "${TEMP_DIR}/todo-completion.json" "$access" \
  -F "occurrenceDate=${TODAY}")"
expect_status "$status" 201 "complete To-do V2 plain task" "${TEMP_DIR}/todo-completion.json"

python3 - "${TEMP_DIR}/proof.png" <<'PY'
import base64, pathlib, sys
pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
PY
status="$(multipart_request POST "${BASE_URL}/api/tasks/${DAILY_TASK_ID}/complete" "${TEMP_DIR}/daily-completion.json" "$access" \
  -F "occurrenceDate=${TODAY}" -F "proofImage=@${TEMP_DIR}/proof.png;type=image/png")"
expect_status "$status" 201 "complete To-do V2 proof task" "${TEMP_DIR}/daily-completion.json"

status="$(http_request GET "${BASE_URL}/api/tasks?page=1&pageSize=100" "${TEMP_DIR}/list-after.json" '' "$access")"
expect_status "$status" 200 "reload To-do V2 completion states" "${TEMP_DIR}/list-after.json"
python3 - "${TEMP_DIR}/list-after.json" "$TODO_ID" "$DAILY_TASK_ID" "$HABIT_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
items = {item["id"]: item for item in payload["items"]}
if items[sys.argv[2]].get("isCompletedForToday") is not True:
    raise SystemExit("Plain task did not become completed for today")
if items[sys.argv[3]].get("isCompletedForToday") is not True:
    raise SystemExit("Proof task did not become completed for today")
if items[sys.argv[4]].get("isCompletedForToday") is not False:
    raise SystemExit("Uncompleted habit has an incorrect completion state")
print("PASS: API supplies all four completion/proof inputs used by To-do V2")
PY

echo
echo "To-do V2 grouping and completion-state smoke test completed successfully against ${BASE_URL}."
