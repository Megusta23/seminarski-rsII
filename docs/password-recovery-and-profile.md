# Password recovery, password change and profile milestone

This milestone extends the working JWT authentication flow without changing the existing register, login, refresh-token rotation or logout contracts.

## Implemented API routes

| Method | Route | Authorization | Expected success |
|---|---|---:|---:|
| POST | `/api/auth/forgot-password` | Anonymous | 202 |
| POST | `/api/auth/reset-password` | Anonymous | 204 |
| POST | `/api/profile/change-password` | Bearer JWT | 204 |
| GET | `/api/profile/me` | Bearer JWT | 200 |
| PUT | `/api/profile/me` | Bearer JWT | 200 |
| GET | `/api/reference-data/countries` | Bearer JWT | 200 |
| GET | `/api/reference-data/cities` | Bearer JWT | 200 |
| GET | `/api/reference-data/task-categories` | Bearer JWT | 200 |
| GET | `/api/reference-data/recurrence-types` | Bearer JWT | 200 |

## Password-reset security behavior

- Forgot-password always returns the same generic response for an active, inactive, unknown or rate-limited account.
- Six-digit reset codes are generated with `RandomNumberGenerator`.
- SQL Server stores only an HMAC-SHA256 code hash.
- A reset code expires, has a maximum number of failed attempts and can only be used once.
- Creating a new reset request invalidates older active requests for the same user.
- The code sent through RabbitMQ is protected with authenticated AES-GCM encryption; it is not published as plain text.
- The API sends a durable RabbitMQ event after the reset request is committed.
- A separate Worker container consumes the event and performs real SMTP delivery.
- Worker failures are retried with increasing delays and exhausted messages are dead-lettered.
- Successful password reset clears an account lockout and revokes all refresh tokens.
- Password reset and authenticated password change invalidate existing JWT access tokens through the ASP.NET Identity security stamp.
- Authenticated password change requires the current password and revokes every session.

## Environment setup

The new API and Worker options must be present in the real `.env` file. Do not copy secrets from `.env.example` into source control.

From the repository root:

```bash
./scripts/prepare-password-reset-env.sh
```

The script preserves already configured secrets and securely creates missing or placeholder values for:

```text
PASSWORD_RESET_HASH_KEY
PASSWORD_RESET_EVENT_KEY
```

It also adds safe local defaults for reset-code lifetime, attempt limits and smtp4dev ports.

Review the resulting configuration without printing secret values:

```bash
grep -E '^(PASSWORD_RESET_CODE_MINUTES|PASSWORD_RESET_MAX_ATTEMPTS|PASSWORD_RESET_MIN_REQUEST_INTERVAL_SECONDS|SMTP4DEV_WEB_HOST_PORT|SMTP_HOST_PORT|SMTP_FROM_ADDRESS)=' .env
```

## Database migration

This milestone contains:

```text
20260820120000_AddPasswordResetRequests
```

The migration creates `PasswordResetRequests`, its foreign key to `AspNetUsers`, and query indexes. The API applies it automatically when:

```env
DATABASE_BOOTSTRAP_MODE=migrate
```

Do not run `docker compose down -v` for a normal upgrade. Preserve the current database and let the API apply the new migration.

## Start the complete stack

```bash
docker compose --env-file .env down
docker compose --env-file .env up --build -d
docker compose --env-file .env ps
```

Expected local services:

```text
API:                 http://localhost:5001
smtp4dev web inbox:  http://localhost:5002
RabbitMQ management: http://localhost:15672
SQL Server:           localhost:14333
```

Check migration and Worker startup:

```bash
docker compose --env-file .env logs --tail=200 api
docker compose --env-file .env logs --tail=200 worker
```

Test API health:

```bash
curl http://localhost:5001/api/health
```

## Automated verification

Run the original authentication regression test first:

```bash
./scripts/test-auth.sh
```

Run the new password-recovery workflow test:

```bash
./scripts/test-password-recovery.sh
```

That test creates a disposable user and verifies:

1. A generic response for an unknown email.
2. A reset request for a real user.
3. RabbitMQ-to-Worker-to-smtp4dev delivery.
4. Extraction of the six-digit code from the smtp4dev API.
5. Successful password reset.
6. Immediate rejection of the old access token.
7. Single-use reset-code behavior.
8. Rejection of the previous password.
9. Authenticated password change.
10. Session invalidation after password change.
11. Login with the final password.

Run profile and reference-data verification:

```bash
./scripts/test-profile.sh
```

It verifies profile update persistence, database-backed dropdown data, future-date validation and rejection of an unknown city.

Run source checks:

```bash
./scripts/verify-source.sh
```

## Mobile application test

Start the Android emulator and run the client:

```bash
flutter emulators --launch Pixel_8

cd apps/ladder_social_mobile
flutter pub get
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

Test this flow:

```text
Login screen
→ Forgot password
→ enter email
→ open smtp4dev on the Mac and copy the six-digit code
→ reset password
→ login with the new password
→ Edit profile
→ select a city from the database-backed dropdown
→ save and reload profile
→ Change password
→ confirm automatic return to sign-in
```

For a USB-connected physical Android device using `adb reverse`:

```bash
adb -d reverse tcp:5001 tcp:5001
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5001
```

## macOS admin application test

```bash
cd apps/ladder_social_admin
flutter pub get
flutter run -d macos \
  --dart-define=API_BASE_URL=http://localhost:5001
```

Test this flow:

```text
Administrator login
→ Forgot administrator password
→ retrieve code from smtp4dev
→ reset password
→ login with the new administrator password
→ Change password
→ confirm return to administrator sign-in
```

Password recovery is shared by User and Admin accounts. Server-side role checks remain unchanged, so a regular User account still cannot open the admin dashboard.

## Manual REST requests

Use:

```text
requests/password-recovery-and-profile.http
```

with the VS Code REST Client extension. The automated shell scripts are preferred because they assert expected status codes and can read the smtp4dev API automatically.

## Troubleshooting

### API or Worker fails immediately after the update

The real `.env` probably does not contain the two password-reset secrets:

```bash
./scripts/prepare-password-reset-env.sh
docker compose --env-file .env up --build -d
```

### API reports that `PasswordResetRequests` does not exist

Check migration mode and API logs:

```bash
grep '^DATABASE_BOOTSTRAP_MODE=' .env
docker compose --env-file .env logs --tail=250 api
```

The value should be `migrate`.

### No email appears in smtp4dev

```bash
docker compose --env-file .env ps
docker compose --env-file .env logs --tail=250 worker
docker compose --env-file .env logs --tail=100 rabbitmq
open http://localhost:5002
```

The Worker must be running, RabbitMQ must be healthy, and smtp4dev must be reachable.

### Port 5002 is already in use

Change this in `.env`:

```env
SMTP4DEV_WEB_HOST_PORT=5003
```

Then recreate smtp4dev:

```bash
docker compose --env-file .env up -d --force-recreate smtp4dev
```

The Worker still uses the internal Docker address `smtp4dev:25`; only the browser URL changes.

## Git and GitHub workflow

Apply the supplied patch on the branch you already pushed:

```bash
git switch feature/password-reset-and-profile
git status
git apply --check ~/Downloads/ladder-social-password-reset-profile.patch
git apply ~/Downloads/ladder-social-password-reset-profile.patch
```

After running the tests:

```bash
git add .
git commit -m "feat: add secure password recovery and profile editing"
git push
```

Never commit `.env`. Before committing, verify:

```bash
git check-ignore -v .env
git ls-files | grep -E '(^|/)\.env$' && echo "ERROR: .env is tracked" || true
```
