using EmailAddressAttribute = System.ComponentModel.DataAnnotations.EmailAddressAttribute;
using System.Data;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Messaging;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Features.Auth;
using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace LadderSocial.Infrastructure.Identity;

public sealed class PasswordRecoveryService(
    UserManager<AppUser> userManager,
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IPasswordResetCodeService resetCodeService,
    IPasswordResetEventPublisher eventPublisher,
    IOptions<PasswordResetOptions> options,
    ILogger<PasswordRecoveryService> logger) : IPasswordRecoveryService
{
    private const string GenericForgotPasswordMessage =
        "If an active account exists for that email address, a reset code has been sent.";

    private static readonly EmailAddressAttribute EmailValidator = new();
    private readonly PasswordResetOptions _options = options.Value;

    public async Task<ForgotPasswordResponse> ForgotPasswordAsync(
        ForgotPasswordRequest request,
        CancellationToken cancellationToken)
    {
        ValidateEmail(request.Email);
        var email = request.Email.Trim();
        var user = await userManager.FindByEmailAsync(email);

        // The response is intentionally identical for known and unknown addresses.
        if (user is null || !user.IsActive)
        {
            logger.LogInformation(
                "Password reset was requested for an unavailable account. Request completed generically.");
            return new ForgotPasswordResponse(GenericForgotPasswordMessage);
        }

        var now = dateTimeProvider.UtcNow;
        var minimumCreatedAt = now.AddSeconds(-_options.MinimumRequestIntervalSeconds);
        var recentlyRequested = await dbContext.PasswordResetRequests
            .AsNoTracking()
            .AnyAsync(
                item => item.UserId == user.Id &&
                        item.CreatedAtUtc >= minimumCreatedAt &&
                        item.UsedAtUtc == null &&
                        item.InvalidatedAtUtc == null,
                cancellationToken);

        if (recentlyRequested)
        {
            logger.LogInformation(
                "Password reset request for user {UserId} was rate-limited by the minimum interval.",
                user.Id);
            return new ForgotPasswordResponse(GenericForgotPasswordMessage);
        }

        var generatedCode = resetCodeService.CreateCode();
        var resetRequest = new PasswordResetRequest
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            CodeHash = generatedCode.CodeHash,
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddMinutes(_options.CodeLifetimeMinutes)
        };

        var strategy = dbContext.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            var activeRequests = await dbContext.PasswordResetRequests
                .Where(item => item.UserId == user.Id &&
                               item.UsedAtUtc == null &&
                               item.InvalidatedAtUtc == null)
                .ToListAsync(cancellationToken);

            foreach (var activeRequest in activeRequests)
            {
                activeRequest.InvalidatedAtUtc = now;
            }

            dbContext.PasswordResetRequests.Add(resetRequest);
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        var message = new PasswordResetRequestedEvent(
            Guid.NewGuid(),
            resetRequest.Id,
            user.Id,
            user.Email ?? email,
            user.DisplayName,
            resetCodeService.ProtectForTransport(generatedCode.PlainTextCode),
            now,
            resetRequest.ExpiresAtUtc);

        try
        {
            await eventPublisher.PublishAsync(message, cancellationToken);
            resetRequest.EmailQueuedAtUtc = dateTimeProvider.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);

            logger.LogInformation(
                "Password reset email event {MessageId} was queued for request {PasswordResetRequestId}.",
                message.MessageId,
                resetRequest.Id);
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            // Preserve anti-enumeration behavior: clients still receive the generic response.
            // The code is invalidated so a later retry can safely generate a new request.
            resetRequest.InvalidatedAtUtc = dateTimeProvider.UtcNow;
            resetRequest.LastDeliveryError = Truncate(exception.Message, 2000);
            await dbContext.SaveChangesAsync(cancellationToken);

            logger.LogError(
                exception,
                "Could not queue password reset email for request {PasswordResetRequestId}.",
                resetRequest.Id);
        }

        return new ForgotPasswordResponse(GenericForgotPasswordMessage);
    }

    public async Task ResetPasswordAsync(
        ResetPasswordRequest request,
        CancellationToken cancellationToken)
    {
        ValidateResetRequest(request);
        var email = request.Email.Trim();
        var user = await userManager.FindByEmailAsync(email);

        if (user is null || !user.IsActive)
        {
            // Perform the same hash work as the normal path before returning the generic error.
            _ = resetCodeService.HashCode(request.Code);
            throw InvalidResetCode();
        }

        var invalidCode = false;
        var now = dateTimeProvider.UtcNow;
        var strategy = dbContext.Database.CreateExecutionStrategy();

        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                IsolationLevel.Serializable,
                cancellationToken);

            var resetRequest = await dbContext.PasswordResetRequests
                .Where(item => item.UserId == user.Id &&
                               item.UsedAtUtc == null &&
                               item.InvalidatedAtUtc == null)
                .OrderByDescending(item => item.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);

            if (resetRequest is null)
            {
                invalidCode = true;
                await transaction.CommitAsync(cancellationToken);
                return;
            }

            if (resetRequest.ExpiresAtUtc <= now ||
                resetRequest.AttemptCount >= _options.MaxAttempts)
            {
                resetRequest.InvalidatedAtUtc = now;
                await dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                invalidCode = true;
                return;
            }

            if (!resetCodeService.VerifyCode(request.Code, resetRequest.CodeHash))
            {
                resetRequest.AttemptCount++;
                if (resetRequest.AttemptCount >= _options.MaxAttempts)
                {
                    resetRequest.InvalidatedAtUtc = now;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                invalidCode = true;
                return;
            }

            var identityToken = await userManager.GeneratePasswordResetTokenAsync(user);
            var resetResult = await userManager.ResetPasswordAsync(
                user,
                identityToken,
                request.NewPassword);
            ThrowPasswordIdentityErrorsIfFailed(resetResult, "newPassword");

            if (await userManager.IsLockedOutAsync(user))
            {
                var clearLockoutResult = await userManager.SetLockoutEndDateAsync(user, null);
                EnsureIdentitySucceeded(clearLockoutResult, "clearing the account lockout");
            }

            if (user.AccessFailedCount > 0)
            {
                var resetLockoutResult = await userManager.ResetAccessFailedCountAsync(user);
                EnsureIdentitySucceeded(resetLockoutResult, "resetting failed login attempts");
            }

            resetRequest.UsedAtUtc = now;

            var otherActiveRequests = await dbContext.PasswordResetRequests
                .Where(item => item.UserId == user.Id &&
                               item.Id != resetRequest.Id &&
                               item.UsedAtUtc == null &&
                               item.InvalidatedAtUtc == null)
                .ToListAsync(cancellationToken);

            foreach (var activeRequest in otherActiveRequests)
            {
                activeRequest.InvalidatedAtUtc = now;
            }

            await RevokeActiveRefreshTokensAsync(user.Id, now, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        if (invalidCode)
        {
            throw InvalidResetCode();
        }

        logger.LogInformation(
            "Password was reset and all sessions were revoked for user {UserId}.",
            user.Id);
    }

    public async Task ChangePasswordAsync(
        ChangePasswordRequest request,
        CancellationToken cancellationToken)
    {
        ValidateChangePasswordRequest(request);
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedException("Authentication is required to change a password.");
        var now = dateTimeProvider.UtcNow;
        var strategy = dbContext.Database.CreateExecutionStrategy();

        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(
                cancellationToken);

            var user = await userManager.FindByIdAsync(userId.ToString())
                ?? throw new NotFoundException("The current user account was not found.");

            var changeResult = await userManager.ChangePasswordAsync(
                user,
                request.CurrentPassword,
                request.NewPassword);

            if (!changeResult.Succeeded && changeResult.Errors.Any(error =>
                    string.Equals(error.Code, "PasswordMismatch", StringComparison.OrdinalIgnoreCase)))
            {
                throw new ValidationException(
                    "Password change validation failed.",
                    new Dictionary<string, string[]>
                    {
                        ["currentPassword"] = ["The current password is incorrect."]
                    });
            }

            ThrowPasswordIdentityErrorsIfFailed(changeResult, "newPassword");

            await RevokeActiveRefreshTokensAsync(user.Id, now, cancellationToken);

            var activeResetRequests = await dbContext.PasswordResetRequests
                .Where(item => item.UserId == user.Id &&
                               item.UsedAtUtc == null &&
                               item.InvalidatedAtUtc == null)
                .ToListAsync(cancellationToken);

            foreach (var activeRequest in activeResetRequests)
            {
                activeRequest.InvalidatedAtUtc = now;
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        logger.LogInformation(
            "User {UserId} changed their password and revoked all sessions.",
            userId);
    }

    private async Task RevokeActiveRefreshTokensAsync(
        Guid userId,
        DateTime revokedAtUtc,
        CancellationToken cancellationToken)
    {
        var activeTokens = await dbContext.RefreshTokens
            .Where(token => token.UserId == userId &&
                            token.RevokedAtUtc == null &&
                            token.ExpiresAtUtc > revokedAtUtc)
            .ToListAsync(cancellationToken);

        foreach (var token in activeTokens)
        {
            token.RevokedAtUtc = revokedAtUtc;
        }
    }

    private static void ValidateEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email) ||
            email.Trim().Length > 256 ||
            !EmailValidator.IsValid(email.Trim()))
        {
            throw new ValidationException(
                "Password recovery validation failed.",
                new Dictionary<string, string[]>
                {
                    ["email"] = ["Enter a valid email address with at most 256 characters."]
                });
        }
    }

    private static void ValidateResetRequest(ResetPasswordRequest request)
    {
        ValidateEmail(request.Email);
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);

        if (string.IsNullOrWhiteSpace(request.Code) ||
            request.Code.Length != 6 ||
            request.Code.Any(character => !char.IsAsciiDigit(character)))
        {
            errors["code"] = ["Enter the six-digit reset code."];
        }

        ValidateNewPasswordPair(
            request.NewPassword,
            request.ConfirmPassword,
            errors);

        if (errors.Count > 0)
        {
            throw new ValidationException("Password reset validation failed.", errors);
        }
    }

    private static void ValidateChangePasswordRequest(ChangePasswordRequest request)
    {
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);

        if (string.IsNullOrWhiteSpace(request.CurrentPassword))
        {
            errors["currentPassword"] = ["Enter your current password."];
        }

        ValidateNewPasswordPair(
            request.NewPassword,
            request.ConfirmPassword,
            errors);

        if (!string.IsNullOrEmpty(request.CurrentPassword) &&
            string.Equals(
                request.CurrentPassword,
                request.NewPassword,
                StringComparison.Ordinal))
        {
            errors["newPassword"] = ["The new password must be different from the current password."];
        }

        if (errors.Count > 0)
        {
            throw new ValidationException("Password change validation failed.", errors);
        }
    }

    private static void ValidateNewPasswordPair(
        string? newPassword,
        string? confirmPassword,
        IDictionary<string, string[]> errors)
    {
        if (string.IsNullOrWhiteSpace(newPassword) || newPassword.Length < 10)
        {
            errors["newPassword"] = ["The new password must contain at least 10 characters."];
        }

        if (!string.Equals(newPassword, confirmPassword, StringComparison.Ordinal))
        {
            errors["confirmPassword"] = ["The new password and confirmation must match."];
        }
    }

    private static ValidationException InvalidResetCode() => new(
        "The password reset code is invalid, expired, or has already been used.",
        new Dictionary<string, string[]>
        {
            ["code"] = ["Enter the latest valid six-digit reset code."]
        });

    private static void ThrowPasswordIdentityErrorsIfFailed(
        IdentityResult result,
        string field)
    {
        if (result.Succeeded)
        {
            return;
        }

        var descriptions = result.Errors
            .Select(error => error.Description)
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        throw new ValidationException(
            "Password validation failed.",
            new Dictionary<string, string[]>
            {
                [field] = descriptions.Length == 0
                    ? ["The password does not satisfy the password policy."]
                    : descriptions
            });
    }

    private static void EnsureIdentitySucceeded(IdentityResult result, string operation)
    {
        if (result.Succeeded)
        {
            return;
        }

        var details = string.Join("; ", result.Errors.Select(error => error.Description));
        throw new InvalidOperationException(
            $"Identity operation failed while {operation}: {details}");
    }

    private static string Truncate(string value, int maximumLength) =>
        value.Length <= maximumLength ? value : value[..maximumLength];
}
