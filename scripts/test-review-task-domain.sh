#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

for command_name in docker; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command '${command_name}' is not installed." >&2
    exit 1
  fi
done

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

find_admin_reference() {
  local file="$1"
  local code="$2"
  python3 - "$file" "$code" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
for item in payload["items"]:
    if str(item.get("code", "")).lower() == sys.argv[2].lower():
        print(json.dumps(item, separators=(",", ":")))
        break
else:
    raise SystemExit(f"Admin recurrence code {sys.argv[2]!r} was not found")
PY
}

assert_completion_options() {
  local file="$1"
  local expected_empty="$2"
  python3 - "$file" "$expected_empty" <<'PY'
from datetime import date
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
business = date.fromisoformat(payload["businessDate"])
anchor = date.fromisoformat(payload["recurrenceAnchorDate"])
allowed = [date.fromisoformat(value) for value in payload["allowedDates"]]
if any(value > business for value in allowed):
    raise SystemExit(f"Future completion date returned: {allowed!r} > {business}")
if any(value < anchor for value in allowed):
    raise SystemExit(f"Pre-anchor completion date returned: {allowed!r} < {anchor}")
expect_empty = sys.argv[2].lower() == "true"
if expect_empty and allowed:
    raise SystemExit(f"Expected no allowed dates, got {allowed!r}")
if not expect_empty and not allowed:
    raise SystemExit("Expected at least one allowed completion date")
PY
}

assert_terminal_task() {
  local file="$1"
  python3 - "$file" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    task = json.load(handle)
assert task["status"] == 2, task
assert task["canEdit"] is False, task
assert task["canComplete"] is False, task
assert task["allowedEditStatuses"] == [], task
PY
}

assert_real_completion_timestamp() {
  local file="$1"
  local expected_occurrence="$2"
  python3 - "$file" "$expected_occurrence" <<'PY'
from datetime import datetime, timezone
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    completion = json.load(handle)
if completion["occurrenceDate"] != sys.argv[2]:
    raise SystemExit(f"Unexpected occurrence date: {completion!r}")
recorded = datetime.fromisoformat(completion["completedAtUtc"].replace("Z", "+00:00"))
now = datetime.now(timezone.utc)
seconds = abs((now - recorded.astimezone(timezone.utc)).total_seconds())
if seconds > 180:
    raise SystemExit(
        f"CompletedAtUtc is not the real recording time: {recorded.isoformat()} vs {now.isoformat()}"
    )
PY
}

suffix="$(date +%s)-$$"
PASSWORD='Domain_Test_220087!'
USER_EMAIL="task-domain-${suffix}@example.com"
register_test_user "$USER_EMAIL" "$PASSWORD" Domain Reviewer "${TEMP_DIR}/user.json"
USER_ACCESS="$(json_get "${TEMP_DIR}/user.json" accessToken)"

ADMIN_EMAIL="$(read_env SEED_ADMIN_EMAIL)"
ADMIN_PASSWORD="$(read_env SEED_ADMIN_PASSWORD)"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@laddersocial.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin_Test_220087!}"
login_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "${TEMP_DIR}/admin.json"
ADMIN_ACCESS="$(json_get "${TEMP_DIR}/admin.json" accessToken)"

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "load task categories" "${TEMP_DIR}/categories.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories.json" 0.id)"

status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "load recurrence types" "${TEMP_DIR}/recurrences.json"
python3 - "${TEMP_DIR}/recurrences.json" <<'PY'
import json, sys
supported = {"none", "daily", "weekly", "monthly"}
with open(sys.argv[1], encoding="utf-8") as handle:
    items = json.load(handle)
returned = {str(item.get("code", "")).strip().lower() for item in items}
unsupported = sorted(returned - supported)
if unsupported:
    raise SystemExit(f"Client recurrence lookup exposed unsupported codes: {unsupported!r}")
PY
echo "PASS: client recurrence lookup exposes only supported semantic codes"
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"
DAILY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" daily)"
WEEKLY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" weekly)"
MONTHLY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" monthly)"

unsupported_body="$(printf '{"name":%s,"code":%s,"sortOrder":999}' \
  "$(json_string "Unsupported recurrence ${suffix}")" \
  "$(json_string every-other-day)")"
status="$(http_request POST "${BASE_URL}/api/admin/reference-data/recurrence-types" "${TEMP_DIR}/unsupported-recurrence.json" "$unsupported_body" "$ADMIN_ACCESS")"
expect_status "$status" 400 "administrator cannot create an unsupported recurrence code" "${TEMP_DIR}/unsupported-recurrence.json"

status="$(http_request GET "${BASE_URL}/api/admin/reference-data/recurrence-types?page=1&pageSize=100" "${TEMP_DIR}/admin-recurrences.json" '' "$ADMIN_ACCESS")"
expect_status "$status" 200 "load administrator recurrence types" "${TEMP_DIR}/admin-recurrences.json"
WEEKLY_JSON="$(find_admin_reference "${TEMP_DIR}/admin-recurrences.json" weekly)"
WEEKLY_ADMIN_ID="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$WEEKLY_JSON")"
WEEKLY_NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["name"])' "$WEEKLY_JSON")"
WEEKLY_ORDER="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["sortOrder"])' "$WEEKLY_JSON")"
WEEKLY_ACTIVE="$(python3 -c 'import json,sys; print(str(json.loads(sys.argv[1])["isActive"]).lower())' "$WEEKLY_JSON")"
immutable_body="$(printf '{"name":%s,"code":"daily","isActive":%s,"sortOrder":%s}' \
  "$(json_string "$WEEKLY_NAME")" "$WEEKLY_ACTIVE" "$WEEKLY_ORDER")"
status="$(http_request PUT "${BASE_URL}/api/admin/reference-data/recurrence-types/${WEEKLY_ADMIN_ID}" "${TEMP_DIR}/immutable-recurrence.json" "$immutable_body" "$ADMIN_ACCESS")"
expect_status "$status" 400 "supported recurrence behavior code is immutable" "${TEMP_DIR}/immutable-recurrence.json"

TODAY="$(date -u +%F)"
YESTERDAY="$(python3 - <<'PY'
from datetime import datetime, timezone, timedelta
print((datetime.now(timezone.utc).date() - timedelta(days=1)).isoformat())
PY
)"
TOMORROW="$(python3 - <<'PY'
from datetime import datetime, timezone, timedelta
print((datetime.now(timezone.utc).date() + timedelta(days=1)).isoformat())
PY
)"
NEXT_WEEK="$(python3 - <<'PY'
from datetime import datetime, timezone, timedelta
print((datetime.now(timezone.utc).date() + timedelta(days=7)).isoformat())
PY
)"
NEXT_MONTH="$(python3 - <<'PY'
from datetime import datetime, timezone, timedelta
print((datetime.now(timezone.utc).date() + timedelta(days=31)).isoformat())
PY
)"

create_task() {
  local title="$1"
  local recurrence_id="$2"
  local due_at="$3"
  local output="$4"
  local due_json="null"
  if [[ -n "$due_at" ]]; then
    due_json="$(json_string "${due_at}T10:00:00Z")"
  fi
  local body
  body="$(printf '{"title":%s,"description":"Professor review phase-one test","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":%s,"requiresProofImage":false,"shareWithFriends":false}' \
    "$(json_string "$title")" \
    "$(json_string "$CATEGORY_ID")" \
    "$(json_string "$recurrence_id")" \
    "$due_json")"
  local status_code
  status_code="$(http_request POST "${BASE_URL}/api/tasks" "$output" "$body" "$USER_ACCESS")"
  expect_status "$status_code" 201 "create ${title}" "$output"
}

create_task "Future weekly anchor ${suffix}" "$WEEKLY_ID" "$NEXT_WEEK" "${TEMP_DIR}/future-weekly.json"
FUTURE_WEEKLY_ID="$(json_get "${TEMP_DIR}/future-weekly.json" id)"
status="$(http_request GET "${BASE_URL}/api/tasks/${FUTURE_WEEKLY_ID}/completion-date-options" "${TEMP_DIR}/future-weekly-options.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "weekly completion options" "${TEMP_DIR}/future-weekly-options.json"
assert_completion_options "${TEMP_DIR}/future-weekly-options.json" true
echo "PASS: weekly completion options exclude dates before the future anchor"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${FUTURE_WEEKLY_ID}/complete" "${TEMP_DIR}/future-weekly-complete.json" "$USER_ACCESS" -F "occurrenceDate=${TODAY}")"
expect_status "$status" 400 "weekly completion before recurrence anchor is rejected" "${TEMP_DIR}/future-weekly-complete.json"

create_task "Future monthly anchor ${suffix}" "$MONTHLY_ID" "$NEXT_MONTH" "${TEMP_DIR}/future-monthly.json"
FUTURE_MONTHLY_ID="$(json_get "${TEMP_DIR}/future-monthly.json" id)"
status="$(http_request GET "${BASE_URL}/api/tasks/${FUTURE_MONTHLY_ID}/completion-date-options" "${TEMP_DIR}/future-monthly-options.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "monthly completion options" "${TEMP_DIR}/future-monthly-options.json"
assert_completion_options "${TEMP_DIR}/future-monthly-options.json" true
echo "PASS: monthly completion options exclude dates before the future anchor"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${FUTURE_MONTHLY_ID}/complete" "${TEMP_DIR}/future-monthly-complete.json" "$USER_ACCESS" -F "occurrenceDate=${TODAY}")"
expect_status "$status" 400 "monthly completion before recurrence anchor is rejected" "${TEMP_DIR}/future-monthly-complete.json"

create_task "Daily future guard ${suffix}" "$DAILY_ID" '' "${TEMP_DIR}/daily-future.json"
DAILY_FUTURE_ID="$(json_get "${TEMP_DIR}/daily-future.json" id)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${DAILY_FUTURE_ID}/complete" "${TEMP_DIR}/daily-future-complete.json" "$USER_ACCESS" -F "occurrenceDate=${TOMORROW}")"
expect_status "$status" 400 "future completion date is rejected" "${TEMP_DIR}/daily-future-complete.json"
status="$(http_request GET "${BASE_URL}/api/tasks/${DAILY_FUTURE_ID}/completion-date-options" "${TEMP_DIR}/daily-options.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "daily completion options" "${TEMP_DIR}/daily-options.json"
assert_completion_options "${TEMP_DIR}/daily-options.json" false
echo "PASS: date options expose only non-future, post-anchor occurrences"

invalid_status_body="$(printf '{"title":%s,"description":null,"taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false,"status":999}' \
  "$(json_string "Invalid status ${suffix}")" \
  "$(json_string "$CATEGORY_ID")" \
  "$(json_string "$DAILY_ID")")"
status="$(http_request PUT "${BASE_URL}/api/tasks/${DAILY_FUTURE_ID}" "${TEMP_DIR}/invalid-status.json" "$invalid_status_body" "$USER_ACCESS")"
expect_status "$status" 400 "undefined numeric task status is rejected" "${TEMP_DIR}/invalid-status.json"

create_task "Terminal task ${suffix}" "$NONE_ID" '' "${TEMP_DIR}/terminal-task.json"
TERMINAL_ID="$(json_get "${TEMP_DIR}/terminal-task.json" id)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${TERMINAL_ID}/complete" "${TEMP_DIR}/terminal-completion.json" "$USER_ACCESS" -F "occurrenceDate=${TODAY}")"
expect_status "$status" 201 "complete terminal one-time task" "${TEMP_DIR}/terminal-completion.json"
reopen_body="$(printf '{"title":%s,"description":null,"taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false,"status":1}' \
  "$(json_string "Terminal task reopened ${suffix}")" \
  "$(json_string "$CATEGORY_ID")" \
  "$(json_string "$NONE_ID")")"
status="$(http_request PUT "${BASE_URL}/api/tasks/${TERMINAL_ID}" "${TEMP_DIR}/terminal-reopen.json" "$reopen_body" "$USER_ACCESS")"
expect_status "$status" 400 "completed task cannot be reopened through ordinary edit" "${TEMP_DIR}/terminal-reopen.json"
status="$(http_request GET "${BASE_URL}/api/tasks/${TERMINAL_ID}" "${TEMP_DIR}/terminal-detail.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "load terminal task state metadata" "${TEMP_DIR}/terminal-detail.json"
assert_terminal_task "${TEMP_DIR}/terminal-detail.json"
echo "PASS: completed task is exposed as terminal to the client"

create_task "Historical completion ${suffix}" "$DAILY_ID" '' "${TEMP_DIR}/historical-task.json"
HISTORICAL_ID="$(json_get "${TEMP_DIR}/historical-task.json" id)"
SQL_PASSWORD="$(read_env SQL_SA_PASSWORD)"
DB_NAME="$(read_env DATABASE_NAME)"
DB_NAME="${DB_NAME:-220087}"
(
  cd "$ROOT_DIR"
  docker compose --env-file "$ENV_FILE" exec -T database \
    /opt/mssql-tools18/bin/sqlcmd \
    -S 127.0.0.1 \
    -U sa \
    -P "$SQL_PASSWORD" \
    -C \
    -b \
    -d "$DB_NAME" \
    -Q "UPDATE dbo.Tasks SET CreatedAtUtc = DATEADD(day, -5, SYSUTCDATETIME()) WHERE Id = '${HISTORICAL_ID}';"
)
status="$(http_request GET "${BASE_URL}/api/tasks/${HISTORICAL_ID}/completion-date-options" "${TEMP_DIR}/historical-options.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "load historical completion options" "${TEMP_DIR}/historical-options.json"
python3 - "${TEMP_DIR}/historical-options.json" "$YESTERDAY" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if sys.argv[2] not in payload["allowedDates"]:
    raise SystemExit(f"Yesterday was not offered as a valid daily occurrence: {payload!r}")
PY
echo "PASS: valid historical occurrence is offered by the completion API"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${HISTORICAL_ID}/complete" "${TEMP_DIR}/historical-completion.json" "$USER_ACCESS" -F "occurrenceDate=${YESTERDAY}")"
expect_status "$status" 201 "record a backdated occurrence" "${TEMP_DIR}/historical-completion.json"
assert_real_completion_timestamp "${TEMP_DIR}/historical-completion.json" "$YESTERDAY"
echo "PASS: OccurrenceDate and real CompletedAtUtc have separate meanings"
status="$(http_request GET "${BASE_URL}/api/tasks/${HISTORICAL_ID}" "${TEMP_DIR}/historical-detail.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "reload recurring task after completion" "${TEMP_DIR}/historical-detail.json"
python3 - "${TEMP_DIR}/historical-detail.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    task = json.load(handle)
assert task["status"] == 1, task
assert task["canEdit"] is True, task
PY
echo "PASS: recurring task remains active after an occurrence completion"

status="$(http_request GET "${BASE_URL}/api/profile/me/overview" "${TEMP_DIR}/overview-before-delete.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "load completion statistics before soft delete" "${TEMP_DIR}/overview-before-delete.json"
COUNT_BEFORE="$(json_get "${TEMP_DIR}/overview-before-delete.json" completedTaskCount)"
status="$(http_request DELETE "${BASE_URL}/api/tasks/${HISTORICAL_ID}" "${TEMP_DIR}/delete-historical.json" '' "$USER_ACCESS")"
expect_status "$status" 204 "soft-delete task with historical completion" "${TEMP_DIR}/delete-historical.json"
status="$(http_request GET "${BASE_URL}/api/profile/me/overview" "${TEMP_DIR}/overview-after-delete.json" '' "$USER_ACCESS")"
expect_status "$status" 200 "load completion statistics after soft delete" "${TEMP_DIR}/overview-after-delete.json"
COUNT_AFTER="$(json_get "${TEMP_DIR}/overview-after-delete.json" completedTaskCount)"
if [[ "$COUNT_BEFORE" != "$COUNT_AFTER" ]]; then
  echo "FAIL: historical completion count changed after soft delete (${COUNT_BEFORE} -> ${COUNT_AFTER})" >&2
  exit 1
fi
echo "PASS: soft delete hides future task work without erasing completion history"

echo
echo "Professor-review task-domain consistency smoke test completed successfully against ${BASE_URL}."
