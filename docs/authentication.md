# Authentication implementation and test guide

## Implemented API endpoints

| Method | Route | Authorization | Purpose |
|---|---|---|---|
| POST | `/api/auth/register` | Anonymous | Creates a regular User account and returns a token pair. |
| POST | `/api/auth/login` | Anonymous | Validates credentials, lockout and account status. |
| POST | `/api/auth/refresh` | Refresh token | Rotates a one-time refresh token and returns a new token pair. |
| POST | `/api/auth/forgot-password` | Anonymous | Queues a generic, rate-limited password-reset email response. |
| POST | `/api/auth/reset-password` | Anonymous | Consumes a one-time six-digit code and resets the password. |
| POST | `/api/auth/logout` | Bearer JWT | Revokes the supplied refresh token and invalidates the current access-token security stamp. |
| GET | `/api/profile/me` | Bearer JWT | Returns the current user and profile derived from JWT identity. |
| PUT | `/api/profile/me` | Bearer JWT | Updates the current user's profile. |
| POST | `/api/profile/change-password` | Bearer JWT | Changes the current password and revokes every session. |
| GET | `/api/admin/access` | Admin role | Confirms that JWT role authorization works. |

## Security behavior

- Registration never accepts a role or administrator flag from the client.
- ASP.NET Identity hashes passwords and enforces the configured password policy.
- New users receive only the `User` role.
- Access tokens contain user, email, display-name, role, token ID and security-stamp claims.
- JWT claim-name mapping is kept consistent with ASP.NET role authorization.
- Raw refresh tokens are returned only to the client; SQL Server stores their SHA-256 hashes.
- Refresh tokens are one-time tokens. A successful refresh revokes the old token and links it to the replacement hash.
- Refresh rotation uses a serializable transaction to prevent concurrent reuse of one token.
- Logout verifies token ownership, revokes the refresh token and changes the ASP.NET Identity security stamp. Previously issued access tokens then fail validation on protected endpoints.
- The current user ID is always taken from validated JWT claims.
- Anonymous, unauthorized and forbidden responses use JSON Problem Details and include a trace identifier.
- Mobile and desktop tokens are stored through `flutter_secure_storage`.
- The shared API client attempts one synchronized refresh and one request replay after a protected request returns HTTP 401. It never retries file uploads or loops indefinitely.

## Start the backend

From the repository root:

```bash
docker compose --env-file .env up --build -d
docker compose --env-file .env ps
curl http://localhost:5001/api/health
```

If your `.env` uses a different `API_HOST_PORT`, use that port instead.

## Automated authentication smoke test

The script reads seed credentials and the API port from `.env`:

```bash
./scripts/test-auth.sh
```

It verifies:

1. API health.
2. Anonymous access to `/api/profile/me` returns HTTP 401.
3. Registration creates a regular user and ignores attempted client-side Admin assignment.
4. Duplicate registration returns HTTP 409.
5. A wrong password returns HTTP 401.
6. A valid JWT can access `/api/profile/me`.
7. A regular user receives HTTP 403 from `/api/admin/access`.
8. Refresh-token rotation returns a new token pair.
9. Reusing the old refresh token returns HTTP 401.
10. Logout succeeds and revokes the active refresh token.
11. The logged-out access token is rejected immediately.
12. Refresh after logout is rejected.
13. The seeded mobile account has only the `User` role and cannot use the admin endpoint.
14. The seeded administrator has only the `Admin` role and can use the admin endpoint.
15. One user cannot revoke another user's refresh token.
16. Seeded mobile and administrator sessions can be logged out cleanly.

You can provide a custom base URL:

```bash
./scripts/test-auth.sh http://localhost:5001
```

## Source verification

Run all available .NET and Flutter checks from the repository root:

```bash
./scripts/verify-source.sh
```

That script runs:

```text
dotnet restore
dotnet build
dotnet test
flutter pub get
flutter analyze
flutter test
Docker Compose configuration validation
```

## VS Code REST Client

Open `requests/auth.http`, then run the requests in order. Change the registration email before repeating the registration request.

## Run the mobile client

Android emulator:

```bash
cd apps/ladder_social_mobile
flutter pub get
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

The mobile authentication screen supports registration, login, session restoration, protected-profile loading and logout.

## Run the macOS admin client

```bash
cd apps/ladder_social_admin
flutter pub get
flutter run -d macos \
  --dart-define=API_BASE_URL=http://localhost:5001
```

Only the account configured by `SEED_ADMIN_EMAIL` and `SEED_ADMIN_PASSWORD`, or another account assigned the Admin role on the server, can open the desktop dashboard.

## Expected seed accounts

The actual values come from your local `.env`:

```text
SEED_MOBILE_EMAIL / SEED_MOBILE_PASSWORD
SEED_ADMIN_EMAIL  / SEED_ADMIN_PASSWORD
```

If an older persisted Docker database contains seed users with different passwords, either keep using those existing passwords or reset local development data once:

```bash
docker compose --env-file .env down -v
docker compose --env-file .env up --build -d
```

The `-v` option deletes local SQL Server and RabbitMQ volumes. Do not use it when you need to preserve local data.

Do not commit `.env` or real secrets.

## Password recovery and profile continuation

The next authentication-related routes are now implemented:

```text
POST /api/auth/forgot-password
POST /api/auth/reset-password
POST /api/profile/change-password
```

Current-profile editing and authenticated reference-data lookups are also available:

```text
PUT /api/profile/me
GET /api/reference-data/countries
GET /api/reference-data/cities
GET /api/reference-data/task-categories
GET /api/reference-data/recurrence-types
```

For environment setup, RabbitMQ/Worker email delivery, smtp4dev usage and the new test scripts, see [`password-recovery-and-profile.md`](password-recovery-and-profile.md).
