# Architecture baseline

## Backend dependency direction

```text
LadderSocial.Api
  -> LadderSocial.Application
  -> LadderSocial.Infrastructure

LadderSocial.Infrastructure
  -> LadderSocial.Application
  -> LadderSocial.Domain

LadderSocial.Application
  -> LadderSocial.Domain

LadderSocial.Domain
  -> no project dependency
```

Runtime request flow:

```text
Controller -> Application service -> ApplicationDbContext -> SQL Server
```

The API project owns HTTP concerns. Application owns use-case contracts and DTOs. Infrastructure owns EF Core, Identity and external integrations. Domain owns persistent business concepts and enums.

## Services

```text
Flutter mobile -----------+
                           +--> REST API --> SQL Server
Flutter admin ------------+       |
                                  +--> RabbitMQ --> Worker
                                  |
                                  +--> SignalR hubs (later)
```

The Worker must eventually perform real work such as e-mail delivery or durable notification processing. The current Worker process is only the executable boundary and lifecycle scaffold.

## Planned feature modules

- Authentication and refresh-token lifecycle
- Profiles
- Friends and friend requests
- Tasks, recurrence and completions
- Proof media upload
- Feed and post views
- Leaderboard
- Conversations and messages
- Notifications
- Friend-of-friend recommendations
- Admin analytics and PDF reports
- Reference-data administration

## Identity boundary

`AppUser` is an ASP.NET Identity entity in Infrastructure. Domain entities store user foreign keys as `Guid` values. Relationships are configured centrally through EF Core configuration classes.

## Database naming

The database is named `220087`, matching the seminar instructions to use the index number without the `IB` prefix.
