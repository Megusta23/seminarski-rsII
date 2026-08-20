using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Common.Security;
using LadderSocial.Infrastructure.Identity;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class JwtTokenServiceTests
{
    private static readonly DateTime FixedUtcNow =
        new(2026, 8, 19, 10, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void CreateRefreshToken_ReturnsPlainTextAndOnlyDeterministicHash()
    {
        var service = CreateService();

        var generated = service.CreateRefreshToken();

        Assert.NotEmpty(generated.PlainTextToken);
        Assert.Equal(64, generated.TokenHash.Length);
        Assert.NotEqual(generated.PlainTextToken, generated.TokenHash);
        Assert.Equal(generated.TokenHash, service.HashRefreshToken(generated.PlainTextToken));
        Assert.Equal(FixedUtcNow.AddDays(14), generated.ExpiresAtUtc);
    }

    [Fact]
    public void CreateAccessToken_ValidatesIdentityRolesAndSecurityStamp()
    {
        var service = CreateService();
        var userId = Guid.NewGuid();

        var generated = service.CreateAccessToken(
            userId,
            "admin@laddersocial.local",
            "Ladder Admin",
            "security-stamp",
            [RoleNames.Admin]);

        var handler = new JwtSecurityTokenHandler
        {
            MapInboundClaims = false
        };
        var validationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = "LadderSocial.Api",
            ValidateAudience = true,
            ValidAudience = "LadderSocial.Clients",
            ValidateLifetime = false,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(new string('k', 64))),
            NameClaimType = ClaimTypes.Name,
            RoleClaimType = ClaimTypes.Role
        };

        var principal = handler.ValidateToken(
            generated.Token,
            validationParameters,
            out var validatedToken);
        var token = Assert.IsType<JwtSecurityToken>(validatedToken);

        Assert.Equal(FixedUtcNow.AddMinutes(30), generated.ExpiresAtUtc);
        Assert.Equal(userId.ToString(), principal.FindFirstValue(ClaimTypes.NameIdentifier));
        Assert.Equal("Ladder Admin", principal.Identity?.Name);
        Assert.True(principal.IsInRole(RoleNames.Admin));
        Assert.Contains(token.Claims, claim =>
            claim.Type == JwtClaimNames.SecurityStamp && claim.Value == "security-stamp");
    }

    private static JwtTokenService CreateService()
    {
        var options = Options.Create(new JwtOptions
        {
            Key = new string('k', 64),
            Issuer = "LadderSocial.Api",
            Audience = "LadderSocial.Clients",
            AccessTokenMinutes = 30,
            RefreshTokenDays = 14
        });

        return new JwtTokenService(options, new FixedDateTimeProvider(FixedUtcNow));
    }

    private sealed class FixedDateTimeProvider(DateTime utcNow) : IDateTimeProvider
    {
        public DateTime UtcNow { get; } = utcNow;
    }
}
