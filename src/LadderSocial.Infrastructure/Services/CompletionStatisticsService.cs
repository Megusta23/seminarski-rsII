using LadderSocial.Application.Features.Tasks;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class CompletionStatisticsService(ApplicationDbContext dbContext)
    : ICompletionStatisticsService
{
    public async Task<int> GetTotalCompletionCountAsync(
        Guid userId,
        CancellationToken cancellationToken) =>
        await dbContext.TaskCompletions
            .AsNoTracking()
            .CountAsync(item => item.UserId == userId, cancellationToken);

    public async Task<IReadOnlyDictionary<Guid, int>> GetTotalCompletionCountsAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        var ids = userIds.Distinct().ToArray();
        if (ids.Length == 0)
        {
            return new Dictionary<Guid, int>();
        }

        return await dbContext.TaskCompletions
            .AsNoTracking()
            .Where(item => ids.Contains(item.UserId))
            .GroupBy(item => item.UserId)
            .Select(group => new { UserId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.UserId, item => item.Count, cancellationToken);
    }

    public async Task<int> GetCurrentStreakAsync(
        Guid userId,
        DateOnly businessDate,
        CancellationToken cancellationToken)
    {
        var values = await GetCurrentStreaksAsync(
            [userId],
            businessDate,
            cancellationToken);
        return values.GetValueOrDefault(userId);
    }

    public async Task<IReadOnlyDictionary<Guid, int>> GetCurrentStreaksAsync(
        IReadOnlyCollection<Guid> userIds,
        DateOnly businessDate,
        CancellationToken cancellationToken)
    {
        var ids = userIds.Distinct().ToArray();
        if (ids.Length == 0)
        {
            return new Dictionary<Guid, int>();
        }

        // Completion history is intentionally queried without joining Tasks. A task's
        // later soft deletion removes it from active/social views, but does not erase
        // the historical fact that the occurrence was completed.
        var dates = await dbContext.TaskCompletions
            .AsNoTracking()
            .Where(item => ids.Contains(item.UserId) && item.OccurrenceDate <= businessDate)
            .Select(item => new { item.UserId, item.OccurrenceDate })
            .Distinct()
            .ToArrayAsync(cancellationToken);

        return dates
            .GroupBy(item => item.UserId)
            .ToDictionary(
                group => group.Key,
                group => CalculateCurrentStreak(
                    group.Select(item => item.OccurrenceDate),
                    businessDate));
    }

    public async Task<int> GetCompletionCountAsync(
        DateOnly fromDate,
        DateOnly toDate,
        CancellationToken cancellationToken) =>
        await dbContext.TaskCompletions
            .AsNoTracking()
            .CountAsync(
                item => item.OccurrenceDate >= fromDate && item.OccurrenceDate <= toDate,
                cancellationToken);

    public async Task<IReadOnlyDictionary<Guid, int>> GetScoresAsync(
        IReadOnlyCollection<Guid> userIds,
        DateOnly fromDate,
        DateOnly toDate,
        CancellationToken cancellationToken)
    {
        var ids = userIds.Distinct().ToArray();
        if (ids.Length == 0)
        {
            return new Dictionary<Guid, int>();
        }

        return await dbContext.TaskCompletions
            .AsNoTracking()
            .Where(item => ids.Contains(item.UserId) &&
                item.OccurrenceDate >= fromDate &&
                item.OccurrenceDate <= toDate)
            .GroupBy(item => item.UserId)
            .Select(group => new
            {
                UserId = group.Key,
                Score = group.Sum(item => item.ScorePoints)
            })
            .ToDictionaryAsync(item => item.UserId, item => item.Score, cancellationToken);
    }

    public async Task<IReadOnlyCollection<UserCompletionAggregate>> GetTopUsersAsync(
        DateOnly? fromDate,
        DateOnly? toDate,
        int take,
        CancellationToken cancellationToken)
    {
        if (take <= 0)
        {
            return Array.Empty<UserCompletionAggregate>();
        }

        var query = dbContext.TaskCompletions.AsNoTracking().AsQueryable();
        if (fromDate.HasValue)
        {
            query = query.Where(item => item.OccurrenceDate >= fromDate.Value);
        }

        if (toDate.HasValue)
        {
            query = query.Where(item => item.OccurrenceDate <= toDate.Value);
        }

        // Project to an anonymous SQL-translatable shape first, then map to the
        // application record after materialization.
        var rows = await query
            .GroupBy(item => item.UserId)
            .Select(group => new
            {
                UserId = group.Key,
                CompletionCount = group.Count(),
                Score = group.Sum(item => item.ScorePoints)
            })
            .OrderByDescending(item => item.Score)
            .ThenByDescending(item => item.CompletionCount)
            .ThenBy(item => item.UserId)
            .Take(take)
            .ToArrayAsync(cancellationToken);

        return rows
            .Select(item => new UserCompletionAggregate(
                item.UserId,
                item.CompletionCount,
                item.Score))
            .ToArray();
    }

    public static int CalculateCurrentStreak(
        IEnumerable<DateOnly> completionDates,
        DateOnly businessDate)
    {
        var dates = completionDates
            .Where(item => item <= businessDate)
            .Distinct()
            .ToHashSet();
        var cursor = dates.Contains(businessDate)
            ? businessDate
            : businessDate.AddDays(-1);
        var streak = 0;

        while (dates.Contains(cursor))
        {
            streak++;
            cursor = cursor.AddDays(-1);
        }

        return streak;
    }
}
