using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Leaderboard;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class LeaderboardService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    ICompletionStatisticsService completionStatisticsService) : ILeaderboardService
{
    public Task<LeaderboardResponse> GetDailyAsync(
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        var selected = date ?? DateOnly.FromDateTime(dateTimeProvider.UtcNow);
        return GetAsync(selected, selected, cancellationToken);
    }

    public Task<LeaderboardResponse> GetWeeklyAsync(
        DateOnly? weekContaining,
        CancellationToken cancellationToken)
    {
        var selected = weekContaining ?? DateOnly.FromDateTime(dateTimeProvider.UtcNow);
        var daysFromMonday = ((int)selected.DayOfWeek + 6) % 7;
        var monday = selected.AddDays(-daysFromMonday);
        return GetAsync(monday, monday.AddDays(6), cancellationToken);
    }

    private async Task<LeaderboardResponse> GetAsync(
        DateOnly fromDate,
        DateOnly toDate,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedException("Authentication is required to access the leaderboard.");
        var friendIds = await dbContext.Friendships
            .AsNoTracking()
            .Where(item => item.UserId == userId)
            .Select(item => item.FriendUserId)
            .ToArrayAsync(cancellationToken);
        var candidateIds = friendIds.Append(userId).Distinct().ToArray();
        var profiles = await (
                from user in dbContext.Users.AsNoTracking()
                join profile in dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId
                where candidateIds.Contains(user.Id) && user.IsActive
                select new
                {
                    user.Id,
                    user.DisplayName,
                    HasAvatar = profile.AvatarStorageKey != null
                })
            .ToArrayAsync(cancellationToken);
        var scores = await completionStatisticsService.GetScoresAsync(
            candidateIds,
            fromDate,
            toDate,
            cancellationToken);
        var ordered = profiles
            .Select(profile => new
            {
                profile.Id,
                profile.DisplayName,
                profile.HasAvatar,
                Score = scores.GetValueOrDefault(profile.Id)
            })
            .OrderByDescending(item => item.Score)
            .ThenBy(item => item.DisplayName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(item => item.Id)
            .ToArray();
        var entries = ordered
            .Select((item, index) => new LeaderboardEntryResponse(
                index + 1,
                item.Id,
                item.DisplayName,
                item.HasAvatar ? $"/api/media/avatars/{item.Id}" : null,
                item.Score,
                item.Id == userId))
            .ToArray();

        return new LeaderboardResponse(
            fromDate,
            toDate,
            entries,
            entries.SingleOrDefault(item => item.UserId == userId));
    }
}
