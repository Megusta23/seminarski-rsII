#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

suffix="$(date +%s)-$$"
PASSWORD='Friends_V2_220087!'
A_EMAIL="friends-v2-a-${suffix}@example.com"
B_EMAIL="friends-v2-b-${suffix}@example.com"
C_EMAIL="friends-v2-c-${suffix}@example.com"

register_test_user "$A_EMAIL" "$PASSWORD" Alice FriendsV2 "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Bob FriendsV2 "${TEMP_DIR}/b.json"
register_test_user "$C_EMAIL" "$PASSWORD" Carol FriendsV2 "${TEMP_DIR}/c.json"

A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"
A_ID="$(json_get "${TEMP_DIR}/a.json" userId)"
B_TOKEN="$(json_get "${TEMP_DIR}/b.json" accessToken)"
B_ID="$(json_get "${TEMP_DIR}/b.json" userId)"
C_TOKEN="$(json_get "${TEMP_DIR}/c.json" accessToken)"
C_ID="$(json_get "${TEMP_DIR}/c.json" userId)"

status="$(http_request GET "${BASE_URL}/api/friends/requests/incoming?page=1&pageSize=20" "${TEMP_DIR}/anonymous.json")"
expect_status "$status" 401 "anonymous requests access rejected" "${TEMP_DIR}/anonymous.json"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${B_ID}" "${TEMP_DIR}/a-b-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice sends Bob a request" "${TEMP_DIR}/a-b-request.json"
AB_REQUEST_ID="$(json_get "${TEMP_DIR}/a-b-request.json" id)"

status="$(http_request GET "${BASE_URL}/api/friends/requests/outgoing?page=1&pageSize=20" "${TEMP_DIR}/a-outgoing.json" '' "$A_TOKEN")"
expect_status "$status" 200 "Alice loads sent requests" "${TEMP_DIR}/a-outgoing.json"
json_array_contains "${TEMP_DIR}/a-outgoing.json" items id "$AB_REQUEST_ID"
echo "PASS: sent request appears for sender"

status="$(http_request GET "${BASE_URL}/api/friends/requests/incoming?page=1&pageSize=20" "${TEMP_DIR}/b-incoming.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob loads incoming requests" "${TEMP_DIR}/b-incoming.json"
json_array_contains "${TEMP_DIR}/b-incoming.json" items id "$AB_REQUEST_ID"
echo "PASS: incoming request appears for receiver"

status="$(http_request GET "${BASE_URL}/api/friends/search?search=Alice&excludeExistingRelationships=false&page=1&pageSize=20" "${TEMP_DIR}/b-search-pending.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob searches pending incoming relationship" "${TEMP_DIR}/b-search-pending.json"
python3 - "${TEMP_DIR}/b-search-pending.json" "$A_ID" "$AB_REQUEST_ID" <<'PYSEARCH'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
match = next((item for item in data.get('items', []) if str(item.get('userId')) == sys.argv[2]), None)
if match is None:
    raise SystemExit('Expected Alice in Bob search results.')
if match.get('hasIncomingPendingRequest') is not True:
    raise SystemExit(f"Expected incoming pending state, got {match!r}")
if str(match.get('incomingRequestId')) != sys.argv[3]:
    raise SystemExit(f"Expected incomingRequestId={sys.argv[3]!r}, got {match!r}")
PYSEARCH
echo "PASS: relationship-aware search exposes the incoming request action"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${AB_REQUEST_ID}/accept" "${TEMP_DIR}/accept.json" '' "$B_TOKEN")"
expect_status "$status" 204 "Bob accepts Alice" "${TEMP_DIR}/accept.json"

status="$(http_request GET "${BASE_URL}/api/friends/requests/incoming?page=1&pageSize=20" "${TEMP_DIR}/b-incoming-after.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob reloads incoming requests" "${TEMP_DIR}/b-incoming-after.json"
python3 - "${TEMP_DIR}/b-incoming-after.json" "$AB_REQUEST_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
if any(str(item.get('id')) == sys.argv[2] for item in data.get('items', [])):
    raise SystemExit('Accepted request still appears in the pending incoming list.')
PY
echo "PASS: accepted request disappears from incoming requests"

status="$(http_request GET "${BASE_URL}/api/friends/requests/outgoing?page=1&pageSize=20" "${TEMP_DIR}/a-outgoing-after.json" '' "$A_TOKEN")"
expect_status "$status" 200 "Alice reloads sent requests after acceptance" "${TEMP_DIR}/a-outgoing-after.json"
python3 - "${TEMP_DIR}/a-outgoing-after.json" "$AB_REQUEST_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
if any(str(item.get('id')) == sys.argv[2] for item in data.get('items', [])):
    raise SystemExit('Accepted request still appears in the pending outgoing list.')
PY
echo "PASS: accepted request disappears from sent requests"

status="$(http_request GET "${BASE_URL}/api/friends?page=1&pageSize=20" "${TEMP_DIR}/b-friends.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob reloads friends" "${TEMP_DIR}/b-friends.json"
json_array_contains "${TEMP_DIR}/b-friends.json" items userId "$A_ID"
echo "PASS: accepted user appears in friends immediately"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${AB_REQUEST_ID}/accept" "${TEMP_DIR}/accept-again.json" '' "$B_TOKEN")"
expect_status "$status" 404 "accepted request cannot be accepted twice" "${TEMP_DIR}/accept-again.json"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${C_ID}" "${TEMP_DIR}/b-c-request.json" '' "$B_TOKEN")"
expect_status "$status" 201 "Bob sends Carol a request" "${TEMP_DIR}/b-c-request.json"
BC_REQUEST_ID="$(json_get "${TEMP_DIR}/b-c-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${BC_REQUEST_ID}/reject" "${TEMP_DIR}/reject.json" '' "$C_TOKEN")"
expect_status "$status" 204 "Carol declines Bob" "${TEMP_DIR}/reject.json"
status="$(http_request GET "${BASE_URL}/api/friends/requests/incoming?page=1&pageSize=20" "${TEMP_DIR}/c-after-reject.json" '' "$C_TOKEN")"
expect_status "$status" 200 "Carol reloads incoming requests" "${TEMP_DIR}/c-after-reject.json"
python3 - "${TEMP_DIR}/c-after-reject.json" "$BC_REQUEST_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
if any(str(item.get('id')) == sys.argv[2] for item in data.get('items', [])):
    raise SystemExit('Rejected request still appears in the pending incoming list.')
PY
echo "PASS: declined request disappears immediately"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${C_ID}" "${TEMP_DIR}/a-c-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice sends Carol a request" "${TEMP_DIR}/a-c-request.json"
AC_REQUEST_ID="$(json_get "${TEMP_DIR}/a-c-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${AC_REQUEST_ID}/cancel" "${TEMP_DIR}/cancel.json" '' "$A_TOKEN")"
expect_status "$status" 204 "Alice cancels Carol request" "${TEMP_DIR}/cancel.json"
status="$(http_request GET "${BASE_URL}/api/friends/requests/outgoing?page=1&pageSize=20" "${TEMP_DIR}/a-after-cancel.json" '' "$A_TOKEN")"
expect_status "$status" 200 "Alice reloads sent requests" "${TEMP_DIR}/a-after-cancel.json"
python3 - "${TEMP_DIR}/a-after-cancel.json" "$AC_REQUEST_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
if any(str(item.get('id')) == sys.argv[2] for item in data.get('items', [])):
    raise SystemExit('Cancelled request still appears in the pending outgoing list.')
PY
echo "PASS: cancelled request disappears immediately"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${A_ID}" "${TEMP_DIR}/self-request.json" '' "$A_TOKEN")"
expect_status "$status" 400 "self friend request rejected" "${TEMP_DIR}/self-request.json"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${B_ID}" "${TEMP_DIR}/duplicate-friend.json" '' "$A_TOKEN")"
expect_status "$status" 409 "existing friends cannot receive duplicate request" "${TEMP_DIR}/duplicate-friend.json"

status="$(http_request GET "${BASE_URL}/api/friends/search?search=Alice&excludeExistingRelationships=false&page=1&pageSize=20" "${TEMP_DIR}/search.json" '' "$B_TOKEN")"
expect_status "$status" 200 "relationship-aware people search" "${TEMP_DIR}/search.json"
python3 - "${TEMP_DIR}/search.json" "$A_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
match = next((item for item in data.get('items', []) if str(item.get('userId')) == sys.argv[2]), None)
if match is None:
    raise SystemExit('Expected accepted friend in search results.')
if match.get('isFriend') is not True:
    raise SystemExit(f"Expected isFriend=true, got {match!r}")
PY
echo "PASS: search reports accepted friendship state"

status="$(http_request DELETE "${BASE_URL}/api/friends/${A_ID}" "${TEMP_DIR}/remove.json" '' "$B_TOKEN")"
expect_status "$status" 204 "Bob removes Alice" "${TEMP_DIR}/remove.json"
status="$(http_request GET "${BASE_URL}/api/friends?page=1&pageSize=20" "${TEMP_DIR}/b-after-remove.json" '' "$B_TOKEN")"
expect_status "$status" 200 "Bob reloads friends after removal" "${TEMP_DIR}/b-after-remove.json"
python3 - "${TEMP_DIR}/b-after-remove.json" "$A_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
if any(str(item.get('userId')) == sys.argv[2] for item in data.get('items', [])):
    raise SystemExit('Removed friend still appears in the friends list.')
PY
echo "PASS: removed friend disappears immediately"

status="$(http_request GET "${BASE_URL}/api/friends/search?search=Alice&excludeExistingRelationships=false&page=1&pageSize=20" "${TEMP_DIR}/search-after-remove.json" '' "$B_TOKEN")"
expect_status "$status" 200 "relationship-aware search after removal" "${TEMP_DIR}/search-after-remove.json"
python3 - "${TEMP_DIR}/search-after-remove.json" "$A_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    data = json.load(handle)
match = next((item for item in data.get('items', []) if str(item.get('userId')) == sys.argv[2]), None)
if match is None:
    raise SystemExit('Expected removed user in relationship-aware search results.')
if match.get('isFriend') is not False:
    raise SystemExit(f"Expected isFriend=false after removal, got {match!r}")
if match.get('hasIncomingPendingRequest') is not False or match.get('hasOutgoingPendingRequest') is not False:
    raise SystemExit(f"Expected no pending relationship after removal, got {match!r}")
PY
echo "PASS: search returns an addable relationship after removal"

echo
echo "Friends V2 request lifecycle and relationship-state smoke test completed successfully against ${BASE_URL}."
