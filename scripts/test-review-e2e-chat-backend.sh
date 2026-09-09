#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/smoke-test-helpers.sh"
initialize_smoke_test "${1:-}"

suffix="$(date +%s)-$$"
PASSWORD='Review_E2E_220087!'
A_EMAIL="review-e2e-a-${suffix}@example.com"
B_EMAIL="review-e2e-b-${suffix}@example.com"
C_EMAIL="review-e2e-c-${suffix}@example.com"
KNOWN_PLAINTEXT='KNOWN-PLAINTEXT-MARKER-220087'

register_test_user "$A_EMAIL" "$PASSWORD" Alice E2E "${TEMP_DIR}/a.json"
register_test_user "$B_EMAIL" "$PASSWORD" Bob E2E "${TEMP_DIR}/b.json"
register_test_user "$C_EMAIL" "$PASSWORD" Charlie Outsider "${TEMP_DIR}/c.json"
A_TOKEN="$(json_get "${TEMP_DIR}/a.json" accessToken)"
A_ID="$(json_get "${TEMP_DIR}/a.json" userId)"
B_TOKEN="$(json_get "${TEMP_DIR}/b.json" accessToken)"
B_ID="$(json_get "${TEMP_DIR}/b.json" userId)"
C_TOKEN="$(json_get "${TEMP_DIR}/c.json" accessToken)"
C_ID="$(json_get "${TEMP_DIR}/c.json" userId)"

status="$(http_request POST "${BASE_URL}/api/friends/requests/${B_ID}" "${TEMP_DIR}/friend-request.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice sends Bob a friend request" "${TEMP_DIR}/friend-request.json"
REQUEST_ID="$(json_get "${TEMP_DIR}/friend-request.json" id)"
status="$(http_request POST "${BASE_URL}/api/friends/requests/${REQUEST_ID}/accept" "${TEMP_DIR}/friend-accept.json" '' "$B_TOKEN")"
expect_status "$status" 204 "Bob accepts Alice" "${TEMP_DIR}/friend-accept.json"

status="$(http_request POST "${BASE_URL}/api/conversations/direct/${B_ID}" "${TEMP_DIR}/conversation.json" '' "$A_TOKEN")"
expect_status "$status" 201 "Alice starts a direct conversation" "${TEMP_DIR}/conversation.json"
CONVERSATION_ID="$(json_get "${TEMP_DIR}/conversation.json" id)"

python3 - "${TEMP_DIR}" <<'PY'
import base64
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
values = {
    "aPublicKey": bytes(range(1, 33)),
    "bPublicKey": bytes(range(33, 65)),
    "cPublicKey": bytes(range(65, 97)),
    "wrappedKey": bytes(range(48)),
    "wrappedKeyChanged": bytes(reversed(range(48))),
    "aliceEnvelopeNonce": bytes(range(101, 113)),
    "bobEnvelopeNonce": bytes(range(113, 125)),
    "textNonce": bytes(range(125, 137)),
    "imageNonce": bytes(range(137, 149)),
    "voiceNonce": bytes(range(149, 161)),
    "videoNonce": bytes(range(161, 173)),
    "textCiphertext": b"authenticated-ciphertext-with-tag-220087",
}
encoded = {key: base64.b64encode(value).decode("ascii") for key, value in values.items()}
(root / "crypto-values.json").write_text(json.dumps(encoded), encoding="utf-8")
(root / "image-ciphertext.bin").write_bytes(bytes(range(256)) * 4)
(root / "voice-ciphertext.bin").write_bytes(b"voice-ciphertext" * 128)
(root / "video-ciphertext.bin").write_bytes(b"video-ciphertext" * 256)
PY

crypto_value() {
  json_get "${TEMP_DIR}/crypto-values.json" "$1"
}

register_device() {
  local token="$1"
  local device_id="$2"
  local public_key="$3"
  local output_file="$4"
  local body
  body="$(printf '{"deviceId":%s,"publicKey":%s}' \
    "$(json_string "$device_id")" \
    "$(json_string "$public_key")")"
  http_request PUT "${BASE_URL}/api/conversations/device-keys" "$output_file" "$body" "$token"
}

status="$(register_device "$A_TOKEN" "alice-device-${suffix}" "$(crypto_value aPublicKey)" "${TEMP_DIR}/a-device.json")"
expect_status "$status" 200 "Alice registers only her public device key" "${TEMP_DIR}/a-device.json"
A_DEVICE_ID="$(json_get "${TEMP_DIR}/a-device.json" id)"
status="$(register_device "$B_TOKEN" "bob-device-${suffix}" "$(crypto_value bPublicKey)" "${TEMP_DIR}/b-device.json")"
expect_status "$status" 200 "Bob registers only his public device key" "${TEMP_DIR}/b-device.json"
B_DEVICE_ID="$(json_get "${TEMP_DIR}/b-device.json" id)"
status="$(register_device "$C_TOKEN" "charlie-device-${suffix}" "$(crypto_value cPublicKey)" "${TEMP_DIR}/c-device.json")"
expect_status "$status" 200 "Charlie registers a public device key" "${TEMP_DIR}/c-device.json"
C_DEVICE_ID="$(json_get "${TEMP_DIR}/c-device.json" id)"

status="$(register_device "$A_TOKEN" "alice-device-${suffix}" "$(crypto_value aPublicKey)" "${TEMP_DIR}/a-device-idempotent.json")"
expect_status "$status" 200 "same device public key registration is idempotent" "${TEMP_DIR}/a-device-idempotent.json"
[[ "$(json_get "${TEMP_DIR}/a-device-idempotent.json" id)" == "$A_DEVICE_ID" ]] || {
  echo "FAIL: idempotent registration changed the device key id" >&2
  exit 1
}

CHANGED_PUBLIC_KEY="$(python3 - <<'PY'
import base64
print(base64.b64encode(b'z' * 32).decode('ascii'))
PY
)"
status="$(register_device "$A_TOKEN" "alice-device-${suffix}" "$CHANGED_PUBLIC_KEY" "${TEMP_DIR}/a-device-conflict.json")"
expect_status "$status" 409 "silent replacement of a device public key is rejected" "${TEMP_DIR}/a-device-conflict.json"

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/device-keys?page=1&pageSize=100" "${TEMP_DIR}/conversation-device-keys.json" '' "$A_TOKEN")"
expect_status "$status" 200 "participant obtains active public device keys" "${TEMP_DIR}/conversation-device-keys.json"
python3 - "${TEMP_DIR}/conversation-device-keys.json" "$A_ID" "$B_ID" "$C_ID" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
rows = payload.get("items", [])
user_ids = {str(row["userId"]).lower() for row in rows}
expected = {sys.argv[2].lower(), sys.argv[3].lower()}
if user_ids != expected:
    raise SystemExit(f"FAIL: expected participant device keys for {expected!r}, got {user_ids!r}")
if sys.argv[4].lower() in user_ids:
    raise SystemExit("FAIL: outsider public key leaked into conversation device keys")
if any("privateKey" in row for row in rows):
    raise SystemExit("FAIL: a private key property was returned by the server")
print("PASS: only active participant public keys are returned")
PY

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/device-keys?page=1&pageSize=100" "${TEMP_DIR}/outsider-device-keys.json" '' "$C_TOKEN")"
expect_status "$status" 404 "non-participant cannot obtain conversation public keys" "${TEMP_DIR}/outsider-device-keys.json"
status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages?page=1&pageSize=20" "${TEMP_DIR}/outsider-messages.json" '' "$C_TOKEN")"
expect_status "$status" 404 "non-participant cannot obtain ciphertext message history" "${TEMP_DIR}/outsider-messages.json"

put_envelope() {
  local recipient_device_id="$1"
  local wrapped_key="$2"
  local nonce="$3"
  local output_file="$4"
  local body
  body="$(printf '{"recipientDeviceKeyId":%s,"senderDeviceKeyId":%s,"encryptedConversationKey":%s,"nonce":%s,"keyVersion":1}' \
    "$(json_string "$recipient_device_id")" \
    "$(json_string "$A_DEVICE_ID")" \
    "$(json_string "$wrapped_key")" \
    "$(json_string "$nonce")")"
  http_request PUT "${BASE_URL}/api/conversations/${CONVERSATION_ID}/key-envelopes" "$output_file" "$body" "$A_TOKEN"
}

status="$(put_envelope "$A_DEVICE_ID" "$(crypto_value wrappedKey)" "$(crypto_value aliceEnvelopeNonce)" "${TEMP_DIR}/a-envelope.json")"
expect_status "$status" 200 "Alice uploads her encrypted conversation-key envelope" "${TEMP_DIR}/a-envelope.json"
status="$(put_envelope "$A_DEVICE_ID" "$(crypto_value wrappedKey)" "$(crypto_value aliceEnvelopeNonce)" "${TEMP_DIR}/a-envelope-idempotent.json")"
expect_status "$status" 200 "same conversation-key envelope PUT is idempotent" "${TEMP_DIR}/a-envelope-idempotent.json"

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages/e2e" "${TEMP_DIR}/missing-envelope-message.json" "$A_TOKEN" \
  -F "type=1" \
  -F "senderDeviceKeyId=${A_DEVICE_ID}" \
  -F "keyVersion=1" \
  -F "encryptedContentBase64=$(crypto_value textCiphertext)" \
  -F "contentNonceBase64=$(crypto_value textNonce)")"
expect_status "$status" 409 "message is blocked until every active device has an envelope" "${TEMP_DIR}/missing-envelope-message.json"

status="$(put_envelope "$B_DEVICE_ID" "$(crypto_value wrappedKey)" "$(crypto_value bobEnvelopeNonce)" "${TEMP_DIR}/b-envelope.json")"
expect_status "$status" 200 "Alice uploads Bob's encrypted conversation-key envelope" "${TEMP_DIR}/b-envelope.json"

status="$(put_envelope "$B_DEVICE_ID" "$(crypto_value wrappedKeyChanged)" "$(crypto_value bobEnvelopeNonce)" "${TEMP_DIR}/b-envelope-conflict.json")"
expect_status "$status" 409 "existing envelope cannot be silently replaced" "${TEMP_DIR}/b-envelope-conflict.json"

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/key-envelopes/${B_DEVICE_ID}?keyVersion=1" "${TEMP_DIR}/b-envelope-read.json" '' "$B_TOKEN")"
expect_status "$status" 200 "recipient obtains only its encrypted key envelope" "${TEMP_DIR}/b-envelope-read.json"
[[ "$(json_get "${TEMP_DIR}/b-envelope-read.json" encryptedConversationKey)" == "$(crypto_value wrappedKey)" ]] || {
  echo "FAIL: encrypted envelope bytes changed on the server" >&2
  exit 1
}

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/key-envelopes/${B_DEVICE_ID}?keyVersion=1" "${TEMP_DIR}/wrong-owner-envelope.json" '' "$A_TOKEN")"
expect_status "$status" 404 "another participant cannot download the recipient device envelope" "${TEMP_DIR}/wrong-owner-envelope.json"
status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/key-envelopes/${C_DEVICE_ID}?keyVersion=1" "${TEMP_DIR}/outsider-envelope.json" '' "$C_TOKEN")"
expect_status "$status" 404 "non-participant cannot download a conversation key envelope" "${TEMP_DIR}/outsider-envelope.json"

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages/e2e" "${TEMP_DIR}/system-message-rejected.json" "$A_TOKEN" \
  -F "type=3" \
  -F "senderDeviceKeyId=${A_DEVICE_ID}" \
  -F "keyVersion=1" \
  -F "encryptedContentBase64=$(crypto_value textCiphertext)" \
  -F "contentNonceBase64=$(crypto_value textNonce)")"
expect_status "$status" 400 "client cannot submit System through the private E2E endpoint" "${TEMP_DIR}/system-message-rejected.json"

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages/e2e" "${TEMP_DIR}/text-message.json" "$A_TOKEN" \
  -F "type=1" \
  -F "senderDeviceKeyId=${A_DEVICE_ID}" \
  -F "keyVersion=1" \
  -F "encryptedContentBase64=$(crypto_value textCiphertext)" \
  -F "contentNonceBase64=$(crypto_value textNonce)")"
expect_status "$status" 201 "encrypted text message is stored" "${TEMP_DIR}/text-message.json"
TEXT_MESSAGE_ID="$(json_get "${TEMP_DIR}/text-message.json" id)"
python3 - "${TEMP_DIR}/text-message.json" "$(crypto_value textCiphertext)" "$KNOWN_PLAINTEXT" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    item = json.load(handle)
if item.get("content") is not None:
    raise SystemExit(f"FAIL: plaintext content column was returned: {item.get('content')!r}")
if item.get("encryptedContent") != sys.argv[2]:
    raise SystemExit("FAIL: ciphertext changed during persistence")
if item.get("encryptionVersion") != 1 or item.get("keyVersion") != 1:
    raise SystemExit("FAIL: E2E version metadata is missing")
if sys.argv[3] in json.dumps(item):
    raise SystemExit("FAIL: known plaintext marker leaked into message response")
print("PASS: encrypted text response contains ciphertext metadata and no plaintext")
PY

send_media() {
  local type="$1"
  local source_file="$2"
  local duration="$3"
  local output_file="$4"
  local nonce_name
  case "$type" in
    2) nonce_name=imageNonce ;;
    4) nonce_name=voiceNonce ;;
    5) nonce_name=videoNonce ;;
    *) echo "Unsupported media type ${type}" >&2; return 2 ;;
  esac
  local args=(
    -F "type=${type}"
    -F "senderDeviceKeyId=${A_DEVICE_ID}"
    -F "keyVersion=1"
    -F "attachmentNonceBase64=$(crypto_value "$nonce_name")"
    -F "attachment=@${source_file};type=application/octet-stream;filename=ciphertext.bin"
  )
  if [[ -n "$duration" ]]; then
    args+=(-F "durationMilliseconds=${duration}")
  fi
  multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages/e2e" "$output_file" "$A_TOKEN" "${args[@]}"
}

status="$(send_media 4 "${TEMP_DIR}/voice-ciphertext.bin" '' "${TEMP_DIR}/voice-missing-duration.json")"
expect_status "$status" 400 "voice ciphertext requires duration metadata" "${TEMP_DIR}/voice-missing-duration.json"

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages/e2e" "${TEMP_DIR}/wrong-media-content-type.json" "$A_TOKEN" \
  -F "type=2" \
  -F "senderDeviceKeyId=${A_DEVICE_ID}" \
  -F "keyVersion=1" \
  -F "attachmentNonceBase64=$(crypto_value imageNonce)" \
  -F "attachment=@${TEMP_DIR}/image-ciphertext.bin;type=image/png;filename=ciphertext.bin")"
expect_status "$status" 400 "encrypted media rejects a plaintext MIME declaration" "${TEMP_DIR}/wrong-media-content-type.json"

status="$(send_media 2 "${TEMP_DIR}/image-ciphertext.bin" '' "${TEMP_DIR}/image-message.json")"
expect_status "$status" 201 "encrypted image message is stored" "${TEMP_DIR}/image-message.json"
IMAGE_ATTACHMENT_ID="$(json_get "${TEMP_DIR}/image-message.json" attachmentId)"
status="$(send_media 4 "${TEMP_DIR}/voice-ciphertext.bin" 1250 "${TEMP_DIR}/voice-message.json")"
expect_status "$status" 201 "encrypted voice message is stored" "${TEMP_DIR}/voice-message.json"
VOICE_ATTACHMENT_ID="$(json_get "${TEMP_DIR}/voice-message.json" attachmentId)"
status="$(send_media 5 "${TEMP_DIR}/video-ciphertext.bin" 2500 "${TEMP_DIR}/video-message.json")"
expect_status "$status" 201 "encrypted video message is stored" "${TEMP_DIR}/video-message.json"
VIDEO_ATTACHMENT_ID="$(json_get "${TEMP_DIR}/video-message.json" attachmentId)"

python3 - "${TEMP_DIR}/image-message.json" "${TEMP_DIR}/voice-message.json" "${TEMP_DIR}/video-message.json" <<'PY'
import json
import sys
expected = [(2, None), (4, 1250), (5, 2500)]
for path, (message_type, duration) in zip(sys.argv[1:], expected):
    with open(path, encoding="utf-8") as handle:
        item = json.load(handle)
    if item.get("type") != message_type:
        raise SystemExit(f"FAIL: wrong media message type in {path}")
    if item.get("content") is not None:
        raise SystemExit(f"FAIL: media response exposed plaintext content in {path}")
    if item.get("attachmentMimeType") != "application/octet-stream":
        raise SystemExit(f"FAIL: encrypted attachment is not octet-stream in {path}")
    if item.get("attachmentEncryptionVersion") != 1:
        raise SystemExit(f"FAIL: encrypted attachment version is missing in {path}")
    if item.get("attachmentDurationMilliseconds") != duration:
        raise SystemExit(f"FAIL: wrong duration metadata in {path}")
print("PASS: image, voice and video responses contain ciphertext-only attachment metadata")
PY

download_and_compare() {
  local attachment_id="$1"
  local source_file="$2"
  local label="$3"
  local download_file="${TEMP_DIR}/downloaded-${label}-ciphertext.bin"
  local status
  status="$(curl -sS -o "$download_file" -w '%{http_code}' \
    -H "Authorization: Bearer ${B_TOKEN}" \
    "${BASE_URL}/api/media/message-attachments/${attachment_id}")"
  expect_status "$status" 200 "participant downloads encrypted ${label} bytes" "$download_file"
  cmp -s "$source_file" "$download_file" || {
    echo "FAIL: downloaded ${label} ciphertext differs from uploaded bytes" >&2
    exit 1
  }
  echo "PASS: encrypted ${label} roundtrip preserves exact ciphertext bytes"
}

download_and_compare "$IMAGE_ATTACHMENT_ID" "${TEMP_DIR}/image-ciphertext.bin" image
download_and_compare "$VOICE_ATTACHMENT_ID" "${TEMP_DIR}/voice-ciphertext.bin" voice
download_and_compare "$VIDEO_ATTACHMENT_ID" "${TEMP_DIR}/video-ciphertext.bin" video

status="$(curl -sS -o "${TEMP_DIR}/outsider-download.json" -w '%{http_code}' \
  -H "Accept: application/json" \
  -H "Authorization: Bearer ${C_TOKEN}" \
  "${BASE_URL}/api/media/message-attachments/${IMAGE_ATTACHMENT_ID}")"
expect_status "$status" 404 "non-participant cannot download encrypted attachment" "${TEMP_DIR}/outsider-download.json"

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages?page=1&pageSize=20" "${TEMP_DIR}/messages.json" '' "$B_TOKEN")"
expect_status "$status" 200 "recipient loads ciphertext message history" "${TEMP_DIR}/messages.json"
python3 - "${TEMP_DIR}/messages.json" "$TEXT_MESSAGE_ID" "$KNOWN_PLAINTEXT" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
serialized = json.dumps(payload)
if sys.argv[3] in serialized:
    raise SystemExit("FAIL: known plaintext marker leaked into message history")
matching = [item for item in payload.get("items", []) if str(item.get("id")) == sys.argv[2]]
if not matching or matching[0].get("content") is not None:
    raise SystemExit("FAIL: encrypted text was not returned with null plaintext content")
print("PASS: history returns ciphertext without the known plaintext marker")
PY

status="$(http_request GET "${BASE_URL}/api/notifications?page=1&pageSize=100" "${TEMP_DIR}/notifications.json" '' "$B_TOKEN")"
expect_status "$status" 200 "recipient loads E2E chat notifications" "${TEMP_DIR}/notifications.json"
python3 - "${TEMP_DIR}/notifications.json" "$CONVERSATION_ID" "$KNOWN_PLAINTEXT" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
bodies = [
    item.get("body", "") for item in payload.get("items", [])
    if str(item.get("relatedEntityId", "")).lower() == sys.argv[2].lower()
]
expected = {
    "Alice E2E sent you a message.",
    "Alice E2E sent you an image.",
    "Alice E2E sent you a voice message.",
    "Alice E2E sent you a video.",
}
if not expected.issubset(set(bodies)):
    raise SystemExit(f"FAIL: missing privacy-safe notification bodies: {bodies!r}")
if any(sys.argv[3] in body for body in bodies):
    raise SystemExit("FAIL: notification leaked the known plaintext marker")
print("PASS: Text/Image/Voice/Video notifications are generic and privacy-safe")
PY

status="$(http_request DELETE "${BASE_URL}/api/friends/${B_ID}" "${TEMP_DIR}/remove-friend.json" '' "$A_TOKEN")"
expect_status "$status" 204 "Alice removes Bob from friends" "${TEMP_DIR}/remove-friend.json"

status="$(multipart_request POST "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages/e2e" "${TEMP_DIR}/blocked-text.json" "$A_TOKEN" \
  -F "type=1" \
  -F "senderDeviceKeyId=${A_DEVICE_ID}" \
  -F "keyVersion=1" \
  -F "encryptedContentBase64=$(crypto_value textCiphertext)" \
  -F "contentNonceBase64=$(crypto_value textNonce)")"
expect_status "$status" 403 "unfriend blocks new encrypted text" "${TEMP_DIR}/blocked-text.json"

for entry in \
  "2:${TEMP_DIR}/image-ciphertext.bin::blocked-image" \
  "4:${TEMP_DIR}/voice-ciphertext.bin:1250:blocked-voice" \
  "5:${TEMP_DIR}/video-ciphertext.bin:2500:blocked-video"; do
  IFS=: read -r message_type source_file duration label <<<"$entry"
  status="$(send_media "$message_type" "$source_file" "$duration" "${TEMP_DIR}/${label}.json")"
  expect_status "$status" 403 "unfriend blocks new encrypted ${label#blocked-}" "${TEMP_DIR}/${label}.json"
done

status="$(http_request GET "${BASE_URL}/api/conversations/${CONVERSATION_ID}/messages?page=1&pageSize=20" "${TEMP_DIR}/history-after-unfriend.json" '' "$B_TOKEN")"
expect_status "$status" 200 "encrypted conversation history remains readable after unfriend" "${TEMP_DIR}/history-after-unfriend.json"

echo
echo "E2E chat backend key, envelope, ciphertext, authorization and friendship smoke test completed successfully against ${BASE_URL}."
