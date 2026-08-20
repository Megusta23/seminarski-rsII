using LadderSocial.Application.Common.Models;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Friends;

public sealed class UserSearchRequest : PagedRequest
{
    public bool ExcludeExistingRelationships { get; set; } = true;
}

public sealed record FriendSummaryResponse(
    Guid UserId,
    string DisplayName,
    string? AvatarUrl,
    int CompletedTaskCount,
    int CurrentStreak);

public sealed record UserSearchResponse(
    Guid UserId,
    string DisplayName,
    string Email,
    string? AvatarUrl,
    bool IsFriend,
    bool HasOutgoingPendingRequest,
    bool HasIncomingPendingRequest);

public sealed record FriendRequestResponse(
    Guid Id,
    Guid SenderUserId,
    string SenderDisplayName,
    string? SenderAvatarUrl,
    Guid ReceiverUserId,
    string ReceiverDisplayName,
    FriendRequestStatus Status,
    DateTime CreatedAtUtc,
    DateTime? RespondedAtUtc);

public sealed record FriendProfileResponse(
    Guid UserId,
    string DisplayName,
    string? Bio,
    string? AvatarUrl,
    string? CityName,
    int FriendCount,
    int CompletedTaskCount,
    int HabitCount,
    int CurrentStreak);

public sealed record FriendRecommendationResponse(
    Guid UserId,
    string DisplayName,
    string? AvatarUrl,
    int MutualFriendCount,
    string Explanation);

public interface IFriendService
{
    Task<PagedResult<FriendSummaryResponse>> GetFriendsAsync(PagedRequest request, CancellationToken cancellationToken);
    Task<PagedResult<UserSearchResponse>> SearchUsersAsync(UserSearchRequest request, CancellationToken cancellationToken);
    Task<PagedResult<FriendRequestResponse>> GetIncomingRequestsAsync(PagedRequest request, CancellationToken cancellationToken);
    Task<PagedResult<FriendRequestResponse>> GetOutgoingRequestsAsync(PagedRequest request, CancellationToken cancellationToken);
    Task<FriendRequestResponse> SendRequestAsync(Guid receiverUserId, CancellationToken cancellationToken);
    Task AcceptRequestAsync(Guid requestId, CancellationToken cancellationToken);
    Task RejectRequestAsync(Guid requestId, CancellationToken cancellationToken);
    Task CancelRequestAsync(Guid requestId, CancellationToken cancellationToken);
    Task RemoveFriendAsync(Guid friendUserId, CancellationToken cancellationToken);
    Task<FriendProfileResponse> GetFriendProfileAsync(Guid userId, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<FriendRecommendationResponse>> GetRecommendationsAsync(CancellationToken cancellationToken);
}
