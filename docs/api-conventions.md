# API conventions

## Route prefix

All controllers use:

```text
/api/<resource>
```

## Authentication

- Anonymous access will be limited to register, login, refresh and password-reset entry points.
- User operations derive the current user ID from validated JWT claims.
- Admin routes require the `Admin` role.
- File routes require both authorization and ownership/membership checks.

## Pagination

Every list endpoint accepts:

```text
page=1&pageSize=20
```

`pageSize` is capped at 100 by `PagedRequest`.

## Errors

The exception middleware maps application exceptions to RFC-style Problem Details responses. Internal stack traces are not returned outside Development.

## Dates

API timestamps are UTC and use names ending in `Utc` where practical.

## DTOs

Controllers never serialize EF entities directly. Separate request and response DTOs are used for each feature.
