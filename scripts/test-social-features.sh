#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

find_reference_id() {
  python3 - "$1" "$2" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle: items=json.load(handle)
for item in items:
    if str(item.get("code", "")).lower() == sys.argv[2].lower():
        print(item["id"]); break
else: raise SystemExit(f"Missing reference code {sys.argv[2]}")
PY
}

suffix="$(date +%s)-$$"
PASSWORD='Social_Test_220087!'
A_EMAIL="social-a-${suffix}@example.com"
B_EMAIL="social-b-${suffix}@example.com"
C_EMAIL="social-c-${suffix}@example.com"
register_test_user "$A_EMAIL" "$PASSWORD" Alice Social "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Bob Social "${TEMP_DIR}/b.json"
register_test_user "$C_EMAIL" "$PASSWORD" Carol Social "${TEMP_DIR}/c.json"
A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"; A_ID="$(json_get "${TEMP_DIR}/a.json" userId)"
B_TOKEN="$(json_get "${TEMP_DIR}/b.json" accessToken)"; B_ID="$(json_get "${TEMP_DIR}/b.json" userId)"
C_TOKEN="$(json_get "${TEMP_DIR}/c.json" accessToken)"; C_ID="$(json_get "${TEMP_DIR}/c.json" userId)"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${B_ID}" "${TEMP_DIR}/a-b-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice sends Bob a friend request" "${TEMP_DIR}/a-b-request.json"
AB_REQUEST_ID="$(json_get "${TEMP_DIR}/a-b-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${AB_REQUEST_ID}/accept" "${TEMP_DIR}/a-b-accept.json" '' "$B_TOKEN")"
expect_status "$status" 204 "Bob accepts Alice" "${TEMP_DIR}/a-b-accept.json"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${C_ID}" "${TEMP_DIR}/b-c-request.json" '' "$B_TOKEN")"
expect_status "$status" 201 "Bob sends Carol a friend request" "${TEMP_DIR}/b-c-request.json"
BC_REQUEST_ID="$(json_get "${TEMP_DIR}/b-c-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${BC_REQUEST_ID}/accept" "${TEMP_DIR}/b-c-accept.json" '' "$C_TOKEN")"
expect_status "$status" 204 "Carol accepts Bob" "${TEMP_DIR}/b-c-accept.json"

status="$(http_request GET "${BASE_URL}/api/friends/recommendations" "${TEMP_DIR}/recommendations.json" '' "$A_TOKEN")"
expect_status "$status" 200 "friend-of-friend recommendations" "${TEMP_DIR}/recommendations.json"
json_array_contains "${TEMP_DIR}/recommendations.json" '' userId "$C_ID"
echo "PASS: Carol is recommended to Alice through mutual friend Bob"

status="$(http_request GET "${BASE_URL}/api/reference-data/task-categories" "${TEMP_DIR}/categories.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load category for social task" "${TEMP_DIR}/categories.json"
CATEGORY_ID="$(json_get "${TEMP_DIR}/categories.json" 0.id)"
status="$(http_request GET "${BASE_URL}/api/reference-data/recurrence-types" "${TEMP_DIR}/recurrences.json" '' "$B_TOKEN")"
expect_status "$status" 200 "load recurrence for social task" "${TEMP_DIR}/recurrences.json"
NONE_ID="$(find_reference_id "${TEMP_DIR}/recurrences.json" none)"

shared_body="$(printf '{"title":%s,"description":"Shared social smoke test","taskCategoryId":%s,"recurrenceTypeId":%s,"dueAtUtc":null,"requiresProofImage":false,"shareWithFriends":true}' \
  "$(json_string "Bob shared task ${suffix}")" "$(json_string "$CATEGORY_ID")" "$(json_string "$NONE_ID")")"
status="$(http_request POST "${BASE_URL}/api/tasks" "${TEMP_DIR}/shared-task.json" "$shared_body" "$B_TOKEN")"
expect_status "$status" 201 "Bob creates a shared task" "${TEMP_DIR}/shared-task.json"
SHARED_TASK_ID="$(json_get "${TEMP_DIR}/shared-task.json" id)"
TODAY="$(date -u +%F)"
status="$(multipart_request POST "${BASE_URL}/api/tasks/${SHARED_TASK_ID}/complete" "${TEMP_DIR}/shared-completion.json" "$B_TOKEN" \
  -F "occurrenceDate=${TODAY}" -F "caption=Bob completed a social smoke-test task")"
expect_status "$status" 201 "Bob completes shared task" "${TEMP_DIR}/shared-completion.json"
POST_ID="$(json_get "${TEMP_DIR}/shared-completion.json" postId)"

status="$(http_request GET "${BASE_URL}/api/feed?page=1&pageSize=20" "${TEMP_DIR}/feed.json" '' "$A_TOKEN")"
expect_status "$status" 200 "Alice loads friends-only feed" "${TEMP_DIR}/feed.json"
json_array_contains "${TEMP_DIR}/feed.json" items id "$POST_ID"
echo "PASS: Bob's shared completion appears in Alice's feed"
status="$(http_request POST "${BASE_URL}/api/feed/${POST_ID}/view" "${TEMP_DIR}/feed-view.json" '' "$A_TOKEN")"
expect_status "$status" 204 "Alice marks feed post viewed" "${TEMP_DIR}/feed-view.json"

status="$(http_request GET "${BASE_URL}/api/leaderboard/daily?date=${TODAY}" "${TEMP_DIR}/leaderboard.json" '' "$A_TOKEN")"
expect_status "$status" 200 "daily friend leaderboard" "${TEMP_DIR}/leaderboard.json"
json_array_contains "${TEMP_DIR}/leaderboard.json" entries userId "$B_ID"
echo "PASS: Bob appears in Alice's daily leaderboard"

status="$(http_request GET "${BASE_URL}/api/notifications?isRead=false&page=1&pageSize=50" "${TEMP_DIR}/notifications.json" '' "$A_TOKEN")"
expect_status "$status" 200 "Alice receives automatic notifications" "${TEMP_DIR}/notifications.json"
NOTIFICATION_COUNT="$(json_array_length "${TEMP_DIR}/notifications.json" items)"
[[ "$NOTIFICATION_COUNT" -gt 0 ]] || { echo "FAIL: expected at least one notification" >&2; exit 1; }
NOTIFICATION_ID="$(json_get "${TEMP_DIR}/notifications.json" items.0.id)"
status="$(http_request POST "${BASE_URL}/api/notifications/${NOTIFICATION_ID}/read" "${TEMP_DIR}/notification-read.json" '' "$A_TOKEN")"
expect_status "$status" 204 "mark notification as read" "${TEMP_DIR}/notification-read.json"
status="$(http_request POST "${BASE_URL}/api/notifications/read-all" "${TEMP_DIR}/notifications-read-all.json" '' "$A_TOKEN")"
expect_status "$status" 204 "mark all notifications read" "${TEMP_DIR}/notifications-read-all.json"

status="$(http_request GET "${BASE_URL}/api/friends/${B_ID}/profile" "${TEMP_DIR}/friend-profile.json" '' "$A_TOKEN")"
expect_status "$status" 200 "Alice opens Bob's friend profile" "${TEMP_DIR}/friend-profile.json"

status="$(http_request POST "${BASE_URL}/api/conversations/direct/${B_ID}" "${TEMP_DIR}/conversation.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice starts direct conversation with Bob" "${TEMP_DIR}/conversation.json"
CONVERSATION_ID="$(json_get "${TEMP_DIR}/conversation.json" id)"
status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/message.json" "$A_TOKEN" \
  -F "content=Hello Bob from the social smoke test")"
expect_status "$status" 201 "Alice sends a chat message" "${TEMP_DIR}/message.json"
MESSAGE_ID="$(json_get "${TEMP_DIR}/message.json" id)"
status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages?page=1&pageSize=20" "${TEMP_DIR}/messages.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob loads authorized conversation messages" "${TEMP_DIR}/messages.json"
json_array_contains "${TEMP_DIR}/messages.json" items id "$MESSAGE_ID"
echo "PASS: Bob received Alice's chat message"
status="$(http_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/read?throughMessageId=${MESSAGE_ID}" "${TEMP_DIR}/read.json" '' "$B_TOKEN")"
expect_status "$status" 204 "Bob marks conversation read" "${TEMP_DIR}/read.json"
status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/carol-chat.json" '' "$C_TOKEN")"
expect_status "$status" 404 "non-member cannot read conversation" "${TEMP_DIR}/carol-chat.json"

status="$(http_request DELETE "${BASE_URL}/api/friends/${B_ID}" "${TEMP_DIR}/remove-friend.json" '' "$A_TOKEN")"
expect_status "$status" 204 "Alice removes Bob from friends" "${TEMP_DIR}/remove-friend.json"

echo
echo "Friends, recommendations, feed, leaderboard, notifications and chat smoke test completed successfully against ${BASE_URL}."
