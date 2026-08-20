using System.ComponentModel.DataAnnotations;

namespace LadderSocial.Application.Features.Auth;

public sealed record RegisterRequest(
    [Required, EmailAddress, StringLength(256)] string Email,
    [Required, StringLength(128, MinimumLength = 10)] string Password,
    [Required, StringLength(128, MinimumLength = 10)] string ConfirmPassword,
    [Required, StringLength(100)] string FirstName,
    [Required, StringLength(100)] string LastName);

public sealed record LoginRequest(
    [Required, EmailAddress, StringLength(256)] string Email,
    [Required, StringLength(128)] string Password);

public sealed record RefreshTokenRequest(
    [Required, StringLength(512, MinimumLength = 40)] string RefreshToken);

public sealed record LogoutRequest(
    [Required, StringLength(512, MinimumLength = 40)] string RefreshToken);

public sealed record AuthResponse(
    string AccessToken,
    string RefreshToken,
    DateTime AccessTokenExpiresAtUtc,
    DateTime RefreshTokenExpiresAtUtc,
    Guid UserId,
    string Email,
    string DisplayName,
    IReadOnlyCollection<string> Roles);

public interface IAuthService
{
    Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken);
    Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken);
    Task<AuthResponse> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken);
    Task LogoutAsync(LogoutRequest request, CancellationToken cancellationToken);
}
