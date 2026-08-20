$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $root 'apps/ladder_social_mobile')
try {
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
}
finally {
    Pop-Location
}
