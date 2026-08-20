namespace LadderSocial.Application.Features.Leaderboard;

public sealed record LeaderboardEntryResponse(
    int Position,
    Guid UserId,
    string DisplayName,
    string? AvatarUrl,
    int Score,
    bool IsCurrentUser);

public sealed record LeaderboardResponse(
    DateOnly FromDate,
    DateOnly ToDate,
    IReadOnlyCollection<LeaderboardEntryResponse> Entries,
    LeaderboardEntryResponse? CurrentUser);

public interface ILeaderboardService
{
    Task<LeaderboardResponse> GetDailyAsync(DateOnly? date, CancellationToken cancellationToken);
    Task<LeaderboardResponse> GetWeeklyAsync(DateOnly? weekContaining, CancellationToken cancellationToken);
}
