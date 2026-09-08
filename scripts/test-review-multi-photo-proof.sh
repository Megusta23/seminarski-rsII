#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://localhost:5001}"
RUN_ID="$(date +%s)-$RANDOM"
EMAIL="multi-proof-${RUN_ID}@example.com"
PASSWORD='Multi_Proof_Test_220087!'
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
expect_status() {
  local expected="$1" actual="$2" label="$3" body="$4"
  [[ "$actual" == "$expected" ]] || fail "$label: expected HTTP $expected, got $actual $body"
  pass "$label (HTTP $actual)"
}
request() {
  local method="$1" url="$2" output="$3"; shift 3
  curl -sS -o "$output" -w '%{http_code}' -X "$method" "$url" "$@"
}

health="$TMP_DIR/health.json"
status="$(request GET "$API_BASE_URL/api/health" "$health")"
expect_status 200 "$status" 'API health' "$(cat "$health")"

register="$TMP_DIR/register.json"
status="$(request POST "$API_BASE_URL/api/auth/register" "$register" \
  -H 'Content-Type: application/json' \
  --data "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"confirmPassword\":\"$PASSWORD\",\"firstName\":\"Multi\",\"lastName\":\"Proof\"}")"
expect_status 201 "$status" 'register multi-photo user' "$(cat "$register")"
TOKEN="$(jq -r '.accessToken // empty' "$register")"
[[ -n "$TOKEN" ]] || fail 'registration did not return accessToken'
AUTH=(-H "Authorization: Bearer $TOKEN")

categories="$TMP_DIR/categories.json"
status="$(request GET "$API_BASE_URL/api/reference-data/task-categories?page=1&pageSize=100" "$categories" "${AUTH[@]}")"
expect_status 200 "$status" 'load task categories' "$(cat "$categories")"
CATEGORY_ID="$(jq -r 'if type == "array" then . else (.items // []) end | .[0].id // empty' "$categories")"

recurrences="$TMP_DIR/recurrences.json"
status="$(request GET "$API_BASE_URL/api/reference-data/recurrence-types?page=1&pageSize=100" "$recurrences" "${AUTH[@]}")"
expect_status 200 "$status" 'load recurrence types' "$(cat "$recurrences")"
RECURRENCE_ID="$(jq -r 'if type == "array" then . else (.items // []) end | map(select(((.code // "") | ascii_downcase) == "none")) | .[0].id // empty' "$recurrences")"
[[ -n "$CATEGORY_ID" && -n "$RECURRENCE_ID" ]] || fail 'reference data IDs missing'

create_task() {
  local title="$1" out="$2"
  local body
  body="$(jq -nc \
    --arg title "$title" \
    --arg category "$CATEGORY_ID" \
    --arg recurrence "$RECURRENCE_ID" \
    '{title:$title,description:"Multi-photo proof review test",taskCategoryId:$category,recurrenceTypeId:$recurrence,dueAtUtc:null,shareWithFriends:true,requiresProofImage:true}')"
  local code
  code="$(request POST "$API_BASE_URL/api/tasks" "$out" "${AUTH[@]}" -H 'Content-Type: application/json' --data "$body")"
  expect_status 201 "$code" "create $title" "$(cat "$out")"
  jq -r '.id // empty' "$out"
}

# Valid, deterministic PNG fixtures.
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2V1kAAAAASUVORK5CYII=' | base64 --decode > "$TMP_DIR/cover.png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' | base64 --decode > "$TMP_DIR/one.png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8zwAAAgEBAP6n0xQAAAAASUVORK5CYII=' | base64 --decode > "$TMP_DIR/two.png"
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8DwQACfsD/QFh5QAAAABJRU5ErkJggg==' | base64 --decode > "$TMP_DIR/three.png"

created="$TMP_DIR/task.json"
TASK_ID="$(create_task "Two-photo proof $RUN_ID" "$created" | tail -1)"
[[ -n "$TASK_ID" ]] || fail 'created task ID missing'
options="$TMP_DIR/options.json"
status="$(request GET "$API_BASE_URL/api/tasks/$TASK_ID/completion-date-options" "$options" "${AUTH[@]}")"
expect_status 200 "$status" 'load completion-date options' "$(cat "$options")"
OCCURRENCE_DATE="$(jq -r '.allowedDates[-1] // .businessDate // empty' "$options")"
[[ -n "$OCCURRENCE_DATE" ]] || fail 'allowed occurrence date missing'

completion="$TMP_DIR/completion.json"
status="$(request POST "$API_BASE_URL/api/tasks/$TASK_ID/complete" "$completion" \
  "${AUTH[@]}" \
  -F "OccurrenceDate=$OCCURRENCE_DATE" \
  -F 'Note=Two edited photos in a vertical layout' \
  -F 'ProofLayoutCode=two-vertical' \
  -F "ProofImage=@$TMP_DIR/cover.png;type=image/png" \
  -F "ProofImages=@$TMP_DIR/one.png;type=image/png" \
  -F "ProofImages=@$TMP_DIR/two.png;type=image/png")"
expect_status 201 "$status" 'complete task with two-photo proof' "$(cat "$completion")"
PRIMARY_MEDIA_ID="$(jq -r '.proofMediaId // .proofMedia.id // .completion.proofMediaId // empty' "$completion")"
[[ -n "$PRIMARY_MEDIA_ID" ]] || fail "completion response does not expose primary proof media ID: $(cat "$completion")"

gallery="$TMP_DIR/gallery.json"
status="$(request GET "$API_BASE_URL/api/proof-galleries/by-media/$PRIMARY_MEDIA_ID" "$gallery" "${AUTH[@]}")"
expect_status 200 "$status" 'load proof gallery' "$(cat "$gallery")"
[[ "$(jq -r '.layoutCode' "$gallery")" == 'two-vertical' ]] || fail 'gallery layoutCode is not two-vertical'
[[ "$(jq -r '.items | length' "$gallery")" == '2' ]] || fail 'gallery does not contain exactly two photos'
[[ "$(jq -r '[.items[].orderIndex] == [0,1]' "$gallery")" == 'true' ]] || fail 'gallery order is not stable'
pass 'multi-photo layout and order persisted'

for item_id in $(jq -r '.items[].id' "$gallery"); do
  output="$TMP_DIR/$item_id.bin"
  status="$(request GET "$API_BASE_URL/api/proof-galleries/items/$item_id" "$output" "${AUTH[@]}")"
  expect_status 200 "$status" 'download protected gallery item' ''
  signature="$(od -An -t x1 -N 8 "$output" | tr -d ' \n')"
  [[ "$signature" == '89504e470d0a1a0a' ]] || fail 'downloaded proof item is not PNG'
done

invalid_task="$TMP_DIR/invalid-task.json"
INVALID_TASK_ID="$(create_task "Invalid four-photo proof $RUN_ID" "$invalid_task" | tail -1)"
invalid="$TMP_DIR/invalid.json"
status="$(request POST "$API_BASE_URL/api/tasks/$INVALID_TASK_ID/complete" "$invalid" \
  "${AUTH[@]}" \
  -F "OccurrenceDate=$OCCURRENCE_DATE" \
  -F 'ProofLayoutCode=four-grid' \
  -F "ProofImage=@$TMP_DIR/cover.png;type=image/png" \
  -F "ProofImages=@$TMP_DIR/one.png;type=image/png" \
  -F "ProofImages=@$TMP_DIR/two.png;type=image/png")"
expect_status 400 "$status" 'reject wrong photo count for layout' "$(cat "$invalid")"

unsupported_task="$TMP_DIR/unsupported-task.json"
UNSUPPORTED_TASK_ID="$(create_task "Unsupported proof layout $RUN_ID" "$unsupported_task" | tail -1)"
unsupported="$TMP_DIR/unsupported.json"
status="$(request POST "$API_BASE_URL/api/tasks/$UNSUPPORTED_TASK_ID/complete" "$unsupported" \
  "${AUTH[@]}" \
  -F "OccurrenceDate=$OCCURRENCE_DATE" \
  -F 'ProofLayoutCode=unknown-layout' \
  -F "ProofImage=@$TMP_DIR/cover.png;type=image/png" \
  -F "ProofImages=@$TMP_DIR/one.png;type=image/png")"
expect_status 400 "$status" 'reject unsupported proof layout' "$(cat "$unsupported")"

printf 'Multi-photo proof review test completed successfully against %s.\n' "$API_BASE_URL"
