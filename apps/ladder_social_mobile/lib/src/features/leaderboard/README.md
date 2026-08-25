# Leaderboard V2

The mobile ranking screen follows the approved Ladder Social mockup:

- first place is centred and visually raised;
- second place is shown on the left and third place on the right;
- every podium entry shows avatar, name and server-calculated completion score;
- ranked rows begin below the podium;
- the signed-in user is highlighted in blue and labelled `You`;
- tapping a friend opens Friend Profile V2;
- tapping the current user opens the local Profile tab;
- daily ranking is the default, while the existing weekly ranking remains available;
- pull-to-refresh, loading, empty and API-error states are supported.

The client never calculates leaderboard points. It renders positions and scores returned by the authenticated leaderboard API.
