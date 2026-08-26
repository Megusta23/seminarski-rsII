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

assert_overview() {
  python3 - "$@" <<'PY'
import json, sys
file, display_name, posts, friends, completed, habits, streak, highlights = sys.argv[1:]
with open(file, encoding="utf-8") as handle:
    payload = json.load(handle)
checks = {
    "displayName": display_name,
    "visiblePostCount": int(posts),
    "friendCount": int(friends),
    "completedTaskCount": int(completed),
    "habitCount": int(habits),
    "currentStreak": int(streak),
}
for key, expected in checks.items():
    actual = payload.get(key)
    if actual != expected:
        raise SystemExit(f"{key}={actual!r}, expected {expected!r}: {payload!r}")
if len(payload.get("highlightedPosts", [])) != int(highlights):
    raise SystemExit(
        f"highlightedPosts={len(payload.get('highlightedPosts', []))}, "
        f"expected {highlights}: {payload!r}"
    )
if not payload.get("memberSinceUtc"):
    raise SystemExit(f"Expected memberSinceUtc: {payload!r}")
PY
}

suffix="$(date +%s)-$$"
PASSWORD='Own_Profile_V2_220087!'
OWNER_EMAIL="own-profile-${suffix}@example.com"
FRIEND_EMAIL="own-profile-friend-${suffix}@example.com"
register_test_user "$OWNER_EMAIL" "$PASSWORD" Own Profile "${TEMP_DIR}/owner.json"
register_test_user "$FRIEND_EMAIL" "$PASSWORD" Profile Friend "${TEMP_DIR}/friend.json"
OWNER_TOKEN="$(json_get "${TEMP_DIR}/owner.json" accessToken)"
OWNER_ID="$(json_get "${TEMP_DIR}/owner.json" userId)"
FRIEND_TOKEN="$(json_get "${TEMP_DIR}/friend.json" accessToken)"
FRIEND_ID="$(json_get "${TEMP_DIR}/friend.json" userId)"

status="$(http_request GET "${BASE_URL}/api/profile/me/overview" "${TEMP_DIR}/anonymous-overview.json")"
expect_status "$status" 401 "anonymous own-profile overview is rejected" "${TEMP_DIR}/anonymous-overview.json"

update_body='{"firstName":"Hasan","lastName":"Profile","bio":"Trying to improve every day.","cityId":null,"dateOfBirth":null}'
status="$(http_request PUT "${BASE_URL}/api/profile/me" "${TEMP_DIR}/updated-profile.json" "$update_body" "$OWNER_TOKEN")"
expect_status "$status" 200 "update own profile fixture" "${TEMP_DIR}/updated-profile.json"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${FRIEND_ID}" "${TEMP_DIR}/friend-request.json" '' "$OWNER_TOKEN")"
expect_status "$status" 201 "create own-profile friendship request" "${TEMP_DIR}/friend-request.json"
REQUEST_ID="$(json_get "${TEMP_DIR}/friend-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${REQUEST_ID}/accept" "${TEMP_DIR}/friend-accept.json" '' "$FRIEND_TOKEN")"
expect_status "$status" 204 "accept own-profile friendship" "${TEMP_DIR}/friend-accept.json"

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$OWNER_TOKEN")"
expect_status "$status" 200 "load own-profile task categories" "${TEMP_DIR}/categories.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories.json" 0.id)"
status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$OWNER_TOKEN")"
expect_status "$status" 200 "load own-profile recurrence types" "${TEMP_DIR}/recurrences.json"
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"
DAILY_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" daily)"
TODAY="$(date -u +%F)"

habit_body="$(printf '{"title":%s,"description":"Own profile habit","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":false}' \
  "$(json_string "Profile habit ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$DAILY_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/habit.json" "$habit_body" "$OWNER_TOKEN")"
expect_status "$status" 201 "create own-profile recurring habit" "${TEMP_DIR}/habit.json"

no_proof_body="$(printf '{"title":%s,"description":"Own profile post","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":true}' \
  "$(json_string "Profile no-proof ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/no-proof-task.json" "$no_proof_body" "$OWNER_TOKEN")"
expect_status "$status" 201 "create own-profile no-proof task" "${TEMP_DIR}/no-proof-task.json"
NO_PROOF_TASK_ID="$(json_get "${TEMP_DIR}/no-proof-task.json" id)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${NO_PROOF_TASK_ID}/complete" "${TEMP_DIR}/no-proof-completion.json" "$OWNER_TOKEN" \
  -F "occurrenceDate=${TODAY}" -F "caption=Visible own profile post")"
expect_status "$status" 201 "complete own-profile no-proof task" "${TEMP_DIR}/no-proof-completion.json"

python3 - "${TEMP_DIR}/proof.png" <<'PY'
import base64, pathlib, sys
pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
PY

proof_body="$(printf '{"title":%s,"description":"Own profile highlight","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":true,"shareWithFriends":true}' \
  "$(json_string "Profile proof ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/proof-task.json" "$proof_body" "$OWNER_TOKEN")"
expect_status "$status" 201 "create own-profile proof task" "${TEMP_DIR}/proof-task.json"
PROOF_TASK_ID="$(json_get "${TEMP_DIR}/proof-task.json" id)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${PROOF_TASK_ID}/complete" "${TEMP_DIR}/proof-completion.json" "$OWNER_TOKEN" \
  -F "occurrenceDate=${TODAY}" -F "caption=Highlighted own profile post" \
  -F "proofImage=@${TEMP_DIR}/proof.png;type=image/png")"
expect_status "$status" 201 "complete own-profile proof task" "${TEMP_DIR}/proof-completion.json"
POST_ID="$(json_get "${TEMP_DIR}/proof-completion.json" postId)"

status="$(http_request POST "${BASE_URL}/api/profile/me/highlights/${POST_ID}" "${TEMP_DIR}/highlight.json" '' "$OWNER_TOKEN")"
expect_status "$status" 204 "highlight own-profile proof post" "${TEMP_DIR}/highlight.json"

status="$(http_request GET "${BASE_URL}/api/profile/me/overview" "${TEMP_DIR}/overview.json" '' "$OWNER_TOKEN")"
expect_status "$status" 200 "load own-profile overview" "${TEMP_DIR}/overview.json"
assert_overview "${TEMP_DIR}/overview.json" "Hasan Profile" 2 1 2 1 1 1
echo "PASS: own-profile social statistics and highlighted posts are correct"
python3 - "${TEMP_DIR}/overview.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if payload.get("bio") != "Trying to improve every day.":
    raise SystemExit(f"Unexpected biography: {payload!r}")
PY

status="$(http_request GET "${BASE_URL}/api/friends/${OWNER_ID}/profile" "${TEMP_DIR}/friend-view.json" '' "$FRIEND_TOKEN")"
expect_status "$status" 200 "friend loads matching profile statistics" "${TEMP_DIR}/friend-view.json"
assert_overview "${TEMP_DIR}/friend-view.json" "Hasan Profile" 2 1 2 1 1 1
echo "PASS: own and friend profile statistics use the same calculation"

status="$(multipart_request POST "${BASE_URL}/api/profile/me/avatar" "${TEMP_DIR}/avatar.json" "$OWNER_TOKEN" \
  -F "file=@${TEMP_DIR}/proof.png;type=image/png")"
expect_status "$status" 200 "upload own-profile avatar" "${TEMP_DIR}/avatar.json"
status="$(http_request GET "${BASE_URL}/api/profile/me/overview" "${TEMP_DIR}/avatar-overview.json" '' "$OWNER_TOKEN")"
expect_status "$status" 200 "reload own-profile avatar overview" "${TEMP_DIR}/avatar-overview.json"
python3 - "${TEMP_DIR}/avatar-overview.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if not payload.get("avatarUrl"):
    raise SystemExit(f"Expected avatarUrl after upload: {payload!r}")
PY
echo "PASS: avatar updates are reflected in own-profile overview"

status="$(http_request DELETE "${BASE_URL}/api/profile/me/highlights/${POST_ID}" "${TEMP_DIR}/remove-highlight.json" '' "$OWNER_TOKEN")"
expect_status "$status" 204 "remove own-profile highlight" "${TEMP_DIR}/remove-highlight.json"
status="$(http_request GET "${BASE_URL}/api/profile/me/overview" "${TEMP_DIR}/overview-without-highlight.json" '' "$OWNER_TOKEN")"
expect_status "$status" 200 "reload own-profile overview after highlight removal" "${TEMP_DIR}/overview-without-highlight.json"
assert_overview "${TEMP_DIR}/overview-without-highlight.json" "Hasan Profile" 2 1 2 1 1 0
echo "PASS: highlight changes are reflected immediately"

status="$(http_request DELETE "${BASE_URL}/api/profile/me/avatar" "${TEMP_DIR}/remove-avatar.json" '' "$OWNER_TOKEN")"
expect_status "$status" 200 "remove own-profile avatar" "${TEMP_DIR}/remove-avatar.json"

cleanup_body="$(printf '{"refreshToken":%s}' "$(json_string "$(json_get "${TEMP_DIR}/owner.json" refreshToken)")")"
status="$(http_request POST "${BASE_URL}/api/auth/logout" "${TEMP_DIR}/owner-logout.json" "$cleanup_body" "$OWNER_TOKEN")"
expect_status "$status" 204 "clean up own-profile session" "${TEMP_DIR}/owner-logout.json"

echo
echo "Own Profile V2 overview, statistics, avatar and highlights smoke test completed successfully against ${BASE_URL}."
