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

assert_feed_item() {
  local file="$1" id="$2" activity_type="$3" viewed="${4:-}"
  python3 - "$file" "$id" "$activity_type" "$viewed" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
expected_id, expected_type, expected_viewed = sys.argv[2], int(sys.argv[3]), sys.argv[4]
for item in payload["items"]:
    if str(item.get("id")) == expected_id:
        if int(item.get("activityType", 0)) != expected_type:
            raise SystemExit(f"Feed item {expected_id} has activityType={item.get('activityType')}, expected {expected_type}")
        if expected_viewed:
            actual = str(bool(item.get("hasBeenViewed"))).lower()
            if actual != expected_viewed.lower():
                raise SystemExit(f"Feed item {expected_id} has hasBeenViewed={actual}, expected {expected_viewed}")
        print(expected_id)
        break
else:
    raise SystemExit(f"Feed item {expected_id} was not found: {payload['items']!r}")
PY
}

assert_feed_missing() {
  local file="$1" id="$2"
  python3 - "$file" "$id" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if any(str(item.get("id")) == sys.argv[2] for item in payload["items"]):
    raise SystemExit(f"Feed unexpectedly contains {sys.argv[2]}: {payload['items']!r}")
PY
}

assert_friend_progress() {
  local file="$1" user_id="$2" completed="$3" scheduled="$4" percentage="$5"
  python3 - "$file" "$user_id" "$completed" "$scheduled" "$percentage" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
for item in payload["friendProgress"]:
    if str(item.get("userId")) == sys.argv[2]:
        actual = (int(item["completedToday"]), int(item["scheduledToday"]), int(item["percentage"]))
        expected = tuple(map(int, sys.argv[3:6]))
        if actual != expected:
            raise SystemExit(f"Progress mismatch: expected {expected}, got {actual}")
        break
else:
    raise SystemExit(f"No progress entry for {sys.argv[2]}")
PY
}

suffix="$(date +%s)-$$"
PASSWORD='Feed_Test_220087!'
A_EMAIL="feed-viewer-${suffix}@example.com"
B_EMAIL="feed-friend-${suffix}@example.com"
C_EMAIL="feed-outsider-${suffix}@example.com"

status="$(http_request GET "${BASE_URL}/api/feed" "${TEMP_DIR}/anonymous.json")"
expect_status "$status" 401 "feed rejects anonymous access" "${TEMP_DIR}/anonymous.json"

register_test_user "$A_EMAIL" "$PASSWORD" Feed Viewer "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Feed Friend "${TEMP_DIR}/b.json"
register_test_user "$C_EMAIL" "$PASSWORD" Feed Outsider "${TEMP_DIR}/c.json"
A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"; A_ID="$(json_get "${TEMP_DIR}/a.json" userId)"
B_TOKEN="$(json_get "${TEMP_DIR}/b.json" accessToken)"; B_ID="$(json_get "${TEMP_DIR}/b.json" userId)"
C_TOKEN="$(json_get "${TEMP_DIR}/c.json" accessToken)"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${B_ID}" "${TEMP_DIR}/friend-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "viewer sends feed friend request" "${TEMP_DIR}/friend-request.json"
REQUEST_ID="$(json_get "${TEMP_DIR}/friend-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${REQUEST_ID}/accept" "${TEMP_DIR}/friend-accept.json" '' "$B_TOKEN")"
expect_status "$status" 204 "feed friend accepts request" "${TEMP_DIR}/friend-accept.json"

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load feed task category" "${TEMP_DIR}/categories.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories.json" 0.id)"
status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load feed recurrence" "${TEMP_DIR}/recurrences.json"
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"
TODAY="$(date -u +%F)"
DUE_AT="${TODAY}T18:00:00Z"

create_task() {
  local output="$1" title="$2" shared="$3" proof="$4"
  local body
  body="$(printf '{"title":%s,"description":"Feed V2 smoke-test fixture","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":%s,"requiresProofImage":%s,"shareWithFriends":%s}' \
    "$(json_string "$title")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")" "$(json_string "$DUE_AT")" "$proof" "$shared")"
  local status
  status="$(http_request POST "${BASE_URL}/api/tasks" "$output" "$body" "$B_TOKEN")"
  expect_status "$status" 201 "create ${title}" "$output"
}

create_task "${TEMP_DIR}/private-task.json" "Private feed task ${suffix}" false false
PRIVATE_TASK_ID="$(json_get "${TEMP_DIR}/private-task.json" id)"
create_task "${TEMP_DIR}/unfinished-task.json" "Unfinished shared task ${suffix}" true false
UNFINISHED_TASK_ID="$(json_get "${TEMP_DIR}/unfinished-task.json" id)"
create_task "${TEMP_DIR}/no-proof-task.json" "Completed without proof ${suffix}" true false
NO_PROOF_TASK_ID="$(json_get "${TEMP_DIR}/no-proof-task.json" id)"
create_task "${TEMP_DIR}/proof-task.json" "Completed with proof ${suffix}" true true
PROOF_TASK_ID="$(json_get "${TEMP_DIR}/proof-task.json" id)"

status="$(multipart_request POST "${BASE_URL}/api/tasks/${NO_PROOF_TASK_ID}/complete" "${TEMP_DIR}/no-proof-completion.json" "$B_TOKEN" \
  -F "occurrenceDate=${TODAY}" -F "caption=Completed without an image")"
expect_status "$status" 201 "complete shared task without proof" "${TEMP_DIR}/no-proof-completion.json"
NO_PROOF_POST_ID="$(json_get "${TEMP_DIR}/no-proof-completion.json" postId)"

python3 - "${TEMP_DIR}/proof.png" <<'PY'
import base64, pathlib, sys
pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
PY
status="$(multipart_request POST "${BASE_URL}/api/tasks/${PROOF_TASK_ID}/complete" "${TEMP_DIR}/proof-completion.json" "$B_TOKEN" \
  -F "occurrenceDate=${TODAY}" -F "caption=Proof attached" -F "proofImage=@${TEMP_DIR}/proof.png;type=image/png")"
expect_status "$status" 201 "complete shared task with proof" "${TEMP_DIR}/proof-completion.json"
PROOF_POST_ID="$(json_get "${TEMP_DIR}/proof-completion.json" postId)"
PROOF_MEDIA_ID="$(json_get "${TEMP_DIR}/proof-completion.json" proofMediaId)"

status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=20" "${TEMP_DIR}/feed.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load Feed V2" "${TEMP_DIR}/feed.json"
assert_feed_item "${TEMP_DIR}/feed.json" "$UNFINISHED_TASK_ID" 1 false >/dev/null
echo "PASS: shared unfinished task appears with unfinished state"
assert_feed_item "${TEMP_DIR}/feed.json" "$NO_PROOF_POST_ID" 2 false >/dev/null
echo "PASS: completed task without proof has the correct state"
assert_feed_item "${TEMP_DIR}/feed.json" "$PROOF_POST_ID" 3 false >/dev/null
echo "PASS: completed task with proof starts unseen"
assert_feed_missing "${TEMP_DIR}/feed.json" "$PRIVATE_TASK_ID"
echo "PASS: private task is excluded from the feed"
assert_friend_progress "${TEMP_DIR}/feed.json" "$B_ID" 2 3 67
echo "PASS: friend progress is calculated from shared scheduled tasks"

status="$(http_request GET "${BASE_URL}/api/feed/items/${UNFINISHED_TASK_ID}?activityType=1&date=${TODAY}" "${TEMP_DIR}/unfinished-detail.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load unfinished feed-item details" "${TEMP_DIR}/unfinished-detail.json"
status="$(http_request GET "${BASE_URL}/api/feed/items/${PROOF_POST_ID}?activityType=3&date=${TODAY}" "${TEMP_DIR}/proof-detail.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load completed feed-item details" "${TEMP_DIR}/proof-detail.json"
status="$(http_request GET "${BASE_URL}/api/feed/items/${PROOF_POST_ID}?activityType=99&date=${TODAY}" "${TEMP_DIR}/invalid-activity-type.json" '' "$A_TOKEN")"
expect_status "$status" 400 "reject unsupported feed activity type" "${TEMP_DIR}/invalid-activity-type.json"

status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=1" "${TEMP_DIR}/page-1.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load first stable feed page" "${TEMP_DIR}/page-1.json"
status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=2&pageSize=1" "${TEMP_DIR}/page-2.json" '' "$A_TOKEN")"
expect_status "$status" 200 "load second stable feed page" "${TEMP_DIR}/page-2.json"
PAGE_ONE_ID="$(json_get "${TEMP_DIR}/page-1.json" items.0.id)"
PAGE_TWO_ID="$(json_get "${TEMP_DIR}/page-2.json" items.0.id)"
[[ "$PAGE_ONE_ID" != "$PAGE_TWO_ID" ]] || { echo "FAIL: pagination returned a duplicate feed item" >&2; exit 1; }
echo "PASS: stable pagination does not duplicate feed items"

status="$(curl -sS -o "${TEMP_DIR}/friend-proof.png" -w "%{http_code}" \
  -H "Authorization: Bearer ${A_TOKEN}" "${BASE_URL}/api/media/task-proofs/${PROOF_MEDIA_ID}")"
expect_status "$status" 200 "friend opens authorized proof image" "${TEMP_DIR}/friend-proof.png"
status="$(curl -sS -o "${TEMP_DIR}/outsider-proof.json" -w "%{http_code}" \
  -H "Authorization: Bearer ${C_TOKEN}" "${BASE_URL}/api/media/task-proofs/${PROOF_MEDIA_ID}")"
expect_status "$status" 403 "non-friend cannot open proof image" "${TEMP_DIR}/outsider-proof.json"

status="$(http_request POST "${BASE_URL}/api/feed/${PROOF_POST_ID}/view-proof" "${TEMP_DIR}/proof-view.json" '' "$A_TOKEN")"
expect_status "$status" 204 "mark proof viewed" "${TEMP_DIR}/proof-view.json"
status="$(http_request POST "${BASE_URL}/api/feed/${PROOF_POST_ID}/view-proof" "${TEMP_DIR}/proof-view-again.json" '' "$A_TOKEN")"
expect_status "$status" 204 "mark proof viewed idempotently" "${TEMP_DIR}/proof-view-again.json"
status="$(http_request POST "${BASE_URL}/api/feed/${NO_PROOF_POST_ID}/view-proof" "${TEMP_DIR}/no-proof-view.json" '' "$A_TOKEN")"
expect_status "$status" 404 "strict proof-view endpoint rejects no-proof post" "${TEMP_DIR}/no-proof-view.json"
status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=20" "${TEMP_DIR}/feed-viewed.json" '' "$A_TOKEN")"
expect_status "$status" 200 "reload viewed Feed V2" "${TEMP_DIR}/feed-viewed.json"
assert_feed_item "${TEMP_DIR}/feed-viewed.json" "$PROOF_POST_ID" 3 true >/dev/null
echo "PASS: proof viewed state persists"

status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=20" "${TEMP_DIR}/outsider-feed.json" '' "$C_TOKEN")"
expect_status "$status" 200 "non-friend loads own empty feed" "${TEMP_DIR}/outsider-feed.json"
assert_feed_missing "${TEMP_DIR}/outsider-feed.json" "$PROOF_POST_ID"
echo "PASS: non-friend cannot see another user's feed activity"

status="$(http_request DELETE "${BASE_URL}/api/tasks/${UNFINISHED_TASK_ID}" "${TEMP_DIR}/delete-unfinished.json" '' "$B_TOKEN")"
expect_status "$status" 204 "soft-delete unfinished shared task" "${TEMP_DIR}/delete-unfinished.json"
status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=20" "${TEMP_DIR}/feed-after-delete.json" '' "$A_TOKEN")"
expect_status "$status" 200 "reload feed after task deletion" "${TEMP_DIR}/feed-after-delete.json"
assert_feed_missing "${TEMP_DIR}/feed-after-delete.json" "$UNFINISHED_TASK_ID"
echo "PASS: soft-deleted task disappears from feed"

ADMIN_EMAIL="$(read_env SEED_ADMIN_EMAIL)"; ADMIN_PASSWORD="$(read_env SEED_ADMIN_PASSWORD)"
login_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "${TEMP_DIR}/admin.json"
ADMIN_TOKEN="$(json_get "${TEMP_DIR}/admin.json" accessToken)"
status="$(http_request PUT "${BASE_URL}/api/admin/posts/${PROOF_POST_ID}/visibility" "${TEMP_DIR}/hide-post.json" '{"isVisible":false}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator hides proof post" "${TEMP_DIR}/hide-post.json"
status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=20" "${TEMP_DIR}/feed-hidden.json" '' "$A_TOKEN")"
expect_status "$status" 200 "reload feed after moderation" "${TEMP_DIR}/feed-hidden.json"
assert_feed_missing "${TEMP_DIR}/feed-hidden.json" "$PROOF_POST_ID"
echo "PASS: administrator-hidden post is excluded"
status="$(http_request PUT "${BASE_URL}/api/admin/posts/${PROOF_POST_ID}/visibility" "${TEMP_DIR}/restore-post.json" '{"isVisible":true}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator restores proof post" "${TEMP_DIR}/restore-post.json"

status="$(http_request PUT "${BASE_URL}/api/admin/users/${B_ID}/active" "${TEMP_DIR}/deactivate-user.json" '{"isActive":false}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator deactivates feed friend" "${TEMP_DIR}/deactivate-user.json"
status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=20" "${TEMP_DIR}/feed-inactive.json" '' "$A_TOKEN")"
expect_status "$status" 200 "reload feed for inactive friend" "${TEMP_DIR}/feed-inactive.json"
assert_feed_missing "${TEMP_DIR}/feed-inactive.json" "$PROOF_POST_ID"
echo "PASS: inactive friend is excluded from feed"
status="$(http_request PUT "${BASE_URL}/api/admin/users/${B_ID}/active" "${TEMP_DIR}/reactivate-user.json" '{"isActive":true}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator reactivates feed friend" "${TEMP_DIR}/reactivate-user.json"

status="$(http_request DELETE "${BASE_URL}/api/friends/${B_ID}" "${TEMP_DIR}/remove-friend.json" '' "$A_TOKEN")"
expect_status "$status" 204 "remove Feed V2 friendship" "${TEMP_DIR}/remove-friend.json"
status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=20" "${TEMP_DIR}/feed-removed.json" '' "$A_TOKEN")"
expect_status "$status" 200 "reload feed after friendship removal" "${TEMP_DIR}/feed-removed.json"
assert_feed_missing "${TEMP_DIR}/feed-removed.json" "$NO_PROOF_POST_ID"
assert_feed_missing "${TEMP_DIR}/feed-removed.json" "$PROOF_POST_ID"
echo "PASS: removed friend immediately loses feed visibility"
status="$(curl -sS -o "${TEMP_DIR}/removed-proof.json" -w "%{http_code}" \
  -H "Authorization: Bearer ${A_TOKEN}" "${BASE_URL}/api/media/task-proofs/${PROOF_MEDIA_ID}")"
expect_status "$status" 403 "removed friend loses proof access" "${TEMP_DIR}/removed-proof.json"

echo
echo "Feed V2 visibility, states, progress, proof viewing and pagination smoke test completed successfully against ${BASE_URL}."
