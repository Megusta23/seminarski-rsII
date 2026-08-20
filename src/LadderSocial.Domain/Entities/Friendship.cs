using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class Friendship : AuditableEntity
{
    public Guid UserId { get; set; }
    public Guid FriendUserId { get; set; }
}
