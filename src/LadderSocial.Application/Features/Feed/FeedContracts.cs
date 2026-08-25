using LadderSocial.Application.Common.Models;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Feed;

public sealed class FeedRequest : PagedRequest
{
    public DateOnly? Date { get; set; }
}

public sealed record FeedItemResponse(
    Guid Id,
    FeedActivityType ActivityType,
    DateTime ActivityAtUtc,
    DateOnly OccurrenceDate,
    Guid AuthorUserId,
    string AuthorDisplayName,
    string? AuthorAvatarUrl,
    Guid TaskId,
    string TaskTitle,
    string CategoryName,
    string CategoryCode,
    string RecurrenceName,
    string RecurrenceCode,
    DateTime? DueAtUtc,
    string? Caption,
    Guid? ProofMediaId,
    string? ProofUrl,
    bool HasBeenViewed,
    DateTime? ViewedAtUtc)
{
    public bool IsCompleted => ActivityType != FeedActivityType.Unfinished;
    public bool HasProof => ProofMediaId.HasValue;
}

public sealed record FriendProgressResponse(
    Guid UserId,
    string DisplayName,
    string? AvatarUrl,
    int CompletedToday,
    int ScheduledToday,
    int? Percentage,
    int CurrentStreak);

public sealed record FeedPageResponse(
    IReadOnlyCollection<FeedItemResponse> Items,
    int Page,
    int PageSize,
    int TotalCount,
    DateOnly Date,
    bool HasFriends,
    int FriendCount,
    IReadOnlyCollection<FriendProgressResponse> FriendProgress)
{
    public int TotalPages => TotalCount == 0
        ? 0
        : (int)Math.Ceiling(TotalCount / (double)PageSize);
}

public interface IFeedService
{
    Task<FeedPageResponse> GetFeedAsync(FeedRequest request, CancellationToken cancellationToken);

    Task<FeedItemResponse> GetPostAsync(Guid postId, CancellationToken cancellationToken);

    Task<FeedItemResponse> GetItemAsync(
        Guid itemId,
        FeedActivityType activityType,
        DateOnly? date,
        CancellationToken cancellationToken);

    Task MarkViewedAsync(Guid postId, bool requireProof, CancellationToken cancellationToken);
}
