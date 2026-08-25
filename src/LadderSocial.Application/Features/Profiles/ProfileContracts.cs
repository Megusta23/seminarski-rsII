using System.ComponentModel.DataAnnotations;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Models;

namespace LadderSocial.Application.Features.Profiles;

public sealed record CurrentProfileResponse(
    Guid UserId,
    string Email,
    string DisplayName,
    string FirstName,
    string LastName,
    string? Bio,
    string? AvatarUrl,
    Guid? CityId,
    string? CityName,
    DateOnly? DateOfBirth,
    IReadOnlyCollection<string> Roles);

public sealed record UpdateProfileRequest(
    [Required, StringLength(100)] string FirstName,
    [Required, StringLength(100)] string LastName,
    [StringLength(500)] string? Bio,
    Guid? CityId,
    DateOnly? DateOfBirth);

public sealed record ProfileHighlightCandidateResponse(
    Guid PostId,
    Guid TaskId,
    string TaskTitle,
    string? Caption,
    string CategoryName,
    string CategoryCode,
    Guid ProofMediaId,
    string ProofUrl,
    DateTime CompletedAtUtc,
    bool IsHighlighted,
    DateTime? HighlightedAtUtc);

public interface IProfileService
{
    Task<CurrentProfileResponse> GetCurrentAsync(CancellationToken cancellationToken);
    Task<CurrentProfileResponse> UpdateCurrentAsync(UpdateProfileRequest request, CancellationToken cancellationToken);
    Task<CurrentProfileResponse> UpdateAvatarAsync(UploadPayload upload, CancellationToken cancellationToken);
    Task<CurrentProfileResponse> RemoveAvatarAsync(CancellationToken cancellationToken);
    Task<PagedResult<ProfileHighlightCandidateResponse>> GetHighlightCandidatesAsync(
        PagedRequest request,
        CancellationToken cancellationToken);
    Task HighlightPostAsync(Guid postId, CancellationToken cancellationToken);
    Task RemoveHighlightAsync(Guid postId, CancellationToken cancellationToken);
}
