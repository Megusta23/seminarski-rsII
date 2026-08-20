#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

echo 'Generating Android platform files...'
flutter create --platforms=android --org com.hasanbrkic --project-name ladder_social_mobile "$TEMP_ROOT/mobile"
rm -rf "$ROOT/apps/ladder_social_mobile/android"
cp -R "$TEMP_ROOT/mobile/android" "$ROOT/apps/ladder_social_mobile/android"
cp "$TEMP_ROOT/mobile/.metadata" "$ROOT/apps/ladder_social_mobile/.metadata"

echo 'Generating Windows platform files...'
flutter create --platforms=windows --org com.hasanbrkic --project-name ladder_social_admin "$TEMP_ROOT/admin"
rm -rf "$ROOT/apps/ladder_social_admin/windows"
cp -R "$TEMP_ROOT/admin/windows" "$ROOT/apps/ladder_social_admin/windows"
cp "$TEMP_ROOT/admin/.metadata" "$ROOT/apps/ladder_social_admin/.metadata"

echo 'Flutter platform generation completed.'
