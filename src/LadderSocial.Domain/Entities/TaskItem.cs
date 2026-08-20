using LadderSocial.Domain.Common;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Domain.Entities;

public sealed class TaskItem : SoftDeletableEntity
{
    public Guid OwnerUserId { get; set; }
    public Guid TaskCategoryId { get; set; }
    public Guid RecurrenceTypeId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTime? DueAtUtc { get; set; }
    public TaskItemStatus Status { get; set; } = TaskItemStatus.Active;
    public bool RequiresProofImage { get; set; }
    public bool ShareWithFriends { get; set; }
}
