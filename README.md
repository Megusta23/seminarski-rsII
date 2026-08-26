# Ladder Social — IB220087

Ladder Social is a productivity-oriented social network built as the Razvoj softvera II seminar project. The repository contains an ASP.NET Core REST API, SQL Server, a separate RabbitMQ Worker, Flutter Android and desktop clients, and a shared Flutter package.

## Implemented scope

The current implementation includes:

- registration, login, JWT authorization, refresh-token rotation and server-side logout;
- forgot/reset/change password, RabbitMQ delivery and smtp4dev testing;
- Instagram-style Own Profile V2, profile editing, social statistics, highlighted proof posts and protected avatar upload;
- countries, cities, task categories and recurrence types;
- administrator CRUD for all reference data, with search, status filters and pagination;
- task CRUD, ownership checks, filtering, sorting, pagination and master-detail mobile UI;
- one-time and recurring task completions with duplicate-occurrence protection;
- optional/required proof images validated by MIME type, magic bytes and file-size limits;
- Friends V2 with immediate request synchronization, relationship-aware people search, accepted-friend productivity cards, document-aligned friend profiles and graph-based recommendations;
- Feed V2 with shared unfinished/completed tasks, proof/view states, friend progress, date filtering and stable pagination;
- daily and weekly leaderboards calculated from server-side completion data;
- read/unread system notifications with automatic polling and SignalR server support;
- direct text/image chat with membership authorization and automatic polling;
- administrator dashboard, user management and post moderation;
- two backend-generated PDF reports.

## Repository structure

```text
apps/
  ladder_social_mobile/       Flutter Android client
  ladder_social_admin/        Flutter admin client; macOS in development, Windows for submission
packages/
  ladder_social_core/         Shared typed API, secure storage and feature repositories
src/
  LadderSocial.Domain/        Entities, enums and domain primitives
  LadderSocial.Application/   DTOs, feature contracts, exceptions and abstractions
  LadderSocial.Infrastructure/EF Core, Identity, files, messaging and service implementations
  LadderSocial.Api/           Controllers, middleware and SignalR hubs
  LadderSocial.Worker/        Separate RabbitMQ consumer and SMTP process
requests/                     REST Client examples
scripts/                      Build, verification and end-to-end smoke tests
tests/                        .NET unit tests
docs/                         Architecture, security, testing and implementation notes
```

## Prerequisites

- .NET 10 SDK
- current stable Flutter
- Docker Desktop and Docker Compose
- Android SDK plus an emulator or physical Android device
- Xcode for macOS development
- Windows environment for the final Windows desktop release build

## Configuration

Create the local configuration once:

```bash
cp .env.example .env
./scripts/prepare-password-reset-env.sh
```

Never commit `.env`. The application reads secrets and infrastructure values from environment variables, including JWT, SQL Server, RabbitMQ, SMTP and password-reset keys.

Important local defaults:

```text
API:                  http://localhost:5001
API health:           http://localhost:5001/api/health
OpenAPI (development):http://localhost:5001/openapi/v1.json
smtp4dev:             http://localhost:5002
RabbitMQ management: http://localhost:15672
SQL Server:           localhost:14333
```

## Start the backend

```bash
docker compose --env-file .env up --build -d
docker compose --env-file .env ps
curl http://localhost:5001/api/health
```

Follow logs when needed:

```bash
docker compose --env-file .env logs -f api worker
```

Stop without deleting data:

```bash
docker compose --env-file .env down
```

Delete all local Docker data only when an intentional clean reset is required:

```bash
docker compose --env-file .env down -v
```

## Database migrations

The project uses EF Core migrations and `DATABASE_BOOTSTRAP_MODE=migrate`. Current schema milestones are:

```text
InitialCreate
AddPasswordResetRequests
AddApplicationMilestones
```

The API applies pending migrations during startup. To create a new migration:

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

Review every generated migration before applying it. Do not return to `EnsureCreated`.

## Run the mobile client

Start the configured emulator:

```bash
flutter emulators --launch Pixel_8
flutter devices
```

Run on the Android emulator:

```bash
cd apps/ladder_social_mobile
flutter pub get
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

For a USB-connected physical Android device:

```bash
adb -d reverse tcp:5001 tcp:5001
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001
```

## Run the desktop administrator client

On macOS during development:

```bash
cd apps/ladder_social_admin
flutter pub get
flutter run -d macos \
  --dart-define=API_BASE_URL=http://localhost:5001
```

The final Windows build must be produced and tested on Windows:

```powershell
flutter clean
flutter build windows --release --dart-define=API_BASE_URL=http://localhost:5001
```

## Automated verification

Run regression suites in this order:

```bash
./scripts/test-auth.sh
./scripts/test-password-recovery.sh
./scripts/test-profile.sh
./scripts/test-reference-data.sh
./scripts/test-tasks.sh
./scripts/test-todo-v2.sh
./scripts/test-feed-v2.sh
./scripts/test-friend-profile-v2.sh
./scripts/test-own-profile-v2.sh
./scripts/test-leaderboard-v2.sh
./scripts/test-friends-v2.sh
./scripts/test-social-features.sh
./scripts/test-admin-reports.sh
./scripts/verify-source.sh
```

The smoke tests create unique test records and verify authorization, ownership, pagination, validation, recurrence, files, the three To-do V2 sections and four task states, the four Feed V2 states, profile statistics and highlights, document-aligned daily/weekly leaderboard behavior, Friends V2 request synchronization and relationship-aware search, progress and proof privacy, recommendations, chat membership, moderation and PDF output.

`verify-source.sh` runs:

- offline source/import/anti-pattern checks;
- shell syntax checks;
- `dotnet restore`, build and tests;
- `flutter pub get`, analyze and tests for all Flutter packages;
- Docker Compose configuration validation when Docker and `.env` are available.

## Major API groups

```text
/api/auth/*
/api/profile/*
/api/reference-data/*
/api/admin/reference-data/*
/api/tasks/*
/api/media/*
/api/friends/*
/api/feed/*
/api/leaderboard/*
/api/notifications/*
/api/conversations/*
/api/admin/*
/api/admin/reports/*
/hubs/notifications
/hubs/chat
```

All private routes require a validated JWT. Admin routes require the `Admin` role. Current-user operations derive the user ID from the JWT rather than accepting it from the client.

## Documentation

- [`docs/architecture.md`](docs/architecture.md)
- [`docs/authentication.md`](docs/authentication.md)
- [`docs/password-recovery-and-profile.md`](docs/password-recovery-and-profile.md)
- [`docs/application-testing-guide.md`](docs/application-testing-guide.md)
- [`docs/feed-v2.md`](docs/feed-v2.md)
- [`docs/friend-profile-v2.md`](docs/friend-profile-v2.md)
- [`docs/friends-v2.md`](docs/friends-v2.md)
- [`docs/leaderboard-v2.md`](docs/leaderboard-v2.md)
- [`docs/todo-v2.md`](docs/todo-v2.md)
- [`docs/implementation-status.md`](docs/implementation-status.md)
- [`recommender-dokumentacija.md`](recommender-dokumentacija.md)

## Seed credentials

Seed credentials are configured in `.env`:

```text
SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD
SEED_MOBILE_EMAIL / SEED_MOBILE_PASSWORD
```

Do not place real passwords in README files, Git history or GitHub Releases.
