using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class RefreshToken : Entity
{
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
    public string? ReplacedByTokenHash { get; set; }
    public bool IsActiveAt(DateTime utcNow) =>
        RevokedAtUtc is null && ExpiresAtUtc > utcNow;
}
