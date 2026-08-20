using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class Conversation : SoftDeletableEntity
{
    public bool IsGroup { get; set; }
    public string? Title { get; set; }
    public DateTime? LastMessageAtUtc { get; set; }
}
