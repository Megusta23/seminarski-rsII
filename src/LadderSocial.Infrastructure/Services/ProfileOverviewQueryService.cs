using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class ProfileOverviewQueryService(
    ApplicationDbContext dbContext,
    IDateTimeProvider dateTimeProvider)
{
    internal async Task<ProfileOverviewData> GetAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var profile = await (
                from user in dbContext.Users.AsNoTracking()
                join userProfile in dbContext.UserProfiles.AsNoTracking()
                    on user.Id equals userProfile.UserId
                join city in dbContext.Cities.AsNoTracking()
                    on userProfile.CityId equals (Guid?)city.Id into cities
                from city in cities.DefaultIfEmpty()
                where user.Id == userId && user.IsActive
                select new
                {
                    user.Id,
                    user.DisplayName,
                    user.CreatedAtUtc,
                    userProfile.Bio,
                    HasAvatar = userProfile.AvatarStorageKey != null,
                    CityName = city == null ? null : city.Name
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested profile was not found.");

        var friendCount = await (
                from friendship in dbContext.Friendships.AsNoTracking()
                join friend in dbContext.Users.AsNoTracking()
                    on friendship.FriendUserId equals friend.Id
                where friendship.UserId == userId && friend.IsActive
                select friendship.Id)
            .CountAsync(cancellationToken);

        var completedTaskCount = await (
                from completion in dbContext.TaskCompletions.AsNoTracking()
                join task in dbContext.Tasks.AsNoTracking()
                    on completion.TaskItemId equals task.Id
                where completion.UserId == userId
                select completion.Id)
            .CountAsync(cancellationToken);

        var habitCount = await (
                from task in dbContext.Tasks.AsNoTracking()
                join recurrence in dbContext.RecurrenceTypes.AsNoTracking()
                    on task.RecurrenceTypeId equals recurrence.Id
                where task.OwnerUserId == userId &&
                    task.Status == TaskItemStatus.Active &&
                    recurrence.Code != "none"
                select task.Id)
            .CountAsync(cancellationToken);

        var visiblePostCount = await (
                from post in dbContext.Posts.AsNoTracking()
                join completion in dbContext.TaskCompletions.AsNoTracking()
                    on post.TaskCompletionId equals completion.Id
                join task in dbContext.Tasks.AsNoTracking()
                    on completion.TaskItemId equals task.Id
                where post.AuthorUserId == userId &&
                    post.IsVisible &&
                    task.ShareWithFriends
                select post.Id)
            .CountAsync(cancellationToken);

        var completionDates = await (
                from completion in dbContext.TaskCompletions.AsNoTracking()
                join task in dbContext.Tasks.AsNoTracking()
                    on completion.TaskItemId equals task.Id
                where completion.UserId == userId
                select completion.OccurrenceDate)
            .Distinct()
            .ToArrayAsync(cancellationToken);
        var today = DateOnly.FromDateTime(dateTimeProvider.UtcNow);
        var currentStreak = CalculateStreak(completionDates, today);

        var highlightedRows = await (
                from post in dbContext.Posts.AsNoTracking()
                join completion in dbContext.TaskCompletions.AsNoTracking()
                    on post.TaskCompletionId equals completion.Id
                join task in dbContext.Tasks.AsNoTracking()
                    on completion.TaskItemId equals task.Id
                join category in dbContext.TaskCategories.AsNoTracking()
                    on task.TaskCategoryId equals category.Id
                join proof in dbContext.TaskProofMedia.AsNoTracking()
                    on completion.Id equals proof.TaskCompletionId
                where post.AuthorUserId == userId &&
                    post.IsHighlighted &&
                    post.IsVisible &&
                    task.ShareWithFriends
                orderby post.HighlightedAtUtc descending,
                    completion.CompletedAtUtc descending,
                    post.Id descending
                select new
                {
                    PostId = post.Id,
                    TaskId = task.Id,
                    TaskTitle = task.Title,
                    post.Caption,
                    CategoryName = category.Name,
                    CategoryCode = category.Code,
                    ProofMediaId = proof.Id,
                    completion.CompletedAtUtc,
                    HighlightedAtUtc = post.HighlightedAtUtc ?? completion.CompletedAtUtc
                })
            .Take(6)
            .ToArrayAsync(cancellationToken);
        var highlightedPosts = highlightedRows
            .Select(item => new ProfileOverviewHighlightData(
                item.PostId,
                item.TaskId,
                item.TaskTitle,
                item.Caption,
                item.CategoryName,
                item.CategoryCode,
                item.ProofMediaId,
                item.CompletedAtUtc,
                item.HighlightedAtUtc))
            .ToArray();

        return new ProfileOverviewData(
            profile.Id,
            profile.DisplayName,
            profile.Bio,
            profile.HasAvatar ? $"/api/media/avatars/{profile.Id}" : null,
            profile.CityName,
            profile.CreatedAtUtc,
            visiblePostCount,
            friendCount,
            completedTaskCount,
            habitCount,
            currentStreak,
            highlightedPosts);
    }

    private static int CalculateStreak(
        IEnumerable<DateOnly> completionDates,
        DateOnly today)
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
}

internal sealed record ProfileOverviewData(
    Guid UserId,
    string DisplayName,
    string? Bio,
    string? AvatarUrl,
    string? CityName,
    DateTime MemberSinceUtc,
    int VisiblePostCount,
    int FriendCount,
    int CompletedTaskCount,
    int HabitCount,
    int CurrentStreak,
    IReadOnlyCollection<ProfileOverviewHighlightData> HighlightedPosts);

internal sealed record ProfileOverviewHighlightData(
    Guid PostId,
    Guid TaskId,
    string TaskTitle,
    string? Caption,
    string CategoryName,
    string CategoryCode,
    Guid ProofMediaId,
    DateTime CompletedAtUtc,
    DateTime HighlightedAtUtc);
