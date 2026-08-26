# Friends V2

Friends V2 turns the mobile Friends tab into a relationship-management screen that matches the rest of Ladder Social.

## Sections

- Friends: accepted friends, productivity summary, profile, message and remove actions.
- Requests: separate incoming and sent requests with immediate accept, decline and cancel updates.
- Discover: graph-based friend-of-friend suggestions and direct people search.

## Immediate request synchronization

After a request action succeeds, the screen updates its mutable local state before reloading from the API:

- accepting removes the incoming card and inserts the new friend immediately;
- declining removes the incoming card immediately;
- cancelling removes the sent card immediately;
- sending a suggestion removes it from Discover and adds the request to Sent.

Processing request IDs and user IDs disable only the affected card and prevent duplicate taps.

## People search

The app-bar search opens a dedicated relationship-aware search screen. Results show one of these states:

- existing friend: open profile;
- incoming request: accept or decline;
- outgoing request: requested or cancel;
- no relationship: add friend.

Search results never display internal IDs and do not expose email addresses in the UI.

## Recommendation behavior

Discover uses the existing graph-based recommendation endpoint. Every suggestion displays the backend-provided mutual-friend explanation. Existing friends and pending relationships remain excluded by the server.

## Security

Friends V2 keeps the existing backend rules:

- JWT identity determines the current user;
- self-requests and duplicate relationships are rejected;
- only the receiver can accept or decline;
- only the sender can cancel;
- removing a friend revokes friend-profile, feed and protected-media access.

## Tests

Run:

```bash
./scripts/test-friends-v2.sh

cd apps/ladder_social_mobile
flutter test test/friends_widgets_test.dart
flutter test test/friends_search_action_test.dart
```

The smoke test verifies the complete request lifecycle, immediate API-list consistency, relationship-aware search and friendship removal.
