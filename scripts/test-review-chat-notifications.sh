#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

suffix="$(date +%s)-$$"
PASSWORD='Review_Chat_220087!'
A_EMAIL="review-chat-a-${suffix}@example.com"
B_EMAIL="review-chat-b-${suffix}@example.com"
KNOWN_PLAINTEXT='LEGACY-PLAINTEXT-MUST-NOT-BE-STORED-220087'

register_test_user "$A_EMAIL" "$PASSWORD" Alice Review "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Bob Review "${TEMP_DIR}/b.json"
A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"
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

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/legacy-text.json" "$A_TOKEN" \
  -F "content=${KNOWN_PLAINTEXT}")"
expect_status "$status" 405 "legacy plaintext text write is unavailable" "${TEMP_DIR}/legacy-text.json"

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/legacy-image.json" "$A_TOKEN" \
  -F "attachment=@${ROOT_DIR}/src/LadderSocial.Infrastructure/SeedAssets/proofs/hike.png;type=image/png")"
expect_status "$status" 405 "legacy plaintext image write is unavailable" "${TEMP_DIR}/legacy-image.json"

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages?page=1&pageSize=20" "${TEMP_DIR}/messages.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob reads conversation history after rejected legacy writes" "${TEMP_DIR}/messages.json"
python3 - "${TEMP_DIR}/messages.json" "$KNOWN_PLAINTEXT" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
if payload.get('items'):
    raise SystemExit(f"FAIL: rejected legacy writes created messages: {payload!r}")
if int(payload.get('totalCount', -1)) != 0:
    raise SystemExit(f"FAIL: expected an empty conversation, got {payload!r}")
if sys.argv[2] in json.dumps(payload):
    raise SystemExit('FAIL: known plaintext marker appeared in message history')
print('PASS: rejected legacy writes leave message history empty')
PY

status="$(http_request GET "${BASE_URL}/api/notifications?page=1&pageSize=100" "${TEMP_DIR}/notifications.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob loads notifications after rejected legacy writes" "${TEMP_DIR}/notifications.json"
python3 - "${TEMP_DIR}/notifications.json" "$CONVERSATION_ID" "$KNOWN_PLAINTEXT" <<'PY'
import json
import sys
with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
items = [
    item for item in payload.get('items', [])
    if str(item.get('relatedEntityId', '')).lower() == sys.argv[2].lower()
]
if items:
    raise SystemExit(f'FAIL: rejected legacy writes created notifications: {items!r}')
if sys.argv[3] in json.dumps(payload):
    raise SystemExit('FAIL: known plaintext marker leaked into notifications')
print('PASS: rejected legacy writes create no notification and leak no content')
PY

status="$(http_request DELETE "${BASE_URL}/api/friends/${B_ID}" "${TEMP_DIR}/remove-friend.json" '' "$A_TOKEN")"
expect_status "$status" 204 "Alice removes Bob from friends" "${TEMP_DIR}/remove-friend.json"

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}" "${TEMP_DIR}/conversation-after-unfriend.json" '' "$A_TOKEN")"
expect_status "$status" 200 "conversation metadata remains readable after unfriend" "${TEMP_DIR}/conversation-after-unfriend.json"
[[ "$(json_get "${TEMP_DIR}/conversation-after-unfriend.json" canSendMessages)" == "false" ]] || {
  echo "FAIL: direct conversation must report canSendMessages=false after unfriend" >&2
  exit 1
}
echo "PASS: direct conversation becomes read-only after unfriend"

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages?page=1&pageSize=20" "${TEMP_DIR}/messages-after-unfriend.json" '' "$B_TOKEN")"
expect_status "$status" 200 "conversation history remains readable after unfriend" "${TEMP_DIR}/messages-after-unfriend.json"

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

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages" "${TEMP_DIR}/legacy-after-refriend.json" "$A_TOKEN" \
  -F "content=${KNOWN_PLAINTEXT}-AFTER-REFRIEND")"
expect_status "$status" 405 "refriending does not restore the removed plaintext route" "${TEMP_DIR}/legacy-after-refriend.json"

echo
echo "Chat friendship rules and notification safety review test completed successfully against ${BASE_URL}."
