#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

for command_name in dotnet flutter; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "Required command '${command_name}' is not installed or is not on PATH." >&2
    exit 1
  fi
done

echo "==> Running offline static source checks"
python3 scripts/static-source-check.py

echo "==> Checking shell-script syntax"
for script_file in scripts/*.sh; do
  bash -n "${script_file}"
done

echo "==> Restoring, building and testing .NET solution"
dotnet restore LadderSocial.sln
dotnet build LadderSocial.sln --no-restore
dotnet test LadderSocial.sln --no-build

verify_flutter_project() {
  local project_dir="$1"
  echo "==> Verifying ${project_dir}"
  (
    cd "${ROOT_DIR}/${project_dir}"
    flutter pub get
    flutter analyze
    flutter test
  )
}

verify_flutter_project "packages/ladder_social_core"
verify_flutter_project "apps/ladder_social_mobile"
verify_flutter_project "apps/ladder_social_admin"

if command -v docker >/dev/null 2>&1 && [[ -f "${ROOT_DIR}/.env" ]]; then
  echo "==> Validating Docker Compose configuration"
  docker compose --env-file .env config >/dev/null
else
  echo "==> Docker Compose validation skipped (.env or Docker command is unavailable)"
fi

echo
echo "All available source checks completed successfully."
