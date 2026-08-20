# Authentication implementation summary

This vertical slice provides a testable security foundation for both Ladder Social clients.

## Backend

- ASP.NET Identity user creation and password hashing
- JWT access-token generation and signature validation
- `User` and `Admin` role claims
- login lockout after repeated failed attempts
- cryptographically secure refresh-token generation
- refresh-token hashes stored in SQL Server
- one-time refresh-token rotation inside a serializable transaction
- server-side logout and immediate access-token invalidation through the Identity security stamp
- authenticated current-profile endpoint
- administrator-only authorization test endpoint
- standardized Problem Details responses for application errors, HTTP 401 and HTTP 403
- seeded mobile and administrator accounts configured through `.env`

## Shared Flutter package

- typed authentication and profile models
- reusable authentication API service and repository
- `flutter_secure_storage` token persistence
- access-token attachment to protected requests
- one synchronized refresh attempt for concurrent HTTP 401 responses
- one safe retry for replayable JSON requests
- session clearing and UI notification when refresh fails
- backend validation-message parsing

## Mobile application

- session restoration on startup
- login form
- registration form
- protected profile test screen
- logout
- visible loading, validation and error states

## Desktop administration application

- session restoration on startup
- administrator login
- rejection and revocation of non-admin sessions
- protected profile check
- server-side Admin-role check
- logout

## Test assets

- `scripts/test-auth.sh`: end-to-end HTTP smoke test
- `scripts/verify-source.sh`: .NET and Flutter source checks
- `requests/auth.http`: manual REST Client workflow
- JWT unit tests
- shared Flutter model and Problem Details tests

## Database migrations

Authentication uses the existing `InitialCreate` migration because the user, Identity and refresh-token tables were already part of the model. No additional authentication migration is required for this slice.
