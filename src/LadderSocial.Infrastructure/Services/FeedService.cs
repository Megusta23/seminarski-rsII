using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Feed;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Domain.Entities;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class FeedService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IRecurrenceRuleService recurrenceRuleService,
    ICompletionStatisticsService completionStatisticsService) : IFeedService
{
    public async Task<FeedPageResponse> GetFeedAsync(
        FeedRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var selectedDate = ValidateDate(request.Date);

        var search = string.IsNullOrWhiteSpace(request.Search) ? null : request.Search.Trim();
        var completedQuery = BuildCompletedFeedQuery(userId, selectedDate, search: search);
        var unfinishedQuery = BuildUnfinishedFeedQuery(userId, selectedDate, search: search);

        var completedCount = await completedQuery.CountAsync(cancellationToken);
        var unfinishedCount = await unfinishedQuery.CountAsync(cancellationToken);
        var totalCount = completedCount + unfinishedCount;
        var requestedSkip = ((long)request.Page - 1) * request.PageSize;
        var skip = requestedSkip >= totalCount ? totalCount : (int)requestedSkip;
        var takeThroughPage = (int)Math.Min((long)skip + request.PageSize, int.MaxValue);

        // The top K rows from the merged feed can only come from the top K rows
        // of each independently ordered source. This keeps SQL simple and avoids
        // provider-specific UNION translation problems while preserving pagination.
        FeedQueryRow[] rows;
        if (skip >= totalCount)
        {
            rows = Array.Empty<FeedQueryRow>();
        }
        else
        {
            var completedRows = await completedQuery
                .Take(takeThroughPage)
                .ToArrayAsync(cancellationToken);
            var unfinishedRows = await unfinishedQuery
                .Take(takeThroughPage)
                .ToArrayAsync(cancellationToken);
            rows = completedRows
                .Concat(unfinishedRows)
                .OrderByDescending(item => item.ActivityAtUtc)
                .ThenByDescending(item => item.Id)
                .Skip(skip)
                .Take(request.PageSize)
                .ToArray();
        }
        var progress = await GetFriendProgressAsync(userId, selectedDate, cancellationToken);

        return new FeedPageResponse(
            rows.Select(MapItem).ToArray(),
            request.Page,
            request.PageSize,
            totalCount,
            selectedDate,
            progress.Count > 0,
            progress.Count,
            progress);
    }

    public async Task<FeedItemResponse> GetPostAsync(
        Guid postId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var row = await BuildCompletedFeedQuery(userId, postId: postId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested feed item was not found.");

        return MapItem(row);
    }

    public async Task<FeedItemResponse> GetItemAsync(
        Guid itemId,
        FeedActivityType activityType,
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        if (!Enum.IsDefined(typeof(FeedActivityType), activityType))
        {
            throw new ValidationException(
                "Feed validation failed.",
                new Dictionary<string, string[]>
                {
                    ["activityType"] = ["Select a supported feed activity type."]
                });
        }

        FeedQueryRow? row;

        if (activityType == FeedActivityType.Unfinished)
        {
            var selectedDate = ValidateDate(date);
            row = await BuildUnfinishedFeedQuery(userId, selectedDate, itemId)
                .SingleOrDefaultAsync(cancellationToken);
        }
        else
        {
            row = await BuildCompletedFeedQuery(userId, postId: itemId)
                .SingleOrDefaultAsync(cancellationToken);
            if (row is not null && row.ActivityType != activityType)
            {
                row = null;
            }
        }

        return row is null
            ? throw new NotFoundException("The requested feed item was not found.")
            : MapItem(row);
    }

    public async Task MarkViewedAsync(
        Guid postId,
        bool requireProof,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var visiblePost = await BuildCompletedFeedQuery(userId, postId: postId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested feed item was not found.");

        if (!visiblePost.ProofMediaId.HasValue)
        {
            if (requireProof)
            {
                throw new NotFoundException("The requested feed item does not contain a proof image.");
            }

            // Keep the legacy /view operation idempotent for posts without proof.
            return;
        }

        var existing = await dbContext.PostViews
            .SingleOrDefaultAsync(
                item => item.PostId == postId && item.ViewerUserId == userId,
                cancellationToken);
        if (existing is not null)
        {
            return;
        }

        var postView = new PostView
        {
            PostId = postId,
            ViewerUserId = userId,
            ViewedAtUtc = dateTimeProvider.UtcNow
        };
        dbContext.PostViews.Add(postView);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            dbContext.Entry(postView).State = EntityState.Detached;
            var concurrentInsertSucceeded = await dbContext.PostViews
                .AsNoTracking()
                .AnyAsync(
                    item => item.PostId == postId && item.ViewerUserId == userId,
                    cancellationToken);
            if (!concurrentInsertSucceeded)
            {
                throw;
            }
        }
    }

    private IQueryable<FeedQueryRow> BuildCompletedFeedQuery(
        Guid userId,
        DateOnly? date = null,
        Guid? postId = null,
        string? search = null)
    {
        var query =
            from friendship in dbContext.Friendships.AsNoTracking()
            join author in dbContext.Users.AsNoTracking()
                on friendship.FriendUserId equals author.Id
            join profile in dbContext.UserProfiles.AsNoTracking()
                on author.Id equals profile.UserId
            join post in dbContext.Posts.AsNoTracking()
                on author.Id equals post.AuthorUserId
            join completion in dbContext.TaskCompletions.AsNoTracking()
                on post.TaskCompletionId equals completion.Id
            join task in dbContext.Tasks.AsNoTracking()
                on completion.TaskItemId equals task.Id
            join category in dbContext.TaskCategories.AsNoTracking()
                on task.TaskCategoryId equals category.Id
            join recurrence in dbContext.RecurrenceTypes.AsNoTracking()
                on task.RecurrenceTypeId equals recurrence.Id
            join proof in dbContext.TaskProofMedia.AsNoTracking()
                on completion.Id equals proof.TaskCompletionId into proofGroup
            from proof in proofGroup.DefaultIfEmpty()
            join view in dbContext.PostViews.AsNoTracking().Where(item => item.ViewerUserId == userId)
                on post.Id equals view.PostId into viewGroup
            from view in viewGroup.DefaultIfEmpty()
            where friendship.UserId == userId &&
                author.IsActive &&
                post.IsVisible &&
                task.ShareWithFriends &&
                completion.UserId == author.Id &&
                (!date.HasValue || completion.OccurrenceDate == date.Value) &&
                (!postId.HasValue || post.Id == postId.Value) &&
                (search == null ||
                    EF.Functions.Like(task.Title, $"%{search}%") ||
                    EF.Functions.Like(author.DisplayName, $"%{search}%") ||
                    (post.Caption != null && EF.Functions.Like(post.Caption, $"%{search}%")))
            orderby completion.CompletedAtUtc descending, post.Id descending
            select new FeedQueryRow
            {
                Id = post.Id,
                ActivityType = proof == null
                    ? FeedActivityType.CompletedWithoutProof
                    : FeedActivityType.CompletedWithProof,
                ActivityAtUtc = completion.CompletedAtUtc,
                OccurrenceDate = completion.OccurrenceDate,
                AuthorUserId = author.Id,
                AuthorDisplayName = author.DisplayName,
                HasAvatar = profile.AvatarStorageKey != null,
                TaskId = task.Id,
                TaskTitle = task.Title,
                CategoryName = category.Name,
                CategoryCode = category.Code,
                RecurrenceName = recurrence.Name,
                RecurrenceCode = recurrence.Code,
                DueAtUtc = task.DueAtUtc,
                Caption = post.Caption,
                ProofMediaId = proof == null ? null : proof.Id,
                ViewedAtUtc = view == null ? null : view.ViewedAtUtc
            };

        return query;
    }

    private IQueryable<FeedQueryRow> BuildUnfinishedFeedQuery(
        Guid userId,
        DateOnly date,
        Guid? taskId = null,
        string? search = null)
    {
        var dateStart = DateTime.SpecifyKind(date.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc);
        var sharedActiveTasks = dbContext.Tasks
            .AsNoTracking()
            .Where(task => task.ShareWithFriends && task.Status == TaskItemStatus.Active);
        var scheduledTaskIds = recurrenceRuleService.GetScheduledTaskIds(
            sharedActiveTasks,
            date);

        return
            from friendship in dbContext.Friendships.AsNoTracking()
            join author in dbContext.Users.AsNoTracking()
                on friendship.FriendUserId equals author.Id
            join profile in dbContext.UserProfiles.AsNoTracking()
                on author.Id equals profile.UserId
            join task in dbContext.Tasks.AsNoTracking()
                on author.Id equals task.OwnerUserId
            join category in dbContext.TaskCategories.AsNoTracking()
                on task.TaskCategoryId equals category.Id
            join recurrence in dbContext.RecurrenceTypes.AsNoTracking()
                on task.RecurrenceTypeId equals recurrence.Id
            where friendship.UserId == userId &&
                author.IsActive &&
                scheduledTaskIds.Contains(task.Id) &&
                (!taskId.HasValue || task.Id == taskId.Value) &&
                !dbContext.TaskCompletions.Any(completion =>
                    completion.TaskItemId == task.Id &&
                    completion.UserId == author.Id &&
                    completion.OccurrenceDate == date) &&
                (search == null ||
                    EF.Functions.Like(task.Title, $"%{search}%") ||
                    EF.Functions.Like(author.DisplayName, $"%{search}%"))
            orderby task.DueAtUtc ?? dateStart descending, task.Id descending
            select new FeedQueryRow
            {
                Id = task.Id,
                ActivityType = FeedActivityType.Unfinished,
                ActivityAtUtc = task.DueAtUtc ?? dateStart,
                OccurrenceDate = date,
                AuthorUserId = author.Id,
                AuthorDisplayName = author.DisplayName,
                HasAvatar = profile.AvatarStorageKey != null,
                TaskId = task.Id,
                TaskTitle = task.Title,
                CategoryName = category.Name,
                CategoryCode = category.Code,
                RecurrenceName = recurrence.Name,
                RecurrenceCode = recurrence.Code,
                DueAtUtc = task.DueAtUtc,
                Caption = null,
                ProofMediaId = null,
                ViewedAtUtc = null
            };
    }

    private async Task<IReadOnlyCollection<FriendProgressResponse>> GetFriendProgressAsync(
        Guid userId,
        DateOnly date,
        CancellationToken cancellationToken)
    {
        var friends = await (
                from friendship in dbContext.Friendships.AsNoTracking()
                join friend in dbContext.Users.AsNoTracking()
                    on friendship.FriendUserId equals friend.Id
                join profile in dbContext.UserProfiles.AsNoTracking()
                    on friend.Id equals profile.UserId
                where friendship.UserId == userId && friend.IsActive
                orderby friend.DisplayName
                select new FriendRow
                {
                    UserId = friend.Id,
                    DisplayName = friend.DisplayName,
                    HasAvatar = profile.AvatarStorageKey != null
                })
            .ToArrayAsync(cancellationToken);

        if (friends.Length == 0)
        {
            return Array.Empty<FriendProgressResponse>();
        }

        var friendIds = friends.Select(item => item.UserId).ToArray();
        var eligibleTasks = dbContext.Tasks
            .AsNoTracking()
            .Where(task =>
                friendIds.Contains(task.OwnerUserId) &&
                task.ShareWithFriends &&
                task.Status != TaskItemStatus.Cancelled &&
                task.Status != TaskItemStatus.Archived);
        var scheduledTaskIds = recurrenceRuleService.GetScheduledTaskIds(
            eligibleTasks,
            date);
        var scheduledTasks = await eligibleTasks
            .Where(task => scheduledTaskIds.Contains(task.Id))
            .Select(task => new ScheduledTaskRow
            {
                UserId = task.OwnerUserId,
                TaskId = task.Id
            })
            .ToArrayAsync(cancellationToken);

        var scheduledIds = scheduledTasks
            .Select(item => item.TaskId)
            .Distinct()
            .ToArray();
        var completedPairs = scheduledIds.Length == 0
            ? Array.Empty<CompletedTaskRow>()
            : await dbContext.TaskCompletions
                .AsNoTracking()
                .Where(item =>
                    friendIds.Contains(item.UserId) &&
                    scheduledIds.Contains(item.TaskItemId) &&
                    item.OccurrenceDate == date)
                .Select(item => new CompletedTaskRow
                {
                    UserId = item.UserId,
                    TaskId = item.TaskItemId
                })
                .ToArrayAsync(cancellationToken);
        var completedKeys = completedPairs
            .Select(item => (item.UserId, item.TaskId))
            .ToHashSet();
        var tasksByFriend = scheduledTasks
            .GroupBy(item => item.UserId)
            .ToDictionary(
                group => group.Key,
                group => group.Select(item => item.TaskId).Distinct().ToArray());
        var businessDate = DateOnly.FromDateTime(dateTimeProvider.UtcNow);
        var streaks = await completionStatisticsService.GetCurrentStreaksAsync(
            friendIds,
            businessDate,
            cancellationToken);

        return friends
            .Select(friend =>
            {
                var taskIds = tasksByFriend.GetValueOrDefault(friend.UserId) ?? Array.Empty<Guid>();
                var completedCount = taskIds.Count(
                    taskId => completedKeys.Contains((friend.UserId, taskId)));
                var percentage = taskIds.Length == 0
                    ? (int?)null
                    : (int)Math.Round(
                        completedCount * 100d / taskIds.Length,
                        MidpointRounding.AwayFromZero);

                return new FriendProgressResponse(
                    friend.UserId,
                    friend.DisplayName,
                    friend.HasAvatar ? $"/api/media/avatars/{friend.UserId}" : null,
                    completedCount,
                    taskIds.Length,
                    percentage,
                    streaks.GetValueOrDefault(friend.UserId));
            })
            .OrderByDescending(item => item.Percentage ?? -1)
            .ThenBy(item => item.DisplayName)
            .ToArray();
    }

    private DateOnly ValidateDate(DateOnly? requestedDate) =>
        requestedDate ?? DateOnly.FromDateTime(dateTimeProvider.UtcNow);

    private static FeedItemResponse MapItem(FeedQueryRow item) =>
        new(
            item.Id,
            item.ActivityType,
            item.ActivityAtUtc,
            item.OccurrenceDate,
            item.AuthorUserId,
            item.AuthorDisplayName,
            item.HasAvatar ? $"/api/media/avatars/{item.AuthorUserId}" : null,
            item.TaskId,
            item.TaskTitle,
            item.CategoryName,
            item.CategoryCode,
            item.RecurrenceName,
            item.RecurrenceCode,
            item.DueAtUtc,
            item.Caption,
            item.ProofMediaId,
            item.ProofMediaId.HasValue ? $"/api/media/task-proofs/{item.ProofMediaId.Value}" : null,
            item.ProofMediaId.HasValue && item.ViewedAtUtc.HasValue,
            item.ViewedAtUtc);

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access the feed.");

    private sealed class FeedQueryRow
    {
        public Guid Id { get; init; }
        public FeedActivityType ActivityType { get; init; }
        public DateTime ActivityAtUtc { get; init; }
        public DateOnly OccurrenceDate { get; init; }
        public Guid AuthorUserId { get; init; }
        public string AuthorDisplayName { get; init; } = string.Empty;
        public bool HasAvatar { get; init; }
        public Guid TaskId { get; init; }
        public string TaskTitle { get; init; } = string.Empty;
        public string CategoryName { get; init; } = string.Empty;
        public string CategoryCode { get; init; } = string.Empty;
        public string RecurrenceName { get; init; } = string.Empty;
        public string RecurrenceCode { get; init; } = string.Empty;
        public DateTime? DueAtUtc { get; init; }
        public string? Caption { get; init; }
        public Guid? ProofMediaId { get; init; }
        public DateTime? ViewedAtUtc { get; init; }
    }

    private sealed class FriendRow
    {
        public Guid UserId { get; init; }
        public string DisplayName { get; init; } = string.Empty;
        public bool HasAvatar { get; init; }
    }

    private sealed class ScheduledTaskRow
    {
        public Guid UserId { get; init; }
        public Guid TaskId { get; init; }
    }

    private sealed class CompletedTaskRow
    {
        public Guid UserId { get; init; }
        public Guid TaskId { get; init; }
    }
}
