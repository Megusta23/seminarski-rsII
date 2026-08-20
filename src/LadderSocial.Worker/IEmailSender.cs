namespace LadderSocial.Worker;

public interface IEmailSender
{
    Task SendPasswordResetAsync(
        string recipientEmail,
        string displayName,
        string resetCode,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken);
}
