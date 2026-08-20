using System.ComponentModel.DataAnnotations;

namespace LadderSocial.Application.Features.Auth;

public sealed record ForgotPasswordRequest(
    [Required, EmailAddress, StringLength(256)] string Email);

public sealed record ForgotPasswordResponse(string Message);

public sealed record ResetPasswordRequest(
    [Required, EmailAddress, StringLength(256)] string Email,
    [Required, RegularExpression("^[0-9]{6}$", ErrorMessage = "Enter the six-digit reset code.")] string Code,
    [Required, StringLength(128, MinimumLength = 10)] string NewPassword,
    [Required, StringLength(128, MinimumLength = 10)] string ConfirmPassword);

public sealed record ChangePasswordRequest(
    [Required, StringLength(128)] string CurrentPassword,
    [Required, StringLength(128, MinimumLength = 10)] string NewPassword,
    [Required, StringLength(128, MinimumLength = 10)] string ConfirmPassword);

public interface IPasswordRecoveryService
{
    Task<ForgotPasswordResponse> ForgotPasswordAsync(
        ForgotPasswordRequest request,
        CancellationToken cancellationToken);

    Task ResetPasswordAsync(
        ResetPasswordRequest request,
        CancellationToken cancellationToken);

    Task ChangePasswordAsync(
        ChangePasswordRequest request,
        CancellationToken cancellationToken);
}
