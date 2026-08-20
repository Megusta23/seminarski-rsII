using LadderSocial.Domain.Common;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Domain.Entities;

public sealed class Notification : AuditableEntity
{
    public Guid UserId { get; set; }
    public NotificationKind Kind { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public bool IsRead { get; set; }
    public DateTime? ReadAtUtc { get; set; }
    public string? RelatedEntityType { get; set; }
    public Guid? RelatedEntityId { get; set; }
}
