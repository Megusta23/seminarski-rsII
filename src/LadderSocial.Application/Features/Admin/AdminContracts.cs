using LadderSocial.Application.Common.Models;

namespace LadderSocial.Application.Features.Admin;

public sealed record DashboardMetricResponse(
    string Label,
    int Value,
    string? SupportingText = null);

public sealed record AdminDashboardResponse(
    DateTime GeneratedAtUtc,
    int TotalUsers,
    int ActiveUsers,
    int TasksCreated,
    int TasksCompletedToday,
    int SharedPosts,
    int FriendRequests,
    int Messages,
    IReadOnlyCollection<AdminTopUserResponse> TopUsers);

public sealed record AdminTopUserResponse(
    Guid UserId,
    string DisplayName,
    int CompletedTaskCount);

public sealed class AdminUserListRequest : PagedRequest
{
    public bool? IsActive { get; set; }
    public Guid? CityId { get; set; }
}

public sealed record AdminUserListItemResponse(
    Guid Id,
    string DisplayName,
    string Email,
    bool IsActive,
    string? CityName,
    DateTime CreatedAtUtc,
    int FriendCount,
    int CompletedTaskCount,
    string? AvatarUrl);

public sealed record AdminUserDetailResponse(
    Guid Id,
    string DisplayName,
    string Email,
    bool IsActive,
    string FirstName,
    string LastName,
    string? Bio,
    string? CityName,
    DateOnly? DateOfBirth,
    DateTime CreatedAtUtc,
    int FriendCount,
    int TaskCount,
    int CompletedTaskCount,
    int PostCount,
    int MessageCount,
    string? AvatarUrl,
    IReadOnlyCollection<string> Roles);

public sealed record SetUserActiveRequest(bool IsActive);

public sealed class AdminPostListRequest : PagedRequest
{
    public bool? IsVisible { get; set; }
}

public sealed record AdminPostListItemResponse(
    Guid Id,
    Guid AuthorUserId,
    string AuthorDisplayName,
    string TaskTitle,
    string? Caption,
    bool IsVisible,
    DateTime CreatedAtUtc);

public sealed record SetPostVisibilityRequest(bool IsVisible);

public interface IAdminService
{
    Task<AdminDashboardResponse> GetDashboardAsync(CancellationToken cancellationToken);
    Task<PagedResult<AdminUserListItemResponse>> GetUsersAsync(AdminUserListRequest request, CancellationToken cancellationToken);
    Task<AdminUserDetailResponse> GetUserAsync(Guid id, CancellationToken cancellationToken);
    Task SetUserActiveAsync(Guid id, bool isActive, CancellationToken cancellationToken);
    Task<PagedResult<AdminPostListItemResponse>> GetPostsAsync(AdminPostListRequest request, CancellationToken cancellationToken);
    Task SetPostVisibilityAsync(Guid id, bool isVisible, CancellationToken cancellationToken);
}
