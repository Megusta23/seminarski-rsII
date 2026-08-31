using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Domain.Constants;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class ProfileOverviewQueryService(
    ApplicationDbContext dbContext,
    IDateTimeProvider dateTimeProvider,
    ICompletionStatisticsService completionStatisticsService)
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

        var completedTaskCount = await completionStatisticsService
            .GetTotalCompletionCountAsync(userId, cancellationToken);

        var habitCount = await (
                from task in dbContext.Tasks.AsNoTracking()
                join recurrence in dbContext.RecurrenceTypes.AsNoTracking()
                    on task.RecurrenceTypeId equals recurrence.Id
                where task.OwnerUserId == userId &&
                    task.Status == TaskItemStatus.Active &&
                    (recurrence.Code == RecurrenceCodes.Daily ||
                     recurrence.Code == RecurrenceCodes.Weekly ||
                     recurrence.Code == RecurrenceCodes.Monthly)
                select task.Id)
            .CountAsync(cancellationToken);

        // Social visibility intentionally keeps the normal Tasks query filter:
        // deleted tasks disappear from feed/profile media, while their historical
        // completions remain in the centralized statistics above.
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

        var businessDate = DateOnly.FromDateTime(dateTimeProvider.UtcNow);
        var currentStreak = await completionStatisticsService.GetCurrentStreakAsync(
            userId,
            businessDate,
            cancellationToken);

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
