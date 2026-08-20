namespace LadderSocial.Application.Common.Messaging;

public sealed record PasswordResetRequestedEvent(
    Guid MessageId,
    Guid PasswordResetRequestId,
    Guid UserId,
    string Email,
    string DisplayName,
    string ProtectedCode,
    DateTime RequestedAtUtc,
    DateTime ExpiresAtUtc)
{
    public const string EventType = "LadderSocial.Auth.PasswordResetRequested.v1";
}
