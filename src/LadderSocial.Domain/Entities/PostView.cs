using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class PostView : Entity
{
    public Guid PostId { get; set; }
    public Guid ViewerUserId { get; set; }
    public DateTime ViewedAtUtc { get; set; }
}
