using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class ConversationKeyEnvelope : Entity
{
    public Guid ConversationId { get; set; }
    public Guid RecipientDeviceKeyId { get; set; }
    public Guid SenderDeviceKeyId { get; set; }
    public byte[] EncryptedConversationKey { get; set; } = Array.Empty<byte>();
    public byte[] Nonce { get; set; } = Array.Empty<byte>();
    public int KeyVersion { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
