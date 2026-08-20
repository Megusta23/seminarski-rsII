$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'ladder-social-flutter-platforms'

if (Test-Path $tempRoot) {
    Remove-Item $tempRoot -Recurse -Force
}

New-Item $tempRoot -ItemType Directory | Out-Null

Write-Host 'Generating Android platform files...'
$mobileTemp = Join-Path $tempRoot 'mobile'
flutter create --platforms=android --org com.hasanbrkic --project-name ladder_social_mobile $mobileTemp
Copy-Item (Join-Path $mobileTemp 'android') (Join-Path $root 'apps/ladder_social_mobile/android') -Recurse -Force
Copy-Item (Join-Path $mobileTemp '.metadata') (Join-Path $root 'apps/ladder_social_mobile/.metadata') -Force

Write-Host 'Generating Windows platform files...'
$adminTemp = Join-Path $tempRoot 'admin'
flutter create --platforms=windows --org com.hasanbrkic --project-name ladder_social_admin $adminTemp
Copy-Item (Join-Path $adminTemp 'windows') (Join-Path $root 'apps/ladder_social_admin/windows') -Recurse -Force
Copy-Item (Join-Path $adminTemp '.metadata') (Join-Path $root 'apps/ladder_social_admin/.metadata') -Force

Remove-Item $tempRoot -Recurse -Force
Write-Host 'Flutter platform generation completed.'
