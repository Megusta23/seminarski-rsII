using LadderSocial.Domain.Common;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Domain.Entities;

public sealed class Message : SoftDeletableEntity
{
    public Guid ConversationId { get; set; }
    public Guid SenderUserId { get; set; }
    public MessageType Type { get; set; } = MessageType.Text;
    public string? Content { get; set; }
    public DateTime SentAtUtc { get; set; }
}
