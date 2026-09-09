# Ladder Social implementation status

## Complete vertical slices

- Infrastructure: SQL Server, EF Core migrations, Docker Compose, RabbitMQ, Worker, smtp4dev and persistent upload storage.
- Security: Identity password hashing, JWT, roles, refresh rotation, revocation, security-stamp checks, password reset and change-password.
- Profile: Instagram-style Own Profile V2, current profile editing, avatar upload/removal, social statistics and secure highlighted proof posts.
- Reference data: client reads plus complete admin CRUD for countries, cities, categories and recurrence types.
- Tasks: CRUD, filtering, pagination, ownership, recurrence occurrences, completion history, proof images and document-aligned To-do V2 sections/state controls.
- Social graph: Friends V2 request management, relationship-aware people search, accepted friendships, graph-based recommendations and Friend Profile V2 with mutual friends, server-calculated statistics and secure highlighted proof posts.
- Feed: shared unfinished and completed friend tasks, proof/no-proof and unseen/seen states, date filtering, server-calculated friend progress, stable pagination and protected proof access.
- Ranking: daily and weekly leaderboard.
- Notifications: persisted read/unread notifications, summary, mark-read actions, polling and SignalR server hub.
- Chat: direct conversations, membership authorization, E2E Text/Image/Voice/Video poruke, lokalni media preview/playback, read state, polling i SignalR server hub.
- Administration: dashboard, users, activation/deactivation, post moderation and reference data.
- Reporting: application activity PDF and individual user activity PDF.

## E2E chat sigurnosni opseg

Novi privatni Text, Image, Voice i Video sadržaj enkriptuje se na Flutter klijentu. Backend čuva samo javne device ključeve, encrypted conversation-key envelope-e, nonce vrijednosti, ciphertext i neosjetljive metapodatke. Legacy `EncryptionVersion = 0` historija ostaje read-only, a stari plaintext write endpoint je uklonjen.

Implementacija svjesno ne tvrdi da je Signal Protocol: koristi verzionisani conversation key, X25519, HKDF-HMAC-SHA-256, AES-256-GCM i TOFU pinning, bez Double Ratchet per-message forward secrecy i bez out-of-band safety-number verifikacije. Ta ograničenja su detaljno opisana u `docs/e2e-chat-arhitektura.md`.

## Remaining submission work

- Execute every smoke test against a clean Docker environment.
- Run `scripts/test-review-e2e-multimedia-chat.sh` and preserve its successful output for the final review evidence.
- Complete manual mobile and desktop UX testing.
- Create realistic seed/demo data if the current database is too sparse.
- Produce and test the Android release APK.
- Produce and test the Windows release build on Windows.
- Create the immutable GitHub Release and attach the required build ZIP.
- Record final credentials and startup steps without publishing secrets.
