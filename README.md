# Ladder Social — IB220087

Ladder Social is the RSII seminar project consisting of:

- ASP.NET Core REST API
- SQL Server database named `220087`
- separate Worker service
- RabbitMQ
- Flutter Android client
- Flutter desktop administrative client
- shared Flutter/Dart client package

The authentication vertical slice is implemented. Tasks, friends, feed, chat, notifications, recommendations, analytics and PDF reports remain incremental milestones.

## Repository structure

```text
apps/
  ladder_social_mobile/       Flutter Android client
  ladder_social_admin/        Flutter admin client; macOS during development, Windows for submission
packages/
  ladder_social_core/         Shared API, secure storage and authentication code
src/
  LadderSocial.Domain/        Entities, enums and domain primitives
  LadderSocial.Application/   Contracts, DTOs, exceptions and feature boundaries
  LadderSocial.Infrastructure/EF Core, Identity and application-service implementations
  LadderSocial.Api/           HTTP pipeline and controllers
  LadderSocial.Worker/        Separate background-service process/container
tests/
  LadderSocial.UnitTests/
requests/
  auth.http                   Manual REST Client authentication checks
docs/
scripts/
```

## Prerequisites

- .NET 10 SDK
- Flutter stable
- Android SDK and an Android emulator or physical Android device
- Xcode for macOS desktop development
- Docker Desktop with Docker Compose
- Visual Studio Code or another editor

## First start

Create the local environment file:

```bash
cp .env.example .env
```

Replace the development secrets in `.env`, especially `JWT_KEY` and passwords. Then start the backend stack:

```bash
docker compose --env-file .env up --build -d
docker compose --env-file .env ps
```

Default development addresses from `.env.example`:

```text
API health:          http://localhost:5001/api/health
OpenAPI document:    http://localhost:5001/openapi/v1.json
RabbitMQ management: http://localhost:15672
SQL Server:          localhost:14333
```

## Database migrations

The repository contains `InitialCreate` and uses:

```text
DATABASE_BOOTSTRAP_MODE=migrate
```

After changing EF models, restore the repository-local EF tool and create a descriptive migration from the repository root:

```bash
dotnet tool restore

SQL_PASSWORD="$(sed -n 's/^SQL_SA_PASSWORD=//p' .env)"
SQL_PORT="$(sed -n 's/^SQL_HOST_PORT=//p' .env)"
DB_NAME="$(sed -n 's/^DATABASE_NAME=//p' .env)"
export DATABASE_CONNECTION_STRING="Server=localhost,${SQL_PORT};Database=${DB_NAME};User Id=sa;Password=${SQL_PASSWORD};Encrypt=False;TrustServerCertificate=True"

dotnet tool run dotnet-ef migrations add DescriptiveMigrationName \
  --project src/LadderSocial.Infrastructure/LadderSocial.Infrastructure.csproj \
  --startup-project src/LadderSocial.Api/LadderSocial.Api.csproj \
  --output-dir Persistence/Migrations
```

Do not create empty migrations.

## Authentication

Implemented routes:

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/profile/me
PUT  /api/profile/me
GET  /api/admin/access
```

Run the complete backend authentication smoke test:

```bash
./scripts/test-auth.sh
```

Run all .NET and Flutter source checks:

```bash
./scripts/verify-source.sh
```

Detailed instructions are in [`docs/authentication.md`](docs/authentication.md). Manual REST Client requests are in [`requests/auth.http`](requests/auth.http).

Seed credentials are read from `.env`:

```text
SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD
SEED_MOBILE_EMAIL / SEED_MOBILE_PASSWORD
```

## Run the Flutter mobile application

Start the Pixel emulator and confirm it appears as a device:

```bash
flutter emulators --launch Pixel_8
flutter devices
```

Then:

```bash
cd apps/ladder_social_mobile
flutter pub get
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

For a physical phone connected through `adb reverse`:

```bash
adb -d reverse tcp:5001 tcp:5001
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:5001
```

## Run the Flutter admin application on macOS

```bash
cd apps/ladder_social_admin
flutter pub get
flutter run -d macos \
  --dart-define=API_BASE_URL=http://localhost:5001
```

The final Windows build must later be produced and tested on Windows.

## Build and test checks

```bash
dotnet restore LadderSocial.sln
dotnet build LadderSocial.sln
dotnet test LadderSocial.sln

cd packages/ladder_social_core
flutter analyze
flutter test

cd ../../apps/ladder_social_mobile
flutter analyze
flutter test

cd ../ladder_social_admin
flutter analyze
flutter test
```

## Next development milestone

After authentication is verified, implement profile/reference-data management and then the first complete tasks vertical slice:

```text
reference data -> task CRUD -> task completion -> proof image -> feed post
```
