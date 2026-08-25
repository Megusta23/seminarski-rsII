# Leaderboard V2

## Goal

Leaderboard V2 implements the ranking screen from the approved Ladder Social proposal. The screen is primarily a daily competition between the signed-in user and accepted friends. The first three positions are separated into a podium and the signed-in user's position is visually highlighted.

## Data source

The existing endpoints remain unchanged:

```http
GET /api/leaderboard/daily?date=2026-08-25
GET /api/leaderboard/weekly?weekContaining=2026-08-25
```

The backend returns:

- rank/position;
- user identifier;
- display name;
- protected avatar URL;
- server-calculated score;
- `isCurrentUser`;
- selected date range;
- the current-user entry.

One valid task completion contributes the score stored by the backend. Flutter does not calculate or submit points.

## Visibility

The ranking includes only:

- the current user;
- accepted friends;
- active accounts;
- valid task completions inside the requested daily or weekly date range.

Pending requests, removed friends, inactive accounts and unrelated users are excluded by the service.

## Mobile presentation

The visual order is:

```text
Second place | First place | Third place
```

First place is taller, centred and uses a gold treatment. Second and third use silver and bronze treatments. Entries after the podium are rendered in one bordered table with rank, avatar, name, score and completion icon.

The current user is identified with:

- a blue row or blue podium outline;
- a visible `You` label;
- an accessibility label that identifies the current user.

## Navigation

- Tapping another ranked user opens Friend Profile V2.
- Tapping the current user switches to the mobile Profile tab.

## Responsive and accessibility behaviour

- podium names support two lines and ellipsis;
- row names use one line and ellipsis;
- score values shrink safely when needed;
- one- and two-user podiums do not render broken placeholder cards;
- every interactive entry has a semantic rank/name/score label;
- colour is not the only current-user indicator because the `You` badge is also shown.

## Verification

Run:

```bash
./scripts/test-leaderboard-v2.sh

cd apps/ladder_social_mobile
flutter analyze
flutter test test/leaderboard_widgets_test.dart
```

The focused smoke test verifies authentication, accepted-friend visibility, non-friend exclusion, server-calculated daily/weekly positions, current-user metadata and immediate removal after friendship deletion.
