namespace LadderSocial.Application.Features.Auth;

public sealed record GeneratedAccessToken(
    string Token,
    DateTime ExpiresAtUtc);

public sealed record GeneratedRefreshToken(
    string PlainTextToken,
    string TokenHash,
    DateTime ExpiresAtUtc);

public interface IJwtTokenService
{
    GeneratedAccessToken CreateAccessToken(
        Guid userId,
        string email,
        string displayName,
        string securityStamp,
        IReadOnlyCollection<string> roles);

    GeneratedRefreshToken CreateRefreshToken();

    string HashRefreshToken(string plainTextToken);
}
