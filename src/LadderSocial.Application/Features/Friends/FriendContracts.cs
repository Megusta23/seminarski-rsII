using LadderSocial.Application.Common.Models;

namespace LadderSocial.Application.Features.Friends;

public sealed record FriendSummaryResponse(
    Guid UserId,
    string DisplayName,
    string? AvatarUrl,
    int CompletedTaskCount);

public sealed record FriendRecommendationResponse(
    Guid UserId,
    string DisplayName,
    int MutualFriendCount,
    string Explanation);

public interface IFriendService
{
    Task<PagedResult<FriendSummaryResponse>> GetFriendsAsync(
        PagedRequest request,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<FriendRecommendationResponse>> GetRecommendationsAsync(
        CancellationToken cancellationToken);
}
