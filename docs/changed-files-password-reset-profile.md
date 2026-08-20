# Changed files: password recovery and profile milestone

This change set was prepared against the exact source tree contained in `ladder-social-auth-current.zip`. It is intended for the already-pushed branch:

```text
feature/password-reset-and-profile
```

The patch and updated ZIP intentionally exclude `.git`, `.env`, build output, IDE caches and signing material.

## Functional scope

### API and security

- `POST /api/auth/forgot-password`
- `POST /api/auth/reset-password`
- `POST /api/profile/change-password`
- `PUT /api/profile/me`
- authenticated read-only reference-data endpoints for countries, cities, task categories and recurrence types
- generic forgot-password responses to reduce account enumeration risk
- six-digit reset codes generated with `RandomNumberGenerator`
- HMAC-SHA256 reset-code hashes stored in SQL Server
- AES-GCM protection for the code transported through RabbitMQ
- reset expiration, attempt limits, single use and invalidation of older reset requests
- server-side revocation of refresh tokens after reset/change
- JWT invalidation through the ASP.NET Identity security stamp

### Messaging and email

- durable RabbitMQ password-reset event
- separate Worker consumer using `AsyncEventingBasicConsumer`
- real SMTP delivery through MailKit
- smtp4dev development inbox in Docker Compose
- retry delays and dead-letter routing after exhausted attempts
- database-backed delivery status and error details

### Flutter mobile

- forgot-password screen
- reset-password screen
- authenticated change-password screen
- current-profile edit screen
- city dropdown populated from the API/database
- date-of-birth picker and profile validation display

### Flutter desktop admin

- administrator forgot-password screen
- administrator reset-password screen
- authenticated administrator change-password screen
- existing server-side Admin-role enforcement preserved

## Database

New migration:

```text
20260820120000_AddPasswordResetRequests
```

It adds `PasswordResetRequests`, its foreign key to `AspNetUsers`, and indexes used by the reset workflow. With `DATABASE_BOOTSTRAP_MODE=migrate`, the API applies it during startup. A normal upgrade does not require deleting Docker volumes.

## New environment values

The real `.env` needs:

```text
PASSWORD_RESET_HASH_KEY
PASSWORD_RESET_EVENT_KEY
PASSWORD_RESET_CODE_MINUTES
PASSWORD_RESET_MAX_ATTEMPTS
PASSWORD_RESET_MIN_REQUEST_INTERVAL_SECONDS
SMTP4DEV_WEB_HOST_PORT
SMTP_HOST_PORT
SMTP_USERNAME
SMTP_PASSWORD
SMTP_USE_SSL
SMTP_USE_STARTTLS
SMTP_FROM_ADDRESS
SMTP_FROM_NAME
```

Run this script after applying the patch:

```bash
./scripts/prepare-password-reset-env.sh
```

It preserves existing values and securely creates the two missing reset secrets without printing them.

## Main changed paths

```text
.env.example
Directory.Packages.props
docker-compose.yml
README.md
docs/authentication.md
docs/password-recovery-and-profile.md
requests/password-recovery-and-profile.http
scripts/prepare-password-reset-env.sh
scripts/test-password-recovery.sh
scripts/test-profile.sh
scripts/verify-source.sh

src/LadderSocial.Domain/Entities/PasswordResetRequest.cs
src/LadderSocial.Application/Common/Messaging/PasswordResetRequestedEvent.cs
src/LadderSocial.Application/Common/Options/PasswordResetOptions.cs
src/LadderSocial.Application/Common/Options/SmtpOptions.cs
src/LadderSocial.Application/Features/Auth/PasswordRecoveryContracts.cs
src/LadderSocial.Application/Features/Auth/IPasswordResetCodeService.cs
src/LadderSocial.Application/Features/ReferenceData/ReferenceDataContracts.cs
src/LadderSocial.Infrastructure/Identity/PasswordRecoveryService.cs
src/LadderSocial.Infrastructure/Identity/PasswordResetCodeService.cs
src/LadderSocial.Infrastructure/Messaging/
src/LadderSocial.Infrastructure/Persistence/Migrations/20260820120000_AddPasswordResetRequests.cs
src/LadderSocial.Infrastructure/Persistence/Migrations/20260820120000_AddPasswordResetRequests.Designer.cs
src/LadderSocial.Infrastructure/Services/ReferenceDataService.cs
src/LadderSocial.Worker/PasswordResetEmailConsumerService.cs
src/LadderSocial.Worker/SmtpEmailSender.cs

tests/LadderSocial.UnitTests/PasswordResetCodeServiceTests.cs
packages/ladder_social_core/lib/src/reference_data/
packages/ladder_social_core/test/password_recovery_models_test.dart
apps/ladder_social_mobile/lib/src/features/profile/presentation/edit_profile_screen.dart
apps/ladder_social_mobile/lib/src/features/auth/presentation/*password_screen.dart
apps/ladder_social_admin/lib/src/features/auth/presentation/admin_*password_screen.dart
```

Existing authentication, profile, DI, persistence, Worker, Flutter provider and navigation files were also updated to connect these components.

## Recommended Git application

Start with a clean copy of the branch that produced the uploaded ZIP:

```bash
git switch feature/password-reset-and-profile
git status
git apply --check ~/Downloads/ladder-social-password-reset-profile.patch
git apply ~/Downloads/ladder-social-password-reset-profile.patch
```

Then configure, build and test:

```bash
./scripts/prepare-password-reset-env.sh
docker compose --env-file .env down
docker compose --env-file .env up --build -d
docker compose --env-file .env ps

./scripts/test-auth.sh
./scripts/test-password-recovery.sh
./scripts/test-profile.sh
./scripts/verify-source.sh
```

After all tests pass:

```bash
git add .
git commit -m "feat: add secure password recovery and profile editing"
git push
```

Before committing, confirm that secrets are not tracked:

```bash
git check-ignore -v .env
git ls-files | grep -E '(^|/)\.env$' && echo "ERROR: .env is tracked" || true
```

## Runtime test targets

```text
API:                 http://localhost:5001
smtp4dev web inbox:  http://localhost:5002
RabbitMQ management: http://localhost:15672
SQL Server:           localhost:14333
```

Mobile emulator:

```bash
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=http://10.0.2.2:5001
```

macOS admin client:

```bash
flutter run -d macos \
  --dart-define=API_BASE_URL=http://localhost:5001
```
