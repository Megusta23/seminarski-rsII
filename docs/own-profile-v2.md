# Own Profile V2

Own Profile V2 turns the signed-in user's Profile tab into the same social,
productivity-focused presentation used by Friend Profile V2.

## Layout

The root Profile tab contains:

- one centered display-name title;
- one three-line Profile settings action;
- avatar, visible-post count and accepted-friend count;
- biography and optional city;
- streak, total completed tasks and active recurring tasks (habits);
- a three-column highlighted-proof grid.

The main profile body no longer contains settings cards. Edit profile, profile
picture management, highlighted-post management, password change and logout are
available from the single Profile settings bottom sheet.

## API

`GET /api/profile/me/overview` returns the read-optimized social profile for the
current JWT user. It includes the same statistics and highlight rules used by
`GET /api/friends/{userId}/profile`, which prevents the owner and their friends
from seeing different totals.

## Security

The current user is always derived from the validated JWT. Highlighted proof
media still uses the existing authenticated media endpoint. No public media URL
or caller-supplied current-user ID was introduced.

## Refresh behavior

The overview is invalidated when the Profile tab is selected and after returning
from edit-profile or highlighted-post management. Avatar updates also refresh the
overview immediately. Pull-to-refresh remains available.

## Validation

Run:

```bash
./scripts/test-own-profile-v2.sh
cd apps/ladder_social_mobile
flutter test test/own_profile_widgets_test.dart
flutter analyze
flutter test
```
