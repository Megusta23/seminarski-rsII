using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class MessageAttachment : AuditableEntity
{
    public Guid MessageId { get; set; }
    public Guid OwnerUserId { get; set; }
    public string StorageKey { get; set; } = string.Empty;
    public string MimeType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
}
