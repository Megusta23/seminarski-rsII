# Friend Profile V2

Friend Profile V2 implements the document-aligned social profile shown from the mobile friends and feed flows. It is a read-only profile for an accepted friend, plus owner-only controls for selecting photographed task completions as highlighted posts.

## Profile contents

The friend profile aggregate includes:

- avatar, display name, city, biography and member-since date;
- count of visible shared completion posts;
- accepted-friend count;
- current completion streak;
- total valid task completions;
- active recurring-task count, presented as habits;
- mutual-friend count and a compact preview;
- up to six highlighted completed tasks with proof images;
- existing friendship and message actions.

A habit is deliberately defined as an active recurring task. No duplicate `Habits` entity is introduced.

## Statistics

All profile statistics are calculated by the API rather than trusted from Flutter.

### Current streak

The service loads distinct task-completion occurrence dates and counts consecutive dates backwards from today. When there is no completion today, yesterday may continue the active streak. Multiple completions on one date count as one streak day.

### Completed tasks

`CompletedTaskCount` counts valid task-completion records whose task has not been soft-deleted.

### Habits

`HabitCount` counts active, non-deleted tasks whose recurrence code is not `none`.

### Visible posts

`VisiblePostCount` counts shared completion posts that remain visible and whose task is still shared with friends.

### Mutual friends

Mutual friends are the active-user intersection of both accepted-friendship sets. The response includes the complete count and up to six ordered preview records.

## Security and visibility

The detailed profile is returned only when:

- the caller is authenticated;
- the target account exists and is active;
- the caller and target are accepted friends, except that the same endpoint may safely return the caller's own aggregate profile;
- related tasks and posts have not been soft-deleted.

Highlighted media remains protected by the existing media endpoint. A friend must still have an accepted friendship and the highlighted post must remain shared and visible. Removing the friendship immediately removes profile and proof access.

## Highlight management

The owner endpoints are:

```http
GET    /api/profile/me/highlight-candidates?search=hike&page=1&pageSize=20
POST   /api/profile/me/highlights/{postId}
DELETE /api/profile/me/highlights/{postId}
```

A valid highlight must:

- belong to the current user;
- represent a visible shared completion post;
- contain a proof image;
- belong to a task that is still shared with friends.

The maximum is six. Add and remove operations are idempotent. The add operation uses a serializable transaction so concurrent requests cannot normally bypass the maximum.

A highlight is cleared automatically when:

- an administrator hides its post;
- the owner disables sharing for the associated task;
- the owner deletes the associated task.

The schema change adds `Post.IsHighlighted`, `Post.HighlightedAtUtc`, and an index supporting owner/profile queries.

## Mobile behavior

The friend profile screen follows the seminar mock-up and deliberately keeps secondary city/member-since metadata out of the primary layout:

1. Profile overview with avatar, name, post count and friend count.
2. Biography and mutual-friend preview.
3. Friends and Message actions.
4. A three-part statistics strip for streak, tasks completed and habits.
5. A three-column highlighted proof grid.

Interactions include:

- pull-to-refresh;
- open mutual-friend list and nested friend profile;
- open or create the existing direct conversation;
- remove-friend confirmation;
- protected full-screen highlighted-proof viewer with caption, task title, category, date and zoom;
- polished empty, unavailable and error states.

The current user's Profile screen contains **Manage highlighted posts**, which loads eligible proof posts, supports search, shows the six-item limit, and prevents repeated requests while an item is updating.

## API example

```json
{
  "userId": "friend-guid",
  "displayName": "Faruk Chaluk",
  "bio": "Building better habits one day at a time.",
  "avatarUrl": "/api/media/avatars/friend-guid",
  "cityName": "Mostar",
  "memberSinceUtc": "2026-06-15T09:00:00Z",
  "visiblePostCount": 4,
  "friendCount": 122,
  "completedTaskCount": 46,
  "habitCount": 3,
  "currentStreak": 12,
  "canMessage": true,
  "mutualFriends": {
    "count": 3,
    "items": []
  },
  "highlightedPosts": []
}
```

## Verification

Run the focused smoke test:

```bash
./scripts/test-friend-profile-v2.sh
```

It verifies friendship authorization, account status, server-calculated statistics, mutual friends, owner-only highlighting, proof requirements, the six-highlight limit, idempotency, moderation, secure proof access, the existing message action, and immediate access revocation after friendship removal.

Run the normal regression suite afterward:

```bash
./scripts/test-auth.sh
./scripts/test-password-recovery.sh
./scripts/test-profile.sh
./scripts/test-feed-v2.sh
./scripts/test-social-features.sh
./scripts/verify-source.sh
```

## Deliberate exclusions

This milestone does not add followers, public profiles, comments, likes, new chat capabilities, a separate habits module, or desktop profile-management screens. The Message action reuses the existing authorized direct-conversation flow.
