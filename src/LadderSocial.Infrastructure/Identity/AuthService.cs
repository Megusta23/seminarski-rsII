using System.Data;
using EmailAddressAttribute = System.ComponentModel.DataAnnotations.EmailAddressAttribute;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Security;
using LadderSocial.Application.Features.Auth;
using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace LadderSocial.Infrastructure.Identity;

public sealed class AuthService(
    UserManager<AppUser> userManager,
    ApplicationDbContext dbContext,
    IJwtTokenService jwtTokenService,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    ILogger<AuthService> logger) : IAuthService
{
    private static readonly EmailAddressAttribute EmailValidator = new();

    public async Task<AuthResponse> RegisterAsync(
        RegisterRequest request,
        CancellationToken cancellationToken)
    {
        ValidateRegisterRequest(request);

        var email = request.Email.Trim();
        var firstName = request.FirstName.Trim();
        var lastName = request.LastName.Trim();

        if (await userManager.FindByEmailAsync(email) is not null)
        {
            throw new ConflictException("An account with this email address already exists.");
        }

        AuthResponse? response = null;
        var strategy = dbContext.Database.CreateExecutionStrategy();

        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);

            if (await userManager.FindByEmailAsync(email) is not null)
            {
                throw new ConflictException("An account with this email address already exists.");
            }

            var user = new AppUser
            {
                Id = Guid.NewGuid(),
                Email = email,
                UserName = email,
                EmailConfirmed = true,
                DisplayName = BuildDisplayName(firstName, lastName),
                CreatedAtUtc = dateTimeProvider.UtcNow,
                IsActive = true,
                LockoutEnabled = true
            };

            var createResult = await userManager.CreateAsync(user, request.Password);
            ThrowIdentityValidationIfFailed(createResult);

            var roleResult = await userManager.AddToRoleAsync(user, RoleNames.User);
            EnsureIdentitySucceeded(roleResult, "assigning the default user role");

            dbContext.UserProfiles.Add(new UserProfile
            {
                UserId = user.Id,
                FirstName = firstName,
                LastName = lastName
            });

            response = await CreateTokenPairAsync(user, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        logger.LogInformation("Registered Ladder Social user {UserId}", response!.UserId);
        return response;
    }

    public async Task<AuthResponse> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken)
    {
        ValidateLoginRequest(request);

        var email = request.Email.Trim();
        var user = await userManager.FindByEmailAsync(email);

        if (user is null)
        {
            throw new UnauthorizedException("Invalid email or password.");
        }

        if (!user.IsActive)
        {
            throw new ForbiddenException("This account is inactive. Contact an administrator.");
        }

        if (await userManager.IsLockedOutAsync(user))
        {
            throw new ForbiddenException(
                "This account is temporarily locked because of repeated failed login attempts.");
        }

        if (!await userManager.CheckPasswordAsync(user, request.Password))
        {
            var failedResult = await userManager.AccessFailedAsync(user);
            EnsureIdentitySucceeded(failedResult, "recording a failed login attempt");

            if (await userManager.IsLockedOutAsync(user))
            {
                throw new ForbiddenException(
                    "This account is temporarily locked because of repeated failed login attempts.");
            }

            throw new UnauthorizedException("Invalid email or password.");
        }

        AuthResponse? response = null;
        var strategy = dbContext.Database.CreateExecutionStrategy();

        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);

            var currentUser = await userManager.FindByIdAsync(user.Id.ToString())
                ?? throw new UnauthorizedException("The account is no longer available.");

            if (currentUser.AccessFailedCount > 0)
            {
                var resetResult = await userManager.ResetAccessFailedCountAsync(currentUser);
                EnsureIdentitySucceeded(resetResult, "resetting failed login attempts");
            }

            response = await CreateTokenPairAsync(currentUser, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        logger.LogInformation("User {UserId} logged in", user.Id);
        return response!;
    }

    public async Task<AuthResponse> RefreshAsync(
        RefreshTokenRequest request,
        CancellationToken cancellationToken)
    {
        ValidateRefreshToken(request.RefreshToken, nameof(request.RefreshToken));

        var tokenHash = jwtTokenService.HashRefreshToken(request.RefreshToken.Trim());
        AuthResponse? response = null;
        Guid? refreshedUserId = null;
        var strategy = dbContext.Database.CreateExecutionStrategy();

        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            // Serializable isolation prevents two concurrent requests from successfully
            // exchanging the same one-time refresh token.
            var storedToken = await dbContext.RefreshTokens
                .SingleOrDefaultAsync(token => token.TokenHash == tokenHash, cancellationToken);

            if (storedToken is null ||
                storedToken.RevokedAtUtc is not null ||
                storedToken.ExpiresAtUtc <= dateTimeProvider.UtcNow)
            {
                throw new UnauthorizedException(
                    "The refresh token is invalid, expired, or already used.");
            }

            var user = await userManager.FindByIdAsync(storedToken.UserId.ToString());
            if (user is null || !user.IsActive)
            {
                throw new UnauthorizedException(
                    "The account associated with this token is unavailable.");
            }

            var roles = (await userManager.GetRolesAsync(user)).ToArray();
            var accessToken = jwtTokenService.CreateAccessToken(
                user.Id,
                user.Email ?? string.Empty,
                user.DisplayName,
                user.SecurityStamp ?? string.Empty,
                roles);
            var replacementToken = jwtTokenService.CreateRefreshToken();
            var now = dateTimeProvider.UtcNow;

            storedToken.RevokedAtUtc = now;
            storedToken.ReplacedByTokenHash = replacementToken.TokenHash;

            dbContext.RefreshTokens.Add(new RefreshToken
            {
                UserId = user.Id,
                TokenHash = replacementToken.TokenHash,
                CreatedAtUtc = now,
                ExpiresAtUtc = replacementToken.ExpiresAtUtc
            });

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            refreshedUserId = user.Id;
            response = BuildAuthResponse(user, roles, accessToken, replacementToken);
        });

        logger.LogInformation("Rotated refresh token for user {UserId}", refreshedUserId);
        return response!;
    }

    public async Task LogoutAsync(
        LogoutRequest request,
        CancellationToken cancellationToken)
    {
        ValidateRefreshToken(request.RefreshToken, nameof(request.RefreshToken));

        var currentUserId = currentUserService.UserId
            ?? throw new UnauthorizedException("Authentication is required to log out.");
        var tokenHash = jwtTokenService.HashRefreshToken(request.RefreshToken.Trim());
        var strategy = dbContext.Database.CreateExecutionStrategy();

        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);

            var storedToken = await dbContext.RefreshTokens
                .SingleOrDefaultAsync(token => token.TokenHash == tokenHash, cancellationToken)
                ?? throw new UnauthorizedException("The refresh token is invalid.");

            if (storedToken.UserId != currentUserId)
            {
                throw new ForbiddenException("The refresh token does not belong to the current user.");
            }

            if (storedToken.RevokedAtUtc is not null)
            {
                throw new UnauthorizedException("The refresh token has already been revoked.");
            }

            var user = await userManager.FindByIdAsync(currentUserId.ToString())
                ?? throw new UnauthorizedException("The current account is unavailable.");

            storedToken.RevokedAtUtc = dateTimeProvider.UtcNow;

            var stampResult = await userManager.UpdateSecurityStampAsync(user);
            EnsureIdentitySucceeded(stampResult, "invalidating the current access token");

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        logger.LogInformation("User {UserId} logged out and invalidated the current session", currentUserId);
    }

    private async Task<AuthResponse> CreateTokenPairAsync(
        AppUser user,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var roles = (await userManager.GetRolesAsync(user)).ToArray();
        var accessToken = jwtTokenService.CreateAccessToken(
            user.Id,
            user.Email ?? string.Empty,
            user.DisplayName,
            user.SecurityStamp ?? string.Empty,
            roles);
        var refreshToken = jwtTokenService.CreateRefreshToken();

        dbContext.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = refreshToken.TokenHash,
            CreatedAtUtc = dateTimeProvider.UtcNow,
            ExpiresAtUtc = refreshToken.ExpiresAtUtc
        });

        return BuildAuthResponse(user, roles, accessToken, refreshToken);
    }

    private static AuthResponse BuildAuthResponse(
        AppUser user,
        IReadOnlyCollection<string> roles,
        GeneratedAccessToken accessToken,
        GeneratedRefreshToken refreshToken) => new(
            accessToken.Token,
            refreshToken.PlainTextToken,
            accessToken.ExpiresAtUtc,
            refreshToken.ExpiresAtUtc,
            user.Id,
            user.Email ?? string.Empty,
            user.DisplayName,
            roles.OrderBy(role => role, StringComparer.Ordinal).ToArray());

    private static void ValidateRegisterRequest(RegisterRequest request)
    {
        var errors = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);

        ValidateEmail(request.Email, errors);
        ValidateName(request.FirstName, "firstName", "First name", errors);
        ValidateName(request.LastName, "lastName", "Last name", errors);

        if (string.IsNullOrWhiteSpace(request.Password))
        {
            AddError(errors, "password", "Password is required.");
        }

        if (!string.Equals(request.Password, request.ConfirmPassword, StringComparison.Ordinal))
        {
            AddError(errors, "confirmPassword", "Password and confirmation password must match.");
        }

        ThrowIfValidationErrors(errors);
    }

    private static void ValidateLoginRequest(LoginRequest request)
    {
        var errors = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        ValidateEmail(request.Email, errors);

        if (string.IsNullOrWhiteSpace(request.Password))
        {
            AddError(errors, "password", "Password is required.");
        }

        ThrowIfValidationErrors(errors);
    }

    private static void ValidateEmail(
        string? email,
        IDictionary<string, List<string>> errors)
    {
        if (string.IsNullOrWhiteSpace(email))
        {
            AddError(errors, "email", "Email address is required.");
            return;
        }

        if (email.Length > 256 || !EmailValidator.IsValid(email.Trim()))
        {
            AddError(errors, "email", "Enter a valid email address with at most 256 characters.");
        }
    }

    private static void ValidateName(
        string? value,
        string field,
        string label,
        IDictionary<string, List<string>> errors)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            AddError(errors, field, $"{label} is required.");
            return;
        }

        if (value.Trim().Length > 100)
        {
            AddError(errors, field, $"{label} must contain at most 100 characters.");
        }
    }

    private static void ValidateRefreshToken(string? token, string field)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Trim().Length < 40)
        {
            throw new ValidationException(
                "Refresh token validation failed.",
                new Dictionary<string, string[]>
                {
                    [field] = ["A valid refresh token is required."]
                });
        }
    }

    private static void ThrowIdentityValidationIfFailed(IdentityResult result)
    {
        if (result.Succeeded)
        {
            return;
        }

        if (result.Errors.Any(error =>
                error.Code.Contains("Duplicate", StringComparison.OrdinalIgnoreCase)))
        {
            throw new ConflictException("An account with this email address already exists.");
        }

        var errors = result.Errors
            .GroupBy(MapIdentityErrorField, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(
                group => group.Key,
                group => group.Select(error => error.Description).Distinct().ToArray(),
                StringComparer.OrdinalIgnoreCase);

        throw new ValidationException("Registration validation failed.", errors);
    }

    private static string MapIdentityErrorField(IdentityError error) =>
        error.Code.Contains("Password", StringComparison.OrdinalIgnoreCase)
            ? "password"
            : error.Code.Contains("Email", StringComparison.OrdinalIgnoreCase) ||
              error.Code.Contains("UserName", StringComparison.OrdinalIgnoreCase)
                ? "email"
                : "request";

    private static void EnsureIdentitySucceeded(IdentityResult result, string operation)
    {
        if (result.Succeeded)
        {
            return;
        }

        var message = string.Join("; ", result.Errors.Select(error => error.Description));
        throw new InvalidOperationException($"Identity operation failed while {operation}: {message}");
    }

    private static void AddError(
        IDictionary<string, List<string>> errors,
        string field,
        string message)
    {
        if (!errors.TryGetValue(field, out var fieldErrors))
        {
            fieldErrors = [];
            errors[field] = fieldErrors;
        }

        fieldErrors.Add(message);
    }

    private static void ThrowIfValidationErrors(
        IReadOnlyDictionary<string, List<string>> errors)
    {
        if (errors.Count == 0)
        {
            return;
        }

        throw new ValidationException(
            "One or more authentication fields are invalid.",
            errors.ToDictionary(
                pair => pair.Key,
                pair => pair.Value.Distinct().ToArray(),
                StringComparer.OrdinalIgnoreCase));
    }

    private static string BuildDisplayName(string firstName, string lastName) =>
        $"{firstName} {lastName}".Trim();
}
