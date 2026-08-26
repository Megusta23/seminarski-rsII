# Ladder Social application testing guide

## 1. Start the environment

```bash
docker compose --env-file .env up --build -d
docker compose --env-file .env ps
curl http://localhost:5001/api/health
```

All five containers should be running, with SQL Server and RabbitMQ healthy.

## 2. Automated test sequence

Run in this order so a failure is easy to isolate:

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

## 3. Manual mobile flow

1. Register and sign in.
2. Edit profile and avatar.
3. Create one-time, daily and proof-required tasks.
4. Complete tasks and verify completion history.
5. Open Friends V2, send and accept friend requests using two accounts, and confirm the accepted request disappears immediately.
6. Confirm the new friend appears in Friends, Requests counts update, and Discover/search reflect the new relationship.
7. On the feed, verify shared unfinished, completed-without-proof and completed-with-proof states.
8. Open a new proof image and confirm the New badge disappears after returning.
9. Verify friend progress, date selection, search, pull-to-refresh and pagination.
10. Remove the friendship and confirm feed/proof access disappears.
11. Verify daily/weekly leaderboard position.
12. Open notifications and mark them read.
13. Start a conversation, send text and image messages.
14. Verify session restoration and logout.

## 4. Manual admin flow

1. Confirm a regular user cannot enter the admin client.
2. Sign in as the seeded administrator.
3. Review dashboard metrics.
4. Search users, open details and test active/inactive controls on a disposable test account.
5. Create, edit and deactivate reference values.
6. Hide and restore a test feed post.
7. Download both PDF reports and open them in a PDF viewer.

## 5. Security checks

- Call protected routes without a token and expect 401.
- Call admin routes with a User token and expect 403.
- Try to access another user’s task and expect 404.
- Try to access a friend proof after friendship removal and expect 403.
- Confirm a private or administrator-hidden task/post never appears in Feed V2.
- Try to read a conversation as a non-participant and expect 404.
- Upload a file with mismatched MIME type/magic bytes and expect 400.
- Reuse a rotated or logged-out refresh token and expect 401.
- Confirm `.env` is ignored and not tracked by Git.

## 6. Clean-environment test

Before final submission, test from a clean checkout or another computer:

```bash
cp .env.example .env
./scripts/prepare-password-reset-env.sh
docker compose --env-file .env up --build -d
```

Then run the complete automated sequence. The application must not require source-code changes, hard-coded addresses or manually edited connection strings.

## Friend Profile V2

Run:

```bash
./scripts/test-friend-profile-v2.sh
```

The test creates disposable users, a mutual-friend graph, recurring and completed tasks, proof posts and profile highlights. It verifies friend-only access, statistics, owner-only highlight management, the six-item limit, moderation behavior, proof authorization and friendship-removal revocation.

## Friends V2

Run:

```bash
./scripts/test-friends-v2.sh
```

The test creates disposable users and verifies incoming/sent request visibility, relationship-aware search request IDs, acceptance, immediate pending-list removal, new-friend visibility, duplicate-action protection, decline, cancel, self-request prevention and friendship removal.
