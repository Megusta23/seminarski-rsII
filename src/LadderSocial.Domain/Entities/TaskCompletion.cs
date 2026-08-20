using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class TaskCompletion : AuditableEntity
{
    public Guid TaskItemId { get; set; }
    public Guid UserId { get; set; }
    public DateTime CompletedAtUtc { get; set; }
    public int ScorePoints { get; set; } = 1;
    public string? Note { get; set; }
}
