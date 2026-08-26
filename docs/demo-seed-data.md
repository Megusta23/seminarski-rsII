# Demo seed data

Ladder Social can initialize a complete evaluation dataset automatically after EF Core migrations and the required roles/reference records are applied.

## Configuration

```env
SEED_DEMO_DATA=true
```

The submitted development configuration should keep this value enabled. Set it to `false` only when a minimal database containing roles, the administrator account, the primary mobile account and reference records is preferred.

Demo mobile accounts use the configured `SEED_MOBILE_PASSWORD`. The primary accounts remain configured through:

```env
SEED_ADMIN_EMAIL
SEED_ADMIN_PASSWORD
SEED_MOBILE_EMAIL
SEED_MOBILE_PASSWORD
```

Existing passwords are never overwritten during startup.

## Seeded evaluation data

A fresh database receives:

- one administrator and nine mobile users;
- complete mobile profiles with biographies, cities, dates of birth and local avatar images;
- countries, cities, task categories and recurrence types;
- accepted friendships, incoming requests and an outgoing request;
- a friendship graph that produces explainable friend-of-friend recommendations;
- one-time, daily, weekly and monthly tasks across Creative, Social, Self-care and Work;
- private and shared tasks, proof-required tasks, unfinished tasks and completed occurrences;
- completions across several days for profile streaks and daily/weekly leaderboards;
- protected proof images, visible feed posts, one moderated/hidden post and highlighted profile posts;
- read and unread notifications;
- direct conversations, text messages and one protected image attachment;
- enough records for administrator analytics, moderation and both PDF reports.

The primary mobile test account immediately has useful content in Feed, Friends, Requests, Discover, To-do, Ranking, Notifications, Profile and Chat.

## Idempotency

The seeder writes a deterministic marker only after the complete dataset is initialized. Later API restarts do not recreate friendships, tasks, posts or messages and therefore do not overwrite user changes. Seed image files are checked before the marker so a recreated upload volume can be repopulated without duplicating database rows.

If startup is interrupted before the marker is written, deterministic identifiers and existence checks allow the next startup to finish the incomplete dataset safely.

## Clean-database verification

This command intentionally deletes local Docker data:

```bash
docker compose --env-file .env down -v
docker compose --env-file .env up --build -d
```

Wait for the API health endpoint, then run:

```bash
./scripts/test-demo-seed.sh
```

To additionally restart the API and verify that counts are not duplicated:

```bash
DEMO_SEED_RESTART_CHECK=true ./scripts/test-demo-seed.sh
```

Do not use `down -v` on an environment whose data must be preserved.
