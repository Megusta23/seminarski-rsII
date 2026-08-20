using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class ConversationParticipant : Entity
{
    public Guid ConversationId { get; set; }
    public Guid UserId { get; set; }
    public DateTime JoinedAtUtc { get; set; }
    public Guid? LastReadMessageId { get; set; }
}
