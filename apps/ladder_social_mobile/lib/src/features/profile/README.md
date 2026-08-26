# Profile feature

The root Profile tab uses `GET /api/profile/me/overview` to render an
Instagram-style social profile with avatar, post/friend counts, biography,
productivity statistics and highlighted proof posts.

A single three-line menu exposes the supported account actions:

- edit profile;
- change/remove profile picture;
- manage highlighted posts;
- change password;
- log out.

Editable profile data continues to use `GET/PUT /api/profile/me`. Highlight
selection continues to use `/api/profile/me/highlight-candidates` and
`/api/profile/me/highlights/{postId}`.
