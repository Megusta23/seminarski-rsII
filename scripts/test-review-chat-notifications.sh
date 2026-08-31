#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

suffix="$(date +%s)-$$"
PASSWORD='Review_Chat_220087!'
A_EMAIL="review-chat-a-${suffix}@example.com"
B_EMAIL="review-chat-b-${suffix}@example.com"

register_test_user "$A_EMAIL" "$PASSWORD" Alice Review "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Bob Review "${TEMP_DIR}/b.json"
A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"
A_ID="$(json_get "${TEMP_DIR}/a.json" userId)"
B_TOKEN="$(json_get "${TEMP_DIR}/b.json" accessToken)"
B_ID="$(json_get "${TEMP_DIR}/b.json" userId)"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${B_ID}" "${TEMP_DIR}/friend-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice sends Bob a friend request" "${TEMP_DIR}/friend-request.json"
REQUEST_ID="$(json_get "${TEMP_DIR}/friend-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${REQUEST_ID}/accept" "${TEMP_DIR}/friend-accept.json" '' "$B_TOKEN")"
expect_status "$status" 204 "Bob accepts Alice" "${TEMP_DIR}/friend-accept.json"

status="$(http_request POST "${BASE_URL}/api/conversations/direct/${B_ID}" "${TEMP_DIR}/conversation.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice starts a direct conversation" "${TEMP_DIR}/conversation.json"
CONVERSATION_ID="$(json_get "${TEMP_DIR}/conversation.json" id)"
[[ "$(json_get "${TEMP_DIR}/conversation.json" canSendMessages)" == "true" ]] || {
  echo "FAIL: a direct conversation between friends must be writable" >&2
  exit 1
}
echo "PASS: direct conversation reports canSendMessages=true"

LONG_MESSAGE="$(python3 - <<'PY'
print('x' * 4000)
PY
)"
status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/long-message.json" "$A_TOKEN" \
  -F "content=${LONG_MESSAGE}")"
expect_status "$status" 201 "4000-character message is saved" "${TEMP_DIR}/long-message.json"
MESSAGE_ID="$(json_get "${TEMP_DIR}/long-message.json" id)"

status="$(http_request GET "${BASE_URL}/api/notifications?page=1&pageSize=100" "${TEMP_DIR}/notifications.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob loads notifications after long message" "${TEMP_DIR}/notifications.json"
python3 - "${TEMP_DIR}/notifications.json" "$CONVERSATION_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
conversation_id = sys.argv[2].lower()
items = [
    item for item in payload.get('items', [])
    if str(item.get('relatedEntityId', '')).lower() == conversation_id
    and int(item.get('kind', 0)) == 4
]
if not items:
    raise SystemExit('FAIL: no new-message notification was created')
body = items[0].get('body', '')
if body != 'Alice Review sent you a message.':
    raise SystemExit(f'FAIL: unexpected notification body: {body!r}')
if len(body) > 2000:
    raise SystemExit('FAIL: notification body exceeds the database limit')
if 'x' * 20 in body:
    raise SystemExit('FAIL: notification body leaked the full chat content')
print('PASS: long chat content uses a short privacy-safe notification body')
PY

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/image-message.json" "$A_TOKEN" \
  -F "attachment=@${ROOT_DIR}/src/LadderSocial.Infrastructure/SeedAssets/proofs/hike.png;type=image/png")"
expect_status "$status" 201 "image message is saved" "${TEMP_DIR}/image-message.json"

status="$(http_request GET "${BASE_URL}/api/notifications?page=1&pageSize=100" "${TEMP_DIR}/image-notifications.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob loads notifications after image message" "${TEMP_DIR}/image-notifications.json"
python3 - "${TEMP_DIR}/image-notifications.json" "$CONVERSATION_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
conversation_id = sys.argv[2].lower()
bodies = [
    item.get('body', '') for item in payload.get('items', [])
    if str(item.get('relatedEntityId', '')).lower() == conversation_id
    and int(item.get('kind', 0)) == 4
]
if 'Alice Review sent you an image.' not in bodies:
    raise SystemExit(f'FAIL: image notification body was not privacy-safe: {bodies!r}')
print('PASS: image chat uses a short privacy-safe notification body')
PY

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages?page=1&pageSize=20" "${TEMP_DIR}/messages-before-unfriend.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob reads conversation history before unfriend" "${TEMP_DIR}/messages-before-unfriend.json"
json_array_contains "${TEMP_DIR}/messages-before-unfriend.json" items id "$MESSAGE_ID"

status="$(http_request DELETE "${BASE_URL}/api/friends/${B_ID}" "${TEMP_DIR}/remove-friend.json" '' "$A_TOKEN")"
expect_status "$status" 204 "Alice removes Bob from friends" "${TEMP_DIR}/remove-friend.json"

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}" "${TEMP_DIR}/conversation-after-unfriend.json" '' "$A_TOKEN")"
expect_status "$status" 200 "conversation history metadata remains readable after unfriend" "${TEMP_DIR}/conversation-after-unfriend.json"
[[ "$(json_get "${TEMP_DIR}/conversation-after-unfriend.json" canSendMessages)" == "false" ]] || {
  echo "FAIL: direct conversation must report canSendMessages=false after unfriend" >&2
  exit 1
}
echo "PASS: direct conversation becomes read-only after unfriend"

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages?page=1&pageSize=20" "${TEMP_DIR}/messages-after-unfriend.json" '' "$B_TOKEN")"
expect_status "$status" 200 "conversation history remains readable after unfriend" "${TEMP_DIR}/messages-after-unfriend.json"
json_array_contains "${TEMP_DIR}/messages-after-unfriend.json" items id "$MESSAGE_ID"

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/blocked-message.json" "$A_TOKEN" \
  -F "content=This message must be blocked")"
expect_status "$status" 403 "new direct message is blocked after unfriend" "${TEMP_DIR}/blocked-message.json"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${B_ID}" "${TEMP_DIR}/refriend-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice sends a new friend request" "${TEMP_DIR}/refriend-request.json"
REFRIEND_REQUEST_ID="$(json_get "${TEMP_DIR}/refriend-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${REFRIEND_REQUEST_ID}/accept" "${TEMP_DIR}/refriend-accept.json" '' "$B_TOKEN")"
expect_status "$status" 204 "Bob accepts Alice again" "${TEMP_DIR}/refriend-accept.json"

status="$(http_request POST "${BASE_URL}/api/conversations/direct/${B_ID}" "${TEMP_DIR}/conversation-restored.json" '' "$A_TOKEN")"
expect_status "$status" 201 "existing direct conversation is restored after refriending" "${TEMP_DIR}/conversation-restored.json"
[[ "$(json_get "${TEMP_DIR}/conversation-restored.json" id)" == "$CONVERSATION_ID" ]] || {
  echo "FAIL: refriending should reuse the existing direct conversation" >&2
  exit 1
}
[[ "$(json_get "${TEMP_DIR}/conversation-restored.json" canSendMessages)" == "true" ]] || {
  echo "FAIL: direct conversation should become writable after refriending" >&2
  exit 1
}
echo "PASS: refriending re-enables the existing direct conversation"

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/restored-message.json" "$A_TOKEN" \
  -F "content=Messaging works again")"
expect_status "$status" 201 "new direct message succeeds after refriending" "${TEMP_DIR}/restored-message.json"

echo
echo "Chat friendship rules and notification safety review test completed successfully against ${BASE_URL}."
