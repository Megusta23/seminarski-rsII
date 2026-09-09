#!/usr/bin/env bash
# Helpers for HTTP smoke tests that need valid ciphertext-only chat fixtures.
# The payloads are synthetic contract fixtures; client cryptography is tested in Flutter.

_e2e_require_smoke_helpers() {
  declare -F http_request >/dev/null 2>&1 || {
    echo "e2e-chat-smoke-helpers.sh requires smoke-test-helpers.sh" >&2
    return 1
  }
  declare -F multipart_request >/dev/null 2>&1 || {
    echo "e2e-chat-smoke-helpers.sh requires multipart_request" >&2
    return 1
  }
  declare -F json_string >/dev/null 2>&1 || {
    echo "e2e-chat-smoke-helpers.sh requires json_string" >&2
    return 1
  }
}

_e2e_require_smoke_helpers

# Emits Base64 for count deterministic non-zero bytes beginning at start.
e2e_base64_sequence() {
  local start="$1"
  local count="$2"
  python3 - "$start" "$count" <<'PY'
import base64
import sys
start = int(sys.argv[1])
count = int(sys.argv[2])
value = bytes(((start + index) % 255) + 1 for index in range(count))
print(base64.b64encode(value).decode('ascii'))
PY
}

# Emits Base64 for a UTF-8 synthetic ciphertext fixture. The server treats it as opaque bytes.
e2e_base64_text() {
  python3 - "$1" <<'PY'
import base64
import sys
print(base64.b64encode(sys.argv[1].encode('utf-8')).decode('ascii'))
PY
}

e2e_register_device() {
  local token="$1"
  local device_id="$2"
  local public_key_base64="$3"
  local output_file="$4"
  local body
  body="$(printf '{"deviceId":%s,"publicKey":%s}' \
    "$(json_string "$device_id")" \
    "$(json_string "$public_key_base64")")"
  http_request PUT "${BASE_URL}/api/conversations/device-keys" "$output_file" "$body" "$token"
}

e2e_put_envelope() {
  local conversation_id="$1"
  local token="$2"
  local sender_device_key_id="$3"
  local recipient_device_key_id="$4"
  local wrapped_key_base64="$5"
  local nonce_base64="$6"
  local output_file="$7"
  local body
  body="$(printf '{"recipientDeviceKeyId":%s,"senderDeviceKeyId":%s,"encryptedConversationKey":%s,"nonce":%s,"keyVersion":1}' \
    "$(json_string "$recipient_device_key_id")" \
    "$(json_string "$sender_device_key_id")" \
    "$(json_string "$wrapped_key_base64")" \
    "$(json_string "$nonce_base64")")"
  http_request PUT \
    "${BASE_URL}/api/conversations/${conversation_id}/key-envelopes" \
    "$output_file" \
    "$body" \
    "$token"
}

e2e_send_text() {
  local conversation_id="$1"
  local token="$2"
  local sender_device_key_id="$3"
  local ciphertext_base64="$4"
  local nonce_base64="$5"
  local output_file="$6"
  multipart_request POST \
    "${BASE_URL}/api/conversations/${conversation_id}/messages/e2e" \
    "$output_file" \
    "$token" \
    -F "type=1" \
    -F "senderDeviceKeyId=${sender_device_key_id}" \
    -F "keyVersion=1" \
    -F "encryptedContentBase64=${ciphertext_base64}" \
    -F "contentNonceBase64=${nonce_base64}"
}
