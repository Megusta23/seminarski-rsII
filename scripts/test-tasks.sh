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
    items=json.load(handle)
for item in items:
    if str(item.get("code", "")).lower() == sys.argv[2].lower():
        print(item["id"])
        break
else:
    raise SystemExit(f"Reference code {sys.argv[2]!r} was not found in {items!r}")
PY
}

suffix="$(date +%s)-$$"
PASSWORD='Task_Test_220087!'
OWNER_EMAIL="task-owner-${suffix}@example.com"
OTHER_EMAIL="task-other-${suffix}@example.com"
register_test_user "$OWNER_EMAIL" "$PASSWORD" Task Owner "${TEMP_DIR}/owner.json"
register_test_user "$OTHER_EMAIL" "$PASSWORD" Other User "${TEMP_DIR}/other.json"
OWNER_ACCESS="$(json_get "${TEMP_DIR}/owner.json" accessToken)"
OTHER_ACCESS="$(json_get "${TEMP_DIR}/other.json" accessToken)"

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$OWNER_ACCESS")"
expect_status "$status" 200 "load task categories" "${TEMP_DIR}/categories.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories.json" 0.id)"
status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$OWNER_ACCESS")"
expect_status "$status" 200 "load recurrence types" "${TEMP_DIR}/recurrences.json"
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"
DAILY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" daily)"

TITLE="Seminar task ${suffix}"
create_body="$(printf '{"title":%s,"description":"Task CRUD smoke test","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false}' \
  "$(json_string "$TITLE")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/task.json" "$create_body" "$OWNER_ACCESS")"
expect_status "$status" 201 "create one-time task" "${TEMP_DIR}/task.json"
TASK_ID="$(json_get "${TEMP_DIR}/task.json" id)"

status="$(http_request GET "${BASE_URL}/api/tasks/${TASK_ID}" "${TEMP_DIR}/task-detail.json" '' "$OWNER_ACCESS")"
expect_status "$status" 200 "load own task details" "${TEMP_DIR}/task-detail.json"
status="$(http_request GET "${BASE_URL}/api/tasks/${TASK_ID}" "${TEMP_DIR}/other-task-detail.json" '' "$OTHER_ACCESS")"
expect_status "$status" 404 "other user cannot access task" "${TEMP_DIR}/other-task-detail.json"

encoded_title="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$TITLE")"
status="$(http_request GET "${BASE_URL}/api/tasks?search=${encoded_title}&page=1&pageSize=1" "${TEMP_DIR}/task-list.json" '' "$OWNER_ACCESS")"
expect_status "$status" 200 "task search and pagination" "${TEMP_DIR}/task-list.json"
json_array_contains "${TEMP_DIR}/task-list.json" items id "$TASK_ID"
echo "PASS: created task appears in filtered list"

updated_body="$(printf '{"title":%s,"description":"Updated task description","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false,"status":1}' \
  "$(json_string "${TITLE} Updated")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")")"
status="$(http_request PUT "${BASE_URL}/api/tasks/${TASK_ID}" "${TEMP_DIR}/task-updated.json" "$updated_body" "$OWNER_ACCESS")"
expect_status "$status" 200 "update own task" "${TEMP_DIR}/task-updated.json"

TODAY="$(date -u +%F)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${TASK_ID}/complete" "${TEMP_DIR}/completion.json" "$OWNER_ACCESS" \
  -F "occurrenceDate=${TODAY}" -F "note=Completed by smoke test")"
expect_status "$status" 201 "complete one-time task" "${TEMP_DIR}/completion.json"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${TASK_ID}/complete" "${TEMP_DIR}/completion-again.json" "$OWNER_ACCESS" \
  -F "occurrenceDate=${TODAY}")"
expect_status "$status" 400 "completed one-time task cannot be completed again" "${TEMP_DIR}/completion-again.json"

# A recurring task stays active and exercises duplicate-occurrence protection.
daily_body="$(printf '{"title":%s,"description":null,"taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false}' \
  "$(json_string "Daily task ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$DAILY_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/daily-task.json" "$daily_body" "$OWNER_ACCESS")"
expect_status "$status" 201 "create daily recurring task" "${TEMP_DIR}/daily-task.json"
DAILY_TASK_ID="$(json_get "${TEMP_DIR}/daily-task.json" id)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${DAILY_TASK_ID}/complete" "${TEMP_DIR}/daily-completion.json" "$OWNER_ACCESS" -F "occurrenceDate=${TODAY}")"
expect_status "$status" 201 "complete daily task occurrence" "${TEMP_DIR}/daily-completion.json"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${DAILY_TASK_ID}/complete" "${TEMP_DIR}/daily-duplicate.json" "$OWNER_ACCESS" -F "occurrenceDate=${TODAY}")"
expect_status "$status" 409 "duplicate daily occurrence rejected" "${TEMP_DIR}/daily-duplicate.json"

# Proof-image validation and protected download.
python3 - "${TEMP_DIR}/proof.png" <<'PY'
import base64, pathlib, sys
# Valid 1x1 PNG.
data=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
pathlib.Path(sys.argv[1]).write_bytes(data)
PY
proof_body="$(printf '{"title":%s,"description":null,"taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":true,"shareWithFriends":true}' \
  "$(json_string "Proof task ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$DAILY_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/proof-task.json" "$proof_body" "$OWNER_ACCESS")"
expect_status "$status" 201 "create proof-required task" "${TEMP_DIR}/proof-task.json"
PROOF_TASK_ID="$(json_get "${TEMP_DIR}/proof-task.json" id)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${PROOF_TASK_ID}/complete" "${TEMP_DIR}/missing-proof.json" "$OWNER_ACCESS" -F "occurrenceDate=${TODAY}")"
expect_status "$status" 400 "required proof is enforced" "${TEMP_DIR}/missing-proof.json"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${PROOF_TASK_ID}/complete" "${TEMP_DIR}/proof-completion.json" "$OWNER_ACCESS" \
  -F "occurrenceDate=${TODAY}" -F "caption=Shared proof" -F "proofImage=@${TEMP_DIR}/proof.png;type=image/png")"
expect_status "$status" 201 "complete task with valid proof image" "${TEMP_DIR}/proof-completion.json"
PROOF_MEDIA_ID="$(json_get "${TEMP_DIR}/proof-completion.json" proofMediaId)"
status="$(curl -sS -o "${TEMP_DIR}/downloaded-proof.png" -w "%{http_code}" \
  -H "Authorization: Bearer ${OWNER_ACCESS}" \
  "${BASE_URL}/api/media/task-proofs/${PROOF_MEDIA_ID}")"
expect_status "$status" 200 "owner downloads protected proof image" "${TEMP_DIR}/downloaded-proof.png"

status="$(http_request DELETE "${BASE_URL}/api/tasks/${DAILY_TASK_ID}" "${TEMP_DIR}/delete.json" '' "$OWNER_ACCESS")"
expect_status "$status" 204 "delete own task" "${TEMP_DIR}/delete.json"
status="$(http_request GET "${BASE_URL}/api/tasks/${DAILY_TASK_ID}" "${TEMP_DIR}/deleted-detail.json" '' "$OWNER_ACCESS")"
expect_status "$status" 404 "deleted task is hidden by soft-delete filter" "${TEMP_DIR}/deleted-detail.json"

echo
echo "Task CRUD, completion, ownership, recurrence and proof-media smoke test completed successfully against ${BASE_URL}."
