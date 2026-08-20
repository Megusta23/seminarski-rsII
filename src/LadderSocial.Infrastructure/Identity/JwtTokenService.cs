using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Common.Security;
using LadderSocial.Application.Features.Auth;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace LadderSocial.Infrastructure.Identity;

public sealed class JwtTokenService(
    IOptions<JwtOptions> options,
    IDateTimeProvider dateTimeProvider) : IJwtTokenService
{
    private readonly JwtOptions _options = options.Value;

    public GeneratedAccessToken CreateAccessToken(
        Guid userId,
        string email,
        string displayName,
        string securityStamp,
        IReadOnlyCollection<string> roles)
    {
        var issuedAtUtc = dateTimeProvider.UtcNow;
        var expiresAtUtc = issuedAtUtc.AddMinutes(_options.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, userId.ToString()),
            new(ClaimTypes.NameIdentifier, userId.ToString()),
            new(JwtRegisteredClaimNames.Email, email),
            new(ClaimTypes.Email, email),
            new(ClaimTypes.Name, displayName),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(
                JwtRegisteredClaimNames.Iat,
                new DateTimeOffset(issuedAtUtc).ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture),
                ClaimValueTypes.Integer64),
            new(JwtClaimNames.SecurityStamp, securityStamp)
        };

        claims.AddRange(
            roles
                .Distinct(StringComparer.Ordinal)
                .OrderBy(role => role, StringComparer.Ordinal)
                .Select(role => new Claim(ClaimTypes.Role, role)));

        var signingCredentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.Key)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: claims,
            notBefore: issuedAtUtc,
            expires: expiresAtUtc,
            signingCredentials: signingCredentials);

        // JwtSecurityTokenHandler maps ClaimTypes.Role to the short "role"
        // claim by default. This API intentionally disables inbound mapping and
        // uses ClaimTypes.Role as RoleClaimType, so preserving the original claim
        // names is required for [Authorize(Roles = ...)] to work reliably.
        var tokenHandler = new JwtSecurityTokenHandler();
        tokenHandler.OutboundClaimTypeMap.Clear();

        return new GeneratedAccessToken(
            tokenHandler.WriteToken(token),
            expiresAtUtc);
    }

    public GeneratedRefreshToken CreateRefreshToken()
    {
        var plainTextToken = WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(64));
        var expiresAtUtc = dateTimeProvider.UtcNow.AddDays(_options.RefreshTokenDays);

        return new GeneratedRefreshToken(
            plainTextToken,
            HashRefreshToken(plainTextToken),
            expiresAtUtc);
    }

    public string HashRefreshToken(string plainTextToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(plainTextToken);

        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(plainTextToken));
        return Convert.ToHexString(hash);
    }
}
