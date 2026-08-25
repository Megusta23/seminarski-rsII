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

assert_profile_values() {
  python3 - "$@" <<'PY'
import json, sys
file, posts, friends, completed, habits, streak, mutuals, highlights = sys.argv[1:]
with open(file, encoding="utf-8") as handle:
    payload = json.load(handle)
checks = {
    "visiblePostCount": int(posts),
    "friendCount": int(friends),
    "completedTaskCount": int(completed),
    "habitCount": int(habits),
    "currentStreak": int(streak),
}
for key, expected in checks.items():
    actual = int(payload.get(key, -1))
    if actual != expected:
        raise SystemExit(f"{key}={actual}, expected {expected}: {payload!r}")
actual_mutuals = int(payload.get("mutualFriends", {}).get("count", -1))
if actual_mutuals != int(mutuals):
    raise SystemExit(f"mutualFriends.count={actual_mutuals}, expected {mutuals}: {payload!r}")
actual_highlights = len(payload.get("highlightedPosts", []))
if actual_highlights != int(highlights):
    raise SystemExit(f"highlightedPosts={actual_highlights}, expected {highlights}: {payload!r}")
if not payload.get("canMessage"):
    raise SystemExit(f"Expected canMessage=true: {payload!r}")
if not payload.get("memberSinceUtc"):
    raise SystemExit(f"Expected memberSinceUtc: {payload!r}")
PY
}

assert_highlight_contains() {
  local file="$1" post_id="$2" expected="$3"
  python3 - "$file" "$post_id" "$expected" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
found = any(str(item.get("postId")) == sys.argv[2] for item in payload.get("highlightedPosts", []))
expected = sys.argv[3].lower() == "true"
if found != expected:
    raise SystemExit(f"post {sys.argv[2]} found={found}, expected={expected}: {payload!r}")
PY
}

assert_candidate_count() {
  local file="$1" expected="$2"
  python3 - "$file" "$expected" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
actual = int(payload.get("totalCount", -1))
if actual != int(sys.argv[2]):
    raise SystemExit(f"totalCount={actual}, expected={sys.argv[2]}: {payload!r}")
PY
}

suffix="$(date +%s)-$$"
PASSWORD='Friend_Profile_V2_220087!'
A_EMAIL="profile-a-${suffix}@example.com"
B_EMAIL="profile-b-${suffix}@example.com"
C_EMAIL="profile-c-${suffix}@example.com"
D_EMAIL="profile-outsider-${suffix}@example.com"
register_test_user "$A_EMAIL" "$PASSWORD" Alice Profile "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Bob Profile "${TEMP_DIR}/b.json"
register_test_user "$C_EMAIL" "$PASSWORD" Carol Mutual "${TEMP_DIR}/c.json"
register_test_user "$D_EMAIL" "$PASSWORD" Derek Outsider "${TEMP_DIR}/d.json"
A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"; A_ID="$(json_get "${TEMP_DIR}/a.json" userId)"
B_TOKEN="$(json_get "${TEMP_DIR}/b.json" accessToken)"; B_ID="$(json_get "${TEMP_DIR}/b.json" userId)"
C_TOKEN="$(json_get "${TEMP_DIR}/c.json" accessToken)"; C_ID="$(json_get "${TEMP_DIR}/c.json" userId)"
D_TOKEN="$(json_get "${TEMP_DIR}/d.json" accessToken)"

make_friends() {
  local sender_token="$1" receiver_token="$2" receiver_id="$3" label="$4"
  local request_file="${TEMP_DIR}/${label}-request.json"
  local accept_file="${TEMP_DIR}/${label}-accept.json"
  local status request_id
  status="$(http_request POST "${BASE_URL}/api/friends/requests/${receiver_id}" "$request_file" '' "$sender_token")"
  expect_status "$status" 201 "create ${label} friendship request" "$request_file"
  request_id="$(json_get "$request_file" id)"
  status="$(http_request POST "${BASE_URL}/api/friends/requests/${request_id}/accept" "$accept_file" '' "$receiver_token")"
  expect_status "$status" 204 "accept ${label} friendship" "$accept_file"
}

make_friends "$A_TOKEN" "$B_TOKEN" "$B_ID" a-b
make_friends "$A_TOKEN" "$C_TOKEN" "$C_ID" a-c
make_friends "$B_TOKEN" "$C_TOKEN" "$C_ID" b-c

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load profile task categories" "${TEMP_DIR}/categories.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories.json" 0.id)"
status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load profile recurrence types" "${TEMP_DIR}/recurrences.json"
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"
DAILY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" daily)"
TODAY="$(date -u +%F)"

habit_body="$(printf '{"title":%s,"description":"Active recurring habit","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false}' \
  "$(json_string "Profile habit ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$DAILY_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/habit.json" "$habit_body" "$B_TOKEN")"
expect_status "$status" 201 "create active recurring habit" "${TEMP_DIR}/habit.json"

no_proof_body="$(printf '{"title":%s,"description":"No-proof profile fixture","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":true}' \
  "$(json_string "No proof post ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/no-proof-task.json" "$no_proof_body" "$B_TOKEN")"
expect_status "$status" 201 "create shared no-proof task" "${TEMP_DIR}/no-proof-task.json"
NO_PROOF_TASK_ID="$(json_get "${TEMP_DIR}/no-proof-task.json" id)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${NO_PROOF_TASK_ID}/complete" "${TEMP_DIR}/no-proof-completion.json" "$B_TOKEN" \
  -F "occurrenceDate=${TODAY}" -F "caption=Visible but not highlightable")"
expect_status "$status" 201 "complete shared no-proof task" "${TEMP_DIR}/no-proof-completion.json"
NO_PROOF_POST_ID="$(json_get "${TEMP_DIR}/no-proof-completion.json" postId)"

python3 - "${TEMP_DIR}/proof.png" <<'PY'
import base64, pathlib, sys
pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
PY

POST_IDS=()
MEDIA_IDS=()
for number in 1 2 3 4 5 6 7; do
  task_file="${TEMP_DIR}/proof-task-${number}.json"
  completion_file="${TEMP_DIR}/proof-completion-${number}.json"
  task_body="$(printf '{"title":%s,"description":"Highlighted-profile fixture","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":true,"shareWithFriends":true}' \
    "$(json_string "Proof highlight ${number} ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")")"
  status="$(http_request POST "${BASE_URL}/api/tasks" "$task_file" "$task_body" "$B_TOKEN")"
  expect_status "$status" 201 "create proof highlight task ${number}" "$task_file"
  task_id="$(json_get "$task_file" id)"
  status="$(multipart_request POST "${BASE_URL}/api/tasks/${task_id}/complete" "$completion_file" "$B_TOKEN" \
    -F "occurrenceDate=${TODAY}" -F "caption=Highlight caption ${number}" \
    -F "proofImage=@${TEMP_DIR}/proof.png;type=image/png")"
  expect_status "$status" 201 "complete proof highlight task ${number}" "$completion_file"
  POST_IDS+=("$(json_get "$completion_file" postId)")
  MEDIA_IDS+=("$(json_get "$completion_file" proofMediaId)")
done

status="$(http_request GET "${BASE_URL}/api/friends/${B_ID}/profile" "${TEMP_DIR}/profile-before.json" '' "$A_TOKEN")"
expect_status "$status" 200 "friend opens profile before highlights" "${TEMP_DIR}/profile-before.json"
assert_profile_values "${TEMP_DIR}/profile-before.json" 8 2 8 1 1 1 0
echo "PASS: profile statistics, member-since and mutual-friend summary are correct"
json_array_contains "${TEMP_DIR}/profile-before.json" mutualFriends.items userId "$C_ID"
echo "PASS: mutual friend details include Carol"

status="$(http_request GET "${BASE_URL}/api/friends/${B_ID}/profile" "${TEMP_DIR}/outsider-profile.json" '' "$D_TOKEN")"
expect_status "$status" 404 "non-friend cannot open detailed friend profile" "${TEMP_DIR}/outsider-profile.json"

status="$(http_request GET "${BASE_URL}/api/profile/me/highlight-candidates?page=1&pageSize=100" "${TEMP_DIR}/candidates.json" '' "$B_TOKEN")"
expect_status "$status" 200 "owner loads highlight candidates" "${TEMP_DIR}/candidates.json"
assert_candidate_count "${TEMP_DIR}/candidates.json" 7
echo "PASS: only visible shared posts with proof are highlight candidates"

status="$(http_request POST "${BASE_URL}/api/profile/me/highlights/${NO_PROOF_POST_ID}" "${TEMP_DIR}/no-proof-highlight.json" '' "$B_TOKEN")"
expect_status "$status" 404 "post without proof cannot be highlighted" "${TEMP_DIR}/no-proof-highlight.json"
status="$(http_request POST "${BASE_URL}/api/profile/me/highlights/${POST_IDS[0]}" "${TEMP_DIR}/other-user-highlight.json" '' "$A_TOKEN")"
expect_status "$status" 404 "another user cannot highlight someone else's post" "${TEMP_DIR}/other-user-highlight.json"

for index in 0 1 2 3 4 5; do
  status="$(http_request POST "${BASE_URL}/api/profile/me/highlights/${POST_IDS[$index]}" "${TEMP_DIR}/highlight-${index}.json" '' "$B_TOKEN")"
  expect_status "$status" 204 "owner highlights post $((index + 1))" "${TEMP_DIR}/highlight-${index}.json"
done
status="$(http_request POST "${BASE_URL}/api/profile/me/highlights/${POST_IDS[0]}" "${TEMP_DIR}/duplicate-highlight.json" '' "$B_TOKEN")"
expect_status "$status" 204 "duplicate highlight is idempotent" "${TEMP_DIR}/duplicate-highlight.json"
status="$(http_request POST "${BASE_URL}/api/profile/me/highlights/${POST_IDS[6]}" "${TEMP_DIR}/seventh-highlight.json" '' "$B_TOKEN")"
expect_status "$status" 409 "seventh highlight exceeds profile limit" "${TEMP_DIR}/seventh-highlight.json"

status="$(http_request GET "${BASE_URL}/api/friends/${B_ID}/profile" "${TEMP_DIR}/profile-highlighted.json" '' "$A_TOKEN")"
expect_status "$status" 200 "friend reloads highlighted profile" "${TEMP_DIR}/profile-highlighted.json"
assert_profile_values "${TEMP_DIR}/profile-highlighted.json" 8 2 8 1 1 1 6
assert_highlight_contains "${TEMP_DIR}/profile-highlighted.json" "${POST_IDS[0]}" true
echo "PASS: six secure highlighted proof posts appear"

status="$(curl -sS -o "${TEMP_DIR}/friend-highlight.png" -w "%{http_code}" \
  -H "Authorization: Bearer ${A_TOKEN}" "${BASE_URL}/api/media/task-proofs/${MEDIA_IDS[0]}")"
expect_status "$status" 200 "friend downloads highlighted proof" "${TEMP_DIR}/friend-highlight.png"

status="$(http_request DELETE "${BASE_URL}/api/profile/me/highlights/${POST_IDS[0]}" "${TEMP_DIR}/remove-highlight.json" '' "$B_TOKEN")"
expect_status "$status" 204 "owner removes highlight" "${TEMP_DIR}/remove-highlight.json"
status="$(http_request DELETE "${BASE_URL}/api/profile/me/highlights/${POST_IDS[0]}" "${TEMP_DIR}/remove-highlight-again.json" '' "$B_TOKEN")"
expect_status "$status" 204 "removing highlight is idempotent" "${TEMP_DIR}/remove-highlight-again.json"
status="$(http_request POST "${BASE_URL}/api/profile/me/highlights/${POST_IDS[0]}" "${TEMP_DIR}/restore-highlight.json" '' "$B_TOKEN")"
expect_status "$status" 204 "owner restores highlight" "${TEMP_DIR}/restore-highlight.json"

ADMIN_EMAIL="$(read_env SEED_ADMIN_EMAIL)"; ADMIN_PASSWORD="$(read_env SEED_ADMIN_PASSWORD)"
login_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "${TEMP_DIR}/admin.json"
ADMIN_TOKEN="$(json_get "${TEMP_DIR}/admin.json" accessToken)"
status="$(http_request PUT "${BASE_URL}/api/admin/posts/${POST_IDS[0]}/visibility" "${TEMP_DIR}/hide-highlight.json" '{"isVisible":false}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator hides highlighted post" "${TEMP_DIR}/hide-highlight.json"
status="$(http_request GET "${BASE_URL}/api/friends/${B_ID}/profile" "${TEMP_DIR}/profile-hidden.json" '' "$A_TOKEN")"
expect_status "$status" 200 "friend reloads profile after moderation" "${TEMP_DIR}/profile-hidden.json"
assert_highlight_contains "${TEMP_DIR}/profile-hidden.json" "${POST_IDS[0]}" false
echo "PASS: hidden post is removed from profile highlights"
status="$(http_request PUT "${BASE_URL}/api/admin/posts/${POST_IDS[0]}/visibility" "${TEMP_DIR}/restore-visibility.json" '{"isVisible":true}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator restores post visibility" "${TEMP_DIR}/restore-visibility.json"
status="$(http_request POST "${BASE_URL}/api/profile/me/highlights/${POST_IDS[0]}" "${TEMP_DIR}/rehighlight.json" '' "$B_TOKEN")"
expect_status "$status" 204 "owner re-highlights restored post" "${TEMP_DIR}/rehighlight.json"

status="$(http_request PUT "${BASE_URL}/api/admin/users/${B_ID}/active" "${TEMP_DIR}/deactivate-profile.json" '{"isActive":false}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator deactivates profile owner" "${TEMP_DIR}/deactivate-profile.json"
status="$(http_request GET "${BASE_URL}/api/friends/${B_ID}/profile" "${TEMP_DIR}/inactive-profile.json" '' "$A_TOKEN")"
expect_status "$status" 404 "inactive friend profile is unavailable" "${TEMP_DIR}/inactive-profile.json"
status="$(http_request PUT "${BASE_URL}/api/admin/users/${B_ID}/active" "${TEMP_DIR}/reactivate-profile.json" '{"isActive":true}' "$ADMIN_TOKEN")"
expect_status "$status" 204 "administrator reactivates profile owner" "${TEMP_DIR}/reactivate-profile.json"

status="$(http_request POST "${BASE_URL}/api/conversations/direct/${B_ID}" "${TEMP_DIR}/profile-conversation.json" '' "$A_TOKEN")"
expect_status "$status" 201 "accepted friend can start profile message conversation" "${TEMP_DIR}/profile-conversation.json"

status="$(http_request DELETE "${BASE_URL}/api/friends/${B_ID}" "${TEMP_DIR}/remove-profile-friend.json" '' "$A_TOKEN")"
expect_status "$status" 204 "remove friend from profile" "${TEMP_DIR}/remove-profile-friend.json"
status="$(http_request GET "${BASE_URL}/api/friends/${B_ID}/profile" "${TEMP_DIR}/removed-profile.json" '' "$A_TOKEN")"
expect_status "$status" 404 "removed friend loses detailed profile access" "${TEMP_DIR}/removed-profile.json"
status="$(curl -sS -o "${TEMP_DIR}/removed-highlight-proof.json" -w "%{http_code}" \
  -H "Authorization: Bearer ${A_TOKEN}" "${BASE_URL}/api/media/task-proofs/${MEDIA_IDS[0]}")"
expect_status "$status" 403 "removed friend loses highlighted proof access" "${TEMP_DIR}/removed-highlight-proof.json"

echo
echo "Friend Profile V2 statistics, mutual friends, highlights and privacy smoke test completed successfully against ${BASE_URL}."
