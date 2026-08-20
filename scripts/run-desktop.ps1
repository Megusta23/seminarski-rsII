$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $root 'apps/ladder_social_admin')
try {
    flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5000
}
finally {
    Pop-Location
}
