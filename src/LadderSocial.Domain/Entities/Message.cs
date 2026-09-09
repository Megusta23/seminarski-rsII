using LadderSocial.Domain.Common;
using LadderSocial.Domain.Constants;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Domain.Entities;

public sealed class Message : SoftDeletableEntity
{
    public Guid ConversationId { get; set; }
    public Guid SenderUserId { get; set; }
    public MessageType Type { get; set; } = MessageType.Text;
    public string? Content { get; set; }
    public byte[]? EncryptedContent { get; set; }
    public byte[]? ContentNonce { get; set; }
    public int EncryptionVersion { get; set; } = ChatEncryptionVersions.LegacyPlaintext;
    public int? KeyVersion { get; set; }
    public DateTime SentAtUtc { get; set; }
}
