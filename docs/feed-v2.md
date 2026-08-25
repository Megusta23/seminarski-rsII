# Feed V2

Feed V2 implements the friends' activity feed described in the Ladder Social seminar proposal. It deliberately focuses on shared productivity activity rather than generic social-media engagement.

## User-facing behavior

The mobile feed is date based and contains activity from accepted, active friends only. Four visual states are presented:

1. Shared task that is still unfinished.
2. Completed task without a proof image.
3. Completed task with a proof image that the viewer has not opened.
4. Completed task with a proof image that the viewer has already opened.

The completed-with-proof state is represented by one activity type plus the persistent `HasBeenViewed` flag. The Flutter UI turns those values into separate "New proof" and "Proof viewed" presentations.

The mobile interface groups all returned activities by friend. Each friend appears once in a compact card whose header contains:

- avatar and display name;
- relative time of the latest shared feed activity;
- completed shared-task count for the selected date;
- current completion streak.

The tasks are listed directly below that header, using the category colours and connected checkbox rail from the seminar mock-up. The relative time is intentionally based on shared activity; the application does not claim to track online presence.

The API still returns completed shared task occurrences, total scheduled shared occurrences, a server-calculated percentage and the current streak. Those values remain available to the interface and accessibility descriptions even though the visible card header follows the more compact document design.

## Privacy rules

The API returns an item only when all applicable conditions remain true:

- the viewer and owner have an accepted friendship;
- the owner account is active;
- the task is explicitly marked `ShareWithFriends`;
- the task and post have not been soft-deleted;
- completed posts remain visible to users;
- the requested proof belongs to a visible shared completion.

Removing a friendship, deactivating the owner, hiding a post, deleting a task, or turning off sharing removes access on the next request. Proof files use the same current friendship and visibility checks; knowledge of a media URL is not enough to retrieve the file.

## API contract

### Feed page

```http
GET /api/feed?date=2026-08-23&search=work&page=1&pageSize=20
```

The response contains:

- `Items`: stable date-filtered feed items;
- pagination metadata;
- selected `Date`;
- `HasFriends` and `FriendCount`;
- `FriendProgress` summaries.

Feed items are ordered by `ActivityAtUtc DESC`, then `Id DESC`. Page size is capped by the shared `PagedRequest` limit. The mobile client requests up to 100 daily activities per page so a friend's compact card is rarely split across pages; later pages are still merged into the existing friend card without duplicates.

### Details

The original completed-post details route remains supported:

```http
GET /api/feed/{postId}
```

The typed Feed V2 route supports unfinished tasks and completed posts:

```http
GET /api/feed/items/{itemId}?activityType=1&date=2026-08-23
```

Activity type values are:

```text
1 = Unfinished
2 = CompletedWithoutProof
3 = CompletedWithProof
```

### Viewed state

The strict proof-view operation is:

```http
POST /api/feed/{postId}/view-proof
```

It is authenticated, friendship checked and idempotent. It returns `404` when the visible post has no proof. The earlier `/view` route remains for backward compatibility and is a safe no-op for a visible no-proof post.

## Scheduling rules

An unfinished shared task appears for a selected date when that date represents a valid occurrence:

- non-recurring task: its due date, or its creation date when no due date exists;
- daily task: every day from creation onward;
- weekly task: every seven days from its due/creation anchor;
- monthly task: matching day-of-month from its due/creation anchor.

A task disappears from the unfinished state when a matching `TaskCompletion` exists for the owner, task and occurrence date. One-time tasks completed through the task workflow also receive the completed task status.

## Mobile behavior

The Flutter feed supports:

- previous-day, next-day and calendar date selection;
- friend/task search;
- one grouped card per friend;
- compact friend headers with completed count and streak;
- category-coloured task rows and the connected checkbox rail;
- pull-to-refresh;
- paginated loading with duplicate protection;
- separate no-friends and no-activity states;
- document-aligned loading skeletons and retry states;
- direct proof opening by tapping a task row with proof;
- read-only details for unfinished and no-proof tasks;
- a protected Snapchat-style full-screen proof viewer with zoom, friend header, task title and caption;
- viewed-state persistence only after image bytes load successfully;
- broken-image and viewed-state-save error handling;
- navigation to the friend profile.

## Verification

Run the dedicated smoke suite:

```bash
./scripts/test-feed-v2.sh
```

It verifies authentication, friendship visibility, private-task exclusion, all feed states, progress calculation, details, stable pagination, proof authorization, persistent viewed state, moderation, soft deletion, account deactivation and friendship removal.

The mobile widget tests verify grouped friend cards, the four document states, header metrics, relative activity time and proof-row interaction.

## Deliberate exclusions

Feed V2 does not add likes, comments, music, photo editing, chat expansion, leaderboard changes or recommendation changes. Those modules remain independent from this milestone.
