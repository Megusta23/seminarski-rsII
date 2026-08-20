using LadderSocial.Domain.Common;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Domain.Entities;

public sealed class FriendRequest : AuditableEntity
{
    public Guid SenderUserId { get; set; }
    public Guid ReceiverUserId { get; set; }
    public FriendRequestStatus Status { get; set; } = FriendRequestStatus.Pending;
    public DateTime? RespondedAtUtc { get; set; }
}
