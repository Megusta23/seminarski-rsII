#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

MOBILE_EMAIL="$(read_env SEED_MOBILE_EMAIL)"
MOBILE_PASSWORD="$(read_env SEED_MOBILE_PASSWORD)"
ADMIN_EMAIL="$(read_env SEED_ADMIN_EMAIL)"
ADMIN_PASSWORD="$(read_env SEED_ADMIN_PASSWORD)"
SEED_DEMO_DATA="$(read_env SEED_DEMO_DATA)"
SEED_DEMO_DATA="${SEED_DEMO_DATA:-true}"

if [[ "$(printf '%s' "$SEED_DEMO_DATA" | tr '[:upper:]' '[:lower:]')" != "true" ]]; then
  echo "SEED_DEMO_DATA must be true before running this test." >&2
  exit 1
fi

login_user "$MOBILE_EMAIL" "$MOBILE_PASSWORD" "${TEMP_DIR}/mobile-login.json"
MOBILE_TOKEN="$(json_get "${TEMP_DIR}/mobile-login.json" accessToken)"
MOBILE_ID="$(json_get "${TEMP_DIR}/mobile-login.json" userId)"

login_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "${TEMP_DIR}/admin-login.json"
ADMIN_TOKEN="$(json_get "${TEMP_DIR}/admin-login.json" accessToken)"

assert_minimum() {
  local file="$1"
  local path="$2"
  local minimum="$3"
  local label="$4"
  python3 - "$file" "$path" "$minimum" "$label" <<'PY'
import json, sys
file, path, minimum, label = sys.argv[1:]
with open(file, encoding="utf-8") as handle:
    value = json.load(handle)
for part in filter(None, path.split(".")):
    value = value[int(part)] if isinstance(value, list) else value[part]
if int(value) < int(minimum):
    raise SystemExit(f"{label}: expected at least {minimum}, got {value}")
print(f"PASS: {label} ({value})")
PY
}

assert_collection_minimum() {
  local file="$1"
  local path="$2"
  local minimum="$3"
  local label="$4"
  python3 - "$file" "$path" "$minimum" "$label" <<'PY'
import json, sys
file, path, minimum, label = sys.argv[1:]
with open(file, encoding="utf-8") as handle:
    value = json.load(handle)
for part in filter(None, path.split(".")):
    value = value[int(part)] if isinstance(value, list) else value[part]
if len(value) < int(minimum):
    raise SystemExit(f"{label}: expected at least {minimum}, got {len(value)}")
print(f"PASS: {label} ({len(value)})")
PY
}

status="$(http_request GET "${BASE_URL}/api/profile/me/overview" "${TEMP_DIR}/overview.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded own-profile overview" "${TEMP_DIR}/overview.json"
python3 - "${TEMP_DIR}/overview.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
requirements = {
    "friendCount": 3,
    "completedTaskCount": 8,
    "habitCount": 4,
    "currentStreak": 4,
    "visiblePostCount": 5,
}
for key, minimum in requirements.items():
    actual = int(payload.get(key, 0))
    if actual < minimum:
        raise SystemExit(f"{key}: expected at least {minimum}, got {actual}")
if not payload.get("avatarUrl"):
    raise SystemExit("Seeded mobile profile is missing an avatarUrl")
if len(payload.get("highlightedPosts", [])) < 2:
    raise SystemExit("Seeded mobile profile needs at least two highlighted posts")
print("PASS: seeded profile contains social statistics, avatar and highlights")
PY

AVATAR_URL="$(json_get "${TEMP_DIR}/overview.json" avatarUrl)"
HIGHLIGHT_PROOF_URL="$(json_get "${TEMP_DIR}/overview.json" highlightedPosts.0.proofUrl)"
status="$(http_request GET "${BASE_URL}${AVATAR_URL}" "${TEMP_DIR}/seed-avatar.png" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "download seeded profile avatar" "${TEMP_DIR}/seed-avatar.png"
status="$(http_request GET "${BASE_URL}${HIGHLIGHT_PROOF_URL}" "${TEMP_DIR}/seed-proof.png" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "download seeded highlighted proof" "${TEMP_DIR}/seed-proof.png"
python3 - "${TEMP_DIR}/seed-avatar.png" "${TEMP_DIR}/seed-proof.png" <<'PY'
import pathlib, sys
for file_name in sys.argv[1:]:
    data = pathlib.Path(file_name).read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise SystemExit(f"{file_name} is not a valid PNG seed asset")
print("PASS: seeded avatar and proof files contain valid PNG headers")
PY

status="$(http_request GET "${BASE_URL}/api/friends?page=1&pageSize=100" "${TEMP_DIR}/friends.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded accepted friends" "${TEMP_DIR}/friends.json"
assert_minimum "${TEMP_DIR}/friends.json" totalCount 3 "accepted-friend count"

status="$(http_request GET "${BASE_URL}/api/friends/requests/incoming?page=1&pageSize=100" "${TEMP_DIR}/incoming.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded incoming requests" "${TEMP_DIR}/incoming.json"
assert_minimum "${TEMP_DIR}/incoming.json" totalCount 2 "incoming-request count"

status="$(http_request GET "${BASE_URL}/api/friends/requests/outgoing?page=1&pageSize=100" "${TEMP_DIR}/outgoing.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded outgoing requests" "${TEMP_DIR}/outgoing.json"
assert_minimum "${TEMP_DIR}/outgoing.json" totalCount 1 "outgoing-request count"

status="$(http_request GET "${BASE_URL}/api/friends/recommendations" "${TEMP_DIR}/recommendations.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded friend recommendations" "${TEMP_DIR}/recommendations.json"
assert_collection_minimum "${TEMP_DIR}/recommendations.json" "" 1 "recommendation count"

status="$(http_request GET "${BASE_URL}/api/tasks?page=1&pageSize=100" "${TEMP_DIR}/tasks.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded tasks" "${TEMP_DIR}/tasks.json"
assert_minimum "${TEMP_DIR}/tasks.json" totalCount 9 "mobile task count"
python3 - "${TEMP_DIR}/tasks.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
items = payload.get("items", [])
category_codes = {item.get("categoryCode") for item in items}
recurrence_codes = {item.get("recurrenceCode") for item in items}
if not {"creative", "social", "self-care", "work"}.issubset(category_codes):
    raise SystemExit(f"Missing seeded task categories: {category_codes}")
if not {"none", "daily", "weekly"}.issubset(recurrence_codes):
    raise SystemExit(f"Missing seeded recurrence groups: {recurrence_codes}")
if not any(item.get("requiresProofImage") for item in items):
    raise SystemExit("Expected a proof-required seeded task")
if not any(not item.get("shareWithFriends") for item in items):
    raise SystemExit("Expected a private seeded task")
print("PASS: seeded tasks cover categories, recurrence, proof and privacy states")
PY

TODAY="$(date -u +%F)"
status="$(http_request GET "${BASE_URL}/api/feed?date=${TODAY}&page=1&pageSize=100" "${TEMP_DIR}/feed.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded friend feed" "${TEMP_DIR}/feed.json"
assert_minimum "${TEMP_DIR}/feed.json" totalCount 6 "feed activity count"
assert_collection_minimum "${TEMP_DIR}/feed.json" friendProgress 3 "friend-progress entries"

status="$(http_request GET "${BASE_URL}/api/leaderboard/daily?date=${TODAY}" "${TEMP_DIR}/leaderboard.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded daily leaderboard" "${TEMP_DIR}/leaderboard.json"
assert_collection_minimum "${TEMP_DIR}/leaderboard.json" entries 4 "daily leaderboard entries"
python3 - "${TEMP_DIR}/leaderboard.json" "$MOBILE_ID" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
entries = payload.get("entries", [])
if not any(item.get("userId") == sys.argv[2] and item.get("score", 0) > 0 for item in entries):
    raise SystemExit("Seeded mobile user is missing a non-zero leaderboard score")
if max((item.get("score", 0) for item in entries), default=0) < 4:
    raise SystemExit("Seeded leaderboard does not contain a meaningful top score")
print("PASS: seeded leaderboard contains ranked friends and current user")
PY

status="$(http_request GET "${BASE_URL}/api/notifications?page=1&pageSize=100" "${TEMP_DIR}/notifications.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded notifications" "${TEMP_DIR}/notifications.json"
assert_minimum "${TEMP_DIR}/notifications.json" totalCount 6 "notification count"
python3 - "${TEMP_DIR}/notifications.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    items = json.load(handle).get("items", [])
if not any(not item.get("isRead") for item in items):
    raise SystemExit("Expected at least one unread seeded notification")
if not any(item.get("isRead") for item in items):
    raise SystemExit("Expected at least one read seeded notification")
print("PASS: seeded notifications include read and unread states")
PY

status="$(http_request GET "${BASE_URL}/api/conversations?page=1&pageSize=100" "${TEMP_DIR}/conversations.json" '' "$MOBILE_TOKEN")"
expect_status "$status" 200 "seeded conversations" "${TEMP_DIR}/conversations.json"
assert_minimum "${TEMP_DIR}/conversations.json" totalCount 3 "conversation count"

status="$(http_request GET "${BASE_URL}/api/admin/dashboard" "${TEMP_DIR}/dashboard.json" '' "$ADMIN_TOKEN")"
expect_status "$status" 200 "seeded administrator dashboard" "${TEMP_DIR}/dashboard.json"
python3 - "${TEMP_DIR}/dashboard.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
minimums = {
    "totalUsers": 10,
    "activeUsers": 10,
    "tasksCreated": 25,
    "tasksCompletedToday": 10,
    "sharedPosts": 10,
    "friendRequests": 3,
    "messages": 10,
}
for key, minimum in minimums.items():
    actual = int(payload.get(key, 0))
    if actual < minimum:
        raise SystemExit(f"{key}: expected at least {minimum}, got {actual}")
if len(payload.get("topUsers", [])) < 3:
    raise SystemExit("Expected at least three top users on the admin dashboard")
print("PASS: seeded administrator dashboard contains meaningful data")
PY

status="$(http_request GET "${BASE_URL}/api/admin/users?page=1&pageSize=100" "${TEMP_DIR}/admin-users.json" '' "$ADMIN_TOKEN")"
expect_status "$status" 200 "seeded administrator users" "${TEMP_DIR}/admin-users.json"
assert_minimum "${TEMP_DIR}/admin-users.json" totalCount 10 "administrator user-table count"

if [[ "${DEMO_SEED_RESTART_CHECK:-false}" == "true" ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is required for DEMO_SEED_RESTART_CHECK=true." >&2
    exit 1
  fi

  before_users="$(json_get "${TEMP_DIR}/dashboard.json" totalUsers)"
  before_tasks="$(json_get "${TEMP_DIR}/dashboard.json" tasksCreated)"
  before_posts="$(json_get "${TEMP_DIR}/dashboard.json" sharedPosts)"

  docker compose --env-file "${ENV_FILE}" restart api >/dev/null
  for _ in $(seq 1 45); do
    if curl -fsS "${BASE_URL}/api/health" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  login_user "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "${TEMP_DIR}/admin-login-after-restart.json"
  ADMIN_TOKEN_AFTER="$(json_get "${TEMP_DIR}/admin-login-after-restart.json" accessToken)"
  status="$(http_request GET "${BASE_URL}/api/admin/dashboard" "${TEMP_DIR}/dashboard-after-restart.json" '' "$ADMIN_TOKEN_AFTER")"
  expect_status "$status" 200 "dashboard after API restart" "${TEMP_DIR}/dashboard-after-restart.json"
  python3 - "${TEMP_DIR}/dashboard-after-restart.json" "$before_users" "$before_tasks" "$before_posts" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
expected = {
    "totalUsers": int(sys.argv[2]),
    "tasksCreated": int(sys.argv[3]),
    "sharedPosts": int(sys.argv[4]),
}
for key, value in expected.items():
    if payload.get(key) != value:
        raise SystemExit(f"{key} changed after restart: {payload.get(key)} != {value}")
print("PASS: API restart did not duplicate demo data")
PY
fi

echo
echo "Demo seed data is ready for evaluation at ${BASE_URL}."
