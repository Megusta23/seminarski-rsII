using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Friends;
using LadderSocial.Domain.Entities;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Identity;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class FriendService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IRealtimeNotifier realtimeNotifier) : IFriendService
{
    public async Task<PagedResult<FriendSummaryResponse>> GetFriendsAsync(
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var query =
            from friendship in dbContext.Friendships.AsNoTracking()
            join user in dbContext.Users.AsNoTracking() on friendship.FriendUserId equals user.Id
            join profile in dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId
            where friendship.UserId == userId && user.IsActive
            select new
            {
                UserId = user.Id,
                user.DisplayName,
                HasAvatar = profile.AvatarStorageKey != null
            };

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item => EF.Functions.Like(item.DisplayName, $"%{search}%"));
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var pageItems = await query
            .OrderBy(item => item.DisplayName)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArrayAsync(cancellationToken);
        var ids = pageItems.Select(item => item.UserId).ToArray();
        var counts = await dbContext.TaskCompletions
            .AsNoTracking()
            .Where(item => ids.Contains(item.UserId))
            .GroupBy(item => item.UserId)
            .Select(group => new { UserId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.UserId, item => item.Count, cancellationToken);
        var streaks = await GetStreaksAsync(ids, cancellationToken);

        var items = pageItems
            .Select(item => new FriendSummaryResponse(
                item.UserId,
                item.DisplayName,
                item.HasAvatar ? $"/api/media/avatars/{item.UserId}" : null,
                counts.GetValueOrDefault(item.UserId),
                streaks.GetValueOrDefault(item.UserId)))
            .ToArray();

        return new PagedResult<FriendSummaryResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<PagedResult<UserSearchResponse>> SearchUsersAsync(
        UserSearchRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var query =
            from user in dbContext.Users.AsNoTracking()
            join profile in dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId
            where user.Id != userId && user.IsActive
            select new
            {
                User = user,
                HasAvatar = profile.AvatarStorageKey != null,
                IsFriend = dbContext.Friendships.Any(friendship =>
                    friendship.UserId == userId && friendship.FriendUserId == user.Id),
                HasOutgoingPendingRequest = dbContext.FriendRequests.Any(friendRequest =>
                    friendRequest.SenderUserId == userId &&
                    friendRequest.ReceiverUserId == user.Id &&
                    friendRequest.Status == FriendRequestStatus.Pending),
                HasIncomingPendingRequest = dbContext.FriendRequests.Any(friendRequest =>
                    friendRequest.SenderUserId == user.Id &&
                    friendRequest.ReceiverUserId == userId &&
                    friendRequest.Status == FriendRequestStatus.Pending)
            };

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.User.DisplayName, $"%{search}%") ||
                (item.User.Email != null && EF.Functions.Like(item.User.Email, $"%{search}%")));
        }

        if (request.ExcludeExistingRelationships)
        {
            query = query.Where(item =>
                !item.IsFriend &&
                !item.HasOutgoingPendingRequest &&
                !item.HasIncomingPendingRequest);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var rows = await query
            .OrderBy(item => item.User.DisplayName)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new
            {
                item.User.Id,
                item.User.DisplayName,
                item.User.Email,
                item.HasAvatar,
                item.IsFriend,
                item.HasOutgoingPendingRequest,
                item.HasIncomingPendingRequest
            })
            .ToArrayAsync(cancellationToken);
        var items = rows
            .Select(item => new UserSearchResponse(
                item.Id,
                item.DisplayName,
                item.Email ?? string.Empty,
                item.HasAvatar ? $"/api/media/avatars/{item.Id}" : null,
                item.IsFriend,
                item.HasOutgoingPendingRequest,
                item.HasIncomingPendingRequest))
            .ToArray();

        return new PagedResult<UserSearchResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public Task<PagedResult<FriendRequestResponse>> GetIncomingRequestsAsync(
        PagedRequest request,
        CancellationToken cancellationToken) =>
        GetRequestsAsync(request, incoming: true, cancellationToken);

    public Task<PagedResult<FriendRequestResponse>> GetOutgoingRequestsAsync(
        PagedRequest request,
        CancellationToken cancellationToken) =>
        GetRequestsAsync(request, incoming: false, cancellationToken);

    public async Task<FriendRequestResponse> SendRequestAsync(
        Guid receiverUserId,
        CancellationToken cancellationToken)
    {
        var senderUserId = RequireCurrentUserId();
        if (receiverUserId == senderUserId)
        {
            throw new ValidationException(
                "Friend-request validation failed.",
                new Dictionary<string, string[]>
                {
                    ["receiverUserId"] = ["You cannot send a friend request to yourself."]
                });
        }

        var receiver = await dbContext.Users
            .AsNoTracking()
            .SingleOrDefaultAsync(item => item.Id == receiverUserId && item.IsActive, cancellationToken)
            ?? throw new NotFoundException("The selected user was not found.");
        var alreadyFriends = await dbContext.Friendships
            .AnyAsync(item => item.UserId == senderUserId && item.FriendUserId == receiverUserId, cancellationToken);
        if (alreadyFriends)
        {
            throw new ConflictException("You are already friends with this user.");
        }

        var pendingRequest = await dbContext.FriendRequests
            .AsNoTracking()
            .AnyAsync(item =>
                item.Status == FriendRequestStatus.Pending &&
                ((item.SenderUserId == senderUserId && item.ReceiverUserId == receiverUserId) ||
                 (item.SenderUserId == receiverUserId && item.ReceiverUserId == senderUserId)),
                cancellationToken);
        if (pendingRequest)
        {
            throw new ConflictException("A pending friend request already exists between these users.");
        }

        var request = new FriendRequest
        {
            SenderUserId = senderUserId,
            ReceiverUserId = receiverUserId,
            Status = FriendRequestStatus.Pending
        };
        var senderName = await dbContext.Users
            .Where(item => item.Id == senderUserId)
            .Select(item => item.DisplayName)
            .SingleAsync(cancellationToken);
        var notification = new Notification
        {
            UserId = receiverUserId,
            Kind = NotificationKind.FriendRequestReceived,
            Title = "New friend request",
            Body = $"{senderName} sent you a friend request.",
            RelatedEntityType = "FriendRequest",
            RelatedEntityId = request.Id
        };

        dbContext.FriendRequests.Add(request);
        dbContext.Notifications.Add(notification);
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyUserAsync(
            receiverUserId,
            "NotificationChanged",
            new { notification.Id, notification.Title, notification.Body },
            cancellationToken);

        return await GetRequestByIdAsync(request.Id, cancellationToken);
    }

    public async Task AcceptRequestAsync(Guid requestId, CancellationToken cancellationToken)
    {
        var receiverUserId = RequireCurrentUserId();
        var request = await dbContext.FriendRequests
            .SingleOrDefaultAsync(item =>
                item.Id == requestId &&
                item.ReceiverUserId == receiverUserId &&
                item.Status == FriendRequestStatus.Pending,
                cancellationToken)
            ?? throw new NotFoundException("The pending friend request was not found.");
        var receiverName = await dbContext.Users
            .Where(item => item.Id == receiverUserId)
            .Select(item => item.DisplayName)
            .SingleAsync(cancellationToken);
        var notification = new Notification
        {
            UserId = request.SenderUserId,
            Kind = NotificationKind.FriendRequestAccepted,
            Title = "Friend request accepted",
            Body = $"{receiverName} accepted your friend request.",
            RelatedEntityType = "User",
            RelatedEntityId = receiverUserId
        };

        var strategy = dbContext.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
            request.Status = FriendRequestStatus.Accepted;
            request.RespondedAtUtc = dateTimeProvider.UtcNow;

            var existingPairs = await dbContext.Friendships
                .Where(item =>
                    (item.UserId == receiverUserId && item.FriendUserId == request.SenderUserId) ||
                    (item.UserId == request.SenderUserId && item.FriendUserId == receiverUserId))
                .Select(item => new { item.UserId, item.FriendUserId })
                .ToArrayAsync(cancellationToken);
            if (!existingPairs.Any(item => item.UserId == receiverUserId && item.FriendUserId == request.SenderUserId))
            {
                dbContext.Friendships.Add(new Friendship
                {
                    UserId = receiverUserId,
                    FriendUserId = request.SenderUserId
                });
            }

            if (!existingPairs.Any(item => item.UserId == request.SenderUserId && item.FriendUserId == receiverUserId))
            {
                dbContext.Friendships.Add(new Friendship
                {
                    UserId = request.SenderUserId,
                    FriendUserId = receiverUserId
                });
            }

            dbContext.Notifications.Add(notification);
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        await realtimeNotifier.NotifyUserAsync(
            request.SenderUserId,
            "NotificationChanged",
            new { notification.Id, notification.Title, notification.Body },
            cancellationToken);
    }

    public Task RejectRequestAsync(Guid requestId, CancellationToken cancellationToken) =>
        ChangeRequestStatusAsync(requestId, FriendRequestStatus.Rejected, incoming: true, cancellationToken);

    public Task CancelRequestAsync(Guid requestId, CancellationToken cancellationToken) =>
        ChangeRequestStatusAsync(requestId, FriendRequestStatus.Cancelled, incoming: false, cancellationToken);

    public async Task RemoveFriendAsync(Guid friendUserId, CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var rows = await dbContext.Friendships
            .Where(item =>
                (item.UserId == userId && item.FriendUserId == friendUserId) ||
                (item.UserId == friendUserId && item.FriendUserId == userId))
            .ToArrayAsync(cancellationToken);
        if (rows.Length == 0)
        {
            throw new NotFoundException("The selected friendship was not found.");
        }

        dbContext.Friendships.RemoveRange(rows);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<FriendProfileResponse> GetFriendProfileAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var currentUserId = RequireCurrentUserId();
        if (userId != currentUserId)
        {
            var isFriend = await dbContext.Friendships
                .AsNoTracking()
                .AnyAsync(item => item.UserId == currentUserId && item.FriendUserId == userId, cancellationToken);
            if (!isFriend)
            {
                throw new NotFoundException("The requested friend profile was not found.");
            }
        }

        var profile = await (
                from user in dbContext.Users.AsNoTracking()
                join userProfile in dbContext.UserProfiles.AsNoTracking() on user.Id equals userProfile.UserId
                join city in dbContext.Cities.AsNoTracking() on userProfile.CityId equals (Guid?)city.Id into cities
                from city in cities.DefaultIfEmpty()
                where user.Id == userId && user.IsActive
                select new
                {
                    user.Id,
                    user.DisplayName,
                    userProfile.Bio,
                    HasAvatar = userProfile.AvatarStorageKey != null,
                    CityName = city == null ? null : city.Name
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested friend profile was not found.");
        var friendCount = await dbContext.Friendships.CountAsync(item => item.UserId == userId, cancellationToken);
        var completedTaskCount = await dbContext.TaskCompletions.CountAsync(item => item.UserId == userId, cancellationToken);
        var habitCount = await (
                from task in dbContext.Tasks.AsNoTracking()
                join recurrence in dbContext.RecurrenceTypes.AsNoTracking() on task.RecurrenceTypeId equals recurrence.Id
                where task.OwnerUserId == userId && recurrence.Code != "none"
                select task.Id)
            .CountAsync(cancellationToken);
        var streaks = await GetStreaksAsync([userId], cancellationToken);

        return new FriendProfileResponse(
            profile.Id,
            profile.DisplayName,
            profile.Bio,
            profile.HasAvatar ? $"/api/media/avatars/{profile.Id}" : null,
            profile.CityName,
            friendCount,
            completedTaskCount,
            habitCount,
            streaks.GetValueOrDefault(userId));
    }

    public async Task<IReadOnlyCollection<FriendRecommendationResponse>> GetRecommendationsAsync(
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var friendIds = await dbContext.Friendships
            .AsNoTracking()
            .Where(item => item.UserId == userId)
            .Select(item => item.FriendUserId)
            .ToArrayAsync(cancellationToken);
        if (friendIds.Length == 0)
        {
            return Array.Empty<FriendRecommendationResponse>();
        }

        var pendingUserIds = await dbContext.FriendRequests
            .AsNoTracking()
            .Where(item => item.Status == FriendRequestStatus.Pending &&
                (item.SenderUserId == userId || item.ReceiverUserId == userId))
            .Select(item => item.SenderUserId == userId ? item.ReceiverUserId : item.SenderUserId)
            .ToArrayAsync(cancellationToken);
        var candidateScores = await dbContext.Friendships
            .AsNoTracking()
            .Where(item => friendIds.Contains(item.UserId) &&
                item.FriendUserId != userId &&
                !friendIds.Contains(item.FriendUserId) &&
                !pendingUserIds.Contains(item.FriendUserId))
            .GroupBy(item => item.FriendUserId)
            .Select(group => new
            {
                UserId = group.Key,
                MutualFriendCount = group.Select(item => item.UserId).Distinct().Count()
            })
            .OrderByDescending(item => item.MutualFriendCount)
            .ThenBy(item => item.UserId)
            .Take(20)
            .ToArrayAsync(cancellationToken);
        var candidateIds = candidateScores.Select(item => item.UserId).ToArray();
        var candidates = await (
                from user in dbContext.Users.AsNoTracking()
                join profile in dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId
                where candidateIds.Contains(user.Id) && user.IsActive
                select new
                {
                    user.Id,
                    user.DisplayName,
                    HasAvatar = profile.AvatarStorageKey != null
                })
            .ToDictionaryAsync(item => item.Id, cancellationToken);
        var now = dateTimeProvider.UtcNow;
        var results = candidateScores
            .Where(item => candidates.ContainsKey(item.UserId))
            .Select(item =>
            {
                var candidate = candidates[item.UserId];
                return new FriendRecommendationResponse(
                    item.UserId,
                    candidate.DisplayName,
                    candidate.HasAvatar ? $"/api/media/avatars/{item.UserId}" : null,
                    item.MutualFriendCount,
                    $"Recommended because you have {item.MutualFriendCount} mutual friend{(item.MutualFriendCount == 1 ? string.Empty : "s")}.");
            })
            .ToArray();

        dbContext.RecommendationLogs.AddRange(results.Select(item => new RecommendationLog
        {
            UserId = userId,
            RecommendedUserId = item.UserId,
            MutualFriendCount = item.MutualFriendCount,
            Explanation = item.Explanation,
            CreatedAtUtc = now
        }));
        await dbContext.SaveChangesAsync(cancellationToken);
        return results;
    }

    private async Task<PagedResult<FriendRequestResponse>> GetRequestsAsync(
        PagedRequest request,
        bool incoming,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var query = BuildRequestQuery(
            currentUserId: userId,
            incoming: incoming,
            search: request.Search);

        var totalCount = await query.CountAsync(cancellationToken);
        var rows = await query
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArrayAsync(cancellationToken);
        var items = rows.Select(MapRequest).ToArray();
        return new PagedResult<FriendRequestResponse>(items, request.Page, request.PageSize, totalCount);
    }

    private async Task<FriendRequestResponse> GetRequestByIdAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        var row = await BuildRequestQuery(requestId: id)
            .SingleAsync(cancellationToken);
        return MapRequest(row);
    }

    private IQueryable<RequestProjection> BuildRequestQuery(
        Guid? requestId = null,
        Guid? currentUserId = null,
        bool incoming = true,
        string? search = null)
    {
        var query =
            from request in dbContext.FriendRequests.AsNoTracking()
            join sender in dbContext.Users.AsNoTracking() on request.SenderUserId equals sender.Id
            join senderProfile in dbContext.UserProfiles.AsNoTracking() on sender.Id equals senderProfile.UserId
            join receiver in dbContext.Users.AsNoTracking() on request.ReceiverUserId equals receiver.Id
            select new
            {
                RequestId = request.Id,
                request.SenderUserId,
                SenderDisplayName = sender.DisplayName,
                SenderHasAvatar = senderProfile.AvatarStorageKey != null,
                request.ReceiverUserId,
                ReceiverDisplayName = receiver.DisplayName,
                request.Status,
                request.CreatedAtUtc,
                request.RespondedAtUtc
            };

        if (requestId.HasValue)
        {
            query = query.Where(item => item.RequestId == requestId.Value);
        }

        if (currentUserId.HasValue)
        {
            var userId = currentUserId.Value;
            query = incoming
                ? query.Where(item => item.ReceiverUserId == userId)
                : query.Where(item => item.SenderUserId == userId);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var normalizedSearch = search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.SenderDisplayName, $"%{normalizedSearch}%") ||
                EF.Functions.Like(item.ReceiverDisplayName, $"%{normalizedSearch}%"));
        }

        return query
            .OrderByDescending(item => item.CreatedAtUtc)
            .Select(item => new RequestProjection(
                item.RequestId,
                item.SenderUserId,
                item.SenderDisplayName,
                item.SenderHasAvatar,
                item.ReceiverUserId,
                item.ReceiverDisplayName,
                item.Status,
                item.CreatedAtUtc,
                item.RespondedAtUtc));
    }

    private async Task ChangeRequestStatusAsync(
        Guid requestId,
        FriendRequestStatus status,
        bool incoming,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var request = await dbContext.FriendRequests
            .SingleOrDefaultAsync(item =>
                item.Id == requestId &&
                item.Status == FriendRequestStatus.Pending &&
                (incoming ? item.ReceiverUserId == userId : item.SenderUserId == userId),
                cancellationToken)
            ?? throw new NotFoundException("The pending friend request was not found.");
        request.Status = status;
        request.RespondedAtUtc = dateTimeProvider.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<Dictionary<Guid, int>> GetStreaksAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, int>();
        }

        var dates = await dbContext.TaskCompletions
            .AsNoTracking()
            .Where(item => userIds.Contains(item.UserId))
            .Select(item => new { item.UserId, item.OccurrenceDate })
            .ToArrayAsync(cancellationToken);
        var today = DateOnly.FromDateTime(dateTimeProvider.UtcNow);
        return dates
            .GroupBy(item => item.UserId)
            .ToDictionary(
                group => group.Key,
                group => CalculateStreak(group.Select(item => item.OccurrenceDate), today));
    }

    private static int CalculateStreak(IEnumerable<DateOnly> completionDates, DateOnly today)
    {
        var dates = completionDates.Distinct().ToHashSet();
        var cursor = dates.Contains(today) ? today : today.AddDays(-1);
        var streak = 0;
        while (dates.Contains(cursor))
        {
            streak++;
            cursor = cursor.AddDays(-1);
        }

        return streak;
    }

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access friends.");

    private static FriendRequestResponse MapRequest(RequestProjection item) =>
        new(
            item.RequestId,
            item.SenderUserId,
            item.SenderDisplayName,
            item.SenderHasAvatar ? $"/api/media/avatars/{item.SenderUserId}" : null,
            item.ReceiverUserId,
            item.ReceiverDisplayName,
            item.Status,
            item.CreatedAtUtc,
            item.RespondedAtUtc);

    private sealed record RequestProjection(
        Guid RequestId,
        Guid SenderUserId,
        string SenderDisplayName,
        bool SenderHasAvatar,
        Guid ReceiverUserId,
        string ReceiverDisplayName,
        FriendRequestStatus Status,
        DateTime CreatedAtUtc,
        DateTime? RespondedAtUtc);
}
