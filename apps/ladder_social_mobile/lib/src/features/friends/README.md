# Friends feature

This module contains user search, requests, accepted friends, recommendations and Friend Profile V2.

Friend Profile V2 is intentionally friend-only and presents:

- avatar, biography and the mock-up-aligned post/friend overview;
- shared-post and accepted-friend counts;
- mutual-friend preview;
- current streak, total completions and active recurring tasks/habits;
- up to six protected highlighted proof posts;
- the existing friendship and direct-message actions.

The profile screen never calculates social statistics locally. It consumes the typed backend aggregate and reuses the authorized media and chat repositories.
