using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class TaskProofItem : AuditableEntity
{
    public Guid TaskCompletionId { get; set; }
    public Guid OwnerUserId { get; set; }
    public string StorageKey { get; set; } = string.Empty;
    public string MimeType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public int OrderIndex { get; set; }
    public int LayoutSlot { get; set; }
}
