#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} does not exist. Copy .env.example to .env first." >&2
  exit 1
fi

ensure_secret() {
  local key="$1"
  if grep -q "^${key}=" "${ENV_FILE}"; then
    local current
    current="$(sed -n "s/^${key}=//p" "${ENV_FILE}")"
    if [[ ${#current} -ge 64 && "${current}" != replace-* ]]; then
      echo "KEEP: ${key} is already configured."
      return
    fi
    local generated
    generated="$(openssl rand -hex 64)"
    local temp
    temp="$(mktemp)"
    awk -v key="${key}" -v value="${generated}" 'BEGIN { FS=OFS="=" } $1 == key { print key, value; next } { print }' "${ENV_FILE}" > "${temp}"
    mv "${temp}" "${ENV_FILE}"
    echo "UPDATE: ${key} was replaced with a secure random value."
    return
  fi

  printf '\n%s=%s\n' "${key}" "$(openssl rand -hex 64)" >> "${ENV_FILE}"
  echo "ADD: ${key} was added with a secure random value."
}

ensure_setting() {
  local key="$1"
  local value="$2"
  if ! grep -q "^${key}=" "${ENV_FILE}"; then
    printf '%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
    echo "ADD: ${key}=${value}"
  fi
}

ensure_secret "PASSWORD_RESET_HASH_KEY"
ensure_secret "PASSWORD_RESET_EVENT_KEY"
ensure_setting "PASSWORD_RESET_CODE_MINUTES" "15"
ensure_setting "PASSWORD_RESET_MAX_ATTEMPTS" "5"
ensure_setting "PASSWORD_RESET_MIN_REQUEST_INTERVAL_SECONDS" "60"
ensure_setting "SMTP4DEV_WEB_HOST_PORT" "5002"
ensure_setting "SMTP_HOST_PORT" "2525"
ensure_setting "SMTP_USE_SSL" "false"
ensure_setting "SMTP_USE_STARTTLS" "false"
ensure_setting "SMTP_FROM_ADDRESS" "no-reply@laddersocial.local"
ensure_setting "SMTP_FROM_NAME" "Ladder Social"

chmod 600 "${ENV_FILE}" 2>/dev/null || true
echo "Password recovery environment values are ready in ${ENV_FILE}."
