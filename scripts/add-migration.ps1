param(
    [Parameter(Mandatory = $true)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'

if (-not (Test-Path $envFile)) {
    throw '.env was not found. Copy .env.example to .env first.'
}

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#')) {
        $parts = $line.Split('=', 2)
        if ($parts.Count -eq 2) {
            [Environment]::SetEnvironmentVariable($parts[0], $parts[1], 'Process')
        }
    }
}

$sqlPort = if ($env:SQL_HOST_PORT) { $env:SQL_HOST_PORT } else { '14333' }
$databaseName = if ($env:DATABASE_NAME) { $env:DATABASE_NAME } else { '220087' }
$env:DATABASE_CONNECTION_STRING = "Server=localhost,$sqlPort;Database=$databaseName;User Id=sa;Password=$($env:SQL_SA_PASSWORD);Encrypt=False;TrustServerCertificate=True"

Push-Location $root
try {
    dotnet tool restore
    dotnet tool run dotnet-ef migrations add $Name `
      --project src/LadderSocial.Infrastructure/LadderSocial.Infrastructure.csproj `
      --startup-project src/LadderSocial.Api/LadderSocial.Api.csproj `
      --output-dir Persistence/Migrations
}
finally {
    Pop-Location
}
