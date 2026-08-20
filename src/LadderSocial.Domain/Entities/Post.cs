using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class Post : SoftDeletableEntity
{
    public Guid AuthorUserId { get; set; }
    public Guid TaskCompletionId { get; set; }
    public string? Caption { get; set; }
    public bool IsVisible { get; set; } = true;
}
