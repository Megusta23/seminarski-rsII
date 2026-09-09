using LadderSocial.Domain.Common;
using LadderSocial.Domain.Constants;

namespace LadderSocial.Domain.Entities;

public sealed class MessageAttachment : AuditableEntity
{
    public Guid MessageId { get; set; }
    public Guid OwnerUserId { get; set; }
    public string StorageKey { get; set; } = string.Empty;
    public string MimeType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public byte[]? ContentNonce { get; set; }
    public int EncryptionVersion { get; set; } = ChatEncryptionVersions.LegacyPlaintext;
    public int? KeyVersion { get; set; }
    public int? DurationMilliseconds { get; set; }
}
