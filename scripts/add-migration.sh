#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || -z "$1" ]]; then
  echo "Usage: $0 DescriptiveMigrationName" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
MIGRATION_NAME="$1"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}. Copy .env.example to .env first." >&2
  exit 1
fi

read_env() {
  local key="$1"
  sed -n "s/^${key}=//p" "${ENV_FILE}" | tail -n 1
}

SQL_PASSWORD="$(read_env SQL_SA_PASSWORD)"
SQL_PORT="$(read_env SQL_HOST_PORT)"
DATABASE_NAME="$(read_env DATABASE_NAME)"

if [[ -z "${SQL_PASSWORD}" ]]; then
  echo "SQL_SA_PASSWORD is missing from .env." >&2
  exit 1
fi

SQL_PORT="${SQL_PORT:-14333}"
DATABASE_NAME="${DATABASE_NAME:-220087}"
export DATABASE_CONNECTION_STRING="Server=localhost,${SQL_PORT};Database=${DATABASE_NAME};User Id=sa;Password=${SQL_PASSWORD};Encrypt=False;TrustServerCertificate=True"

cd "${ROOT_DIR}"
dotnet tool restore
dotnet tool run dotnet-ef migrations add "${MIGRATION_NAME}" \
  --project src/LadderSocial.Infrastructure/LadderSocial.Infrastructure.csproj \
  --startup-project src/LadderSocial.Api/LadderSocial.Api.csproj \
  --output-dir Persistence/Migrations
