using LadderSocial.Application.Common.Models;

namespace LadderSocial.Application.Features.Feed;

public sealed record FeedPostResponse(
    Guid Id,
    Guid AuthorUserId,
    string AuthorDisplayName,
    string? AuthorAvatarUrl,
    Guid TaskId,
    string TaskTitle,
    string CategoryName,
    string? Caption,
    DateTime CompletedAtUtc,
    Guid? ProofMediaId,
    string? ProofUrl,
    bool HasBeenViewed);

public interface IFeedService
{
    Task<PagedResult<FeedPostResponse>> GetFeedAsync(PagedRequest request, CancellationToken cancellationToken);
    Task<FeedPostResponse> GetPostAsync(Guid postId, CancellationToken cancellationToken);
    Task MarkViewedAsync(Guid postId, CancellationToken cancellationToken);
}
