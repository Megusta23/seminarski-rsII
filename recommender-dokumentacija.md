# Ladder Social recommender documentation

## Purpose

Ladder Social recommends potential friends using a graph-based friend-of-friend approach. Users are graph vertices and accepted friendships are bidirectional graph edges. The recommender is intentionally simple, explainable and reproducible for the seminar project.

## Input data

The algorithm uses real application data from:

- `Friendships`, which stores both directed rows for every accepted friendship;
- `FriendRequests`, which identifies pending relationships that must be excluded;
- `AspNetUsers` and `UserProfiles`, which provide active-user and display information;
- `RecommendationLogs`, which records the generated recommendation, score and explanation.

No synthetic rating or unused scoring signal is collected.

## Candidate generation

For current user `U`:

1. Load direct friends `F(U)`.
2. Load friends of every user in `F(U)`.
3. Exclude `U`.
4. Exclude users already in `F(U)`.
5. Exclude users involved in a pending friend request with `U`.
6. Exclude inactive accounts.
7. Group remaining candidates by user ID.

## Score

The score is the number of distinct mutual friends:

```text
score(U, C) = | F(U) ∩ F(C) |
```

Candidates are ordered by descending score. User ID is used only as a deterministic secondary ordering key. A maximum of 20 recommendations is returned per request.

## Explainability

Every response includes a human-readable explanation, for example:

```text
Recommended because you have 3 mutual friends.
```

The exact score and explanation are persisted to `RecommendationLogs`, which provides evidence that the recommendation was generated from the implemented graph signal.

## Endpoint

```http
GET /api/friends/recommendations
Authorization: Bearer <access-token>
```

Example response:

```json
[
  {
    "userId": "7fe1f18b-6c7e-4f31-a214-fac0660d508c",
    "displayName": "Recommended User",
    "avatarUrl": "/api/media/avatars/7fe1f18b-6c7e-4f31-a214-fac0660d508c",
    "mutualFriendCount": 3,
    "explanation": "Recommended because you have 3 mutual friends."
  }
]
```

## Privacy and authorization

- Authentication is required.
- Existing friends and pending relationships are excluded.
- Only active accounts are returned.
- Avatar bytes remain behind an authorized media endpoint.
- The client cannot supply or alter the recommendation score.

## Limitations and future improvements

The current version deliberately prioritizes clarity over machine-learning complexity. Potential future signals include shared task categories, common activity patterns and recommendation interaction feedback. Any future signal must be genuinely stored, used in scoring and documented; unused values must not be collected merely to make the algorithm appear more advanced.
