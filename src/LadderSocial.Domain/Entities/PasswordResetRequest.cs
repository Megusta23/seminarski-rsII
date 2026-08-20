using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class PasswordResetRequest : Entity
{
    public Guid UserId { get; set; }
    public string CodeHash { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
    public int AttemptCount { get; set; }
    public DateTime? UsedAtUtc { get; set; }
    public DateTime? InvalidatedAtUtc { get; set; }
    public DateTime? EmailQueuedAtUtc { get; set; }
    public DateTime? EmailSentAtUtc { get; set; }
    public int EmailDeliveryAttemptCount { get; set; }
    public string? LastDeliveryError { get; set; }
}
