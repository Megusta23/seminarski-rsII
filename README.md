# Ladder Social — IB220087

Ladder Social is the Razvoj softvera II seminar project consisting of:

- ASP.NET Core REST API
- SQL Server database named `220087`
- separate .NET Worker service
- RabbitMQ messaging
- smtp4dev local development inbox
- Flutter Android client
- Flutter desktop administrative client
- shared Flutter/Dart client package

The current vertical slices cover secure authentication, password recovery/password change, current-profile editing and read-only reference data. Tasks, friends, feed, leaderboard, notifications, chat, recommendations, analytics and PDF reports remain incremental milestones.

## Repository structure

```text
apps/
  ladder_social_mobile/       Flutter Android client
  ladder_social_admin/        Flutter admin client; macOS during development, Windows for submission
packages/
  ladder_social_core/         Shared API, secure storage, auth and reference-data code
src/
  LadderSocial.Domain/        Entities, enums and domain primitives
  LadderSocial.Application/   Contracts, DTOs, exceptions and feature boundaries
  LadderSocial.Infrastructure/EF Core, Identity, messaging and service implementations
  LadderSocial.Api/           HTTP pipeline and controllers
  LadderSocial.Worker/        Separate RabbitMQ consumer and SMTP delivery process
requests/
  auth.http
  password-recovery-and-profile.http
tests/
  LadderSocial.UnitTests/
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

## First start or upgrade from the authentication branch

Create `.env` when starting from a clean clone:

```bash
cp .env.example .env
```

If you already have a working `.env`, keep it. Generate the new password-recovery secrets and local SMTP defaults:

```bash
./scripts/prepare-password-reset-env.sh
```

Never commit `.env`.

Start the complete backend stack:

```bash
docker compose --env-file .env up --build -d
docker compose --env-file .env ps
```

Default local addresses:

```text
API health:           http://localhost:5001/api/health
OpenAPI document:     http://localhost:5001/openapi/v1.json
smtp4dev inbox:       http://localhost:5002
RabbitMQ management:  http://localhost:15672
SQL Server:           localhost:14333
```

## Database migrations

The repository uses:

```env
DATABASE_BOOTSTRAP_MODE=migrate
```

Current migrations:

```text
InitialCreate
AddPasswordResetRequests
```

The API applies pending migrations during startup. A normal update does not require deleting Docker volumes.

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

Review every generated migration before applying it. Do not create empty migrations.

## Implemented authentication and profile routes

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/forgot-password
POST /api/auth/reset-password
POST /api/auth/logout
GET  /api/profile/me
PUT  /api/profile/me
POST /api/profile/change-password
GET  /api/admin/access
```

Password recovery flow:

```text
API stores a hashed, expiring reset request
→ API publishes an encrypted-code event to RabbitMQ
→ separate Worker consumes the event
→ Worker sends a real SMTP message
→ smtp4dev displays the local development email
```

Reference-data routes currently available to authenticated clients:

```text
GET /api/reference-data/countries
GET /api/reference-data/cities
GET /api/reference-data/task-categories
GET /api/reference-data/recurrence-types
```

## Automated tests

Run the existing authentication regression suite:

```bash
./scripts/test-auth.sh
```

Run password reset, RabbitMQ/Worker email delivery and password-change verification:

```bash
./scripts/test-password-recovery.sh
```

Run profile and reference-data verification:

```bash
./scripts/test-profile.sh
```

Run all available .NET and Flutter checks:

```bash
./scripts/verify-source.sh
```

Detailed instructions are in:

- [`docs/authentication.md`](docs/authentication.md)
- [`docs/password-recovery-and-profile.md`](docs/password-recovery-and-profile.md)
- [`docs/changed-files-password-reset-profile.md`](docs/changed-files-password-reset-profile.md)

Manual REST Client requests are in `requests/`.

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

The mobile app currently supports login, registration, secure session restoration, forgot/reset/change password, protected-profile loading and profile editing.

## Run the Flutter admin application on macOS

```bash
cd apps/ladder_social_admin
flutter pub get
flutter run -d macos \
  --dart-define=API_BASE_URL=http://localhost:5001
```

The desktop app supports administrator login, role enforcement, password recovery, password change, protected profile checks and logout. The final Windows build must later be produced and tested on Windows.

## Direct build and test commands

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

After this branch is merged and tested, implement the first complete task-management vertical slice:

```text
admin reference-data CRUD
→ task CRUD with filtering and pagination
→ task master-detail UI
→ task completion history
→ optional proof image
→ friends-only feed post
```
