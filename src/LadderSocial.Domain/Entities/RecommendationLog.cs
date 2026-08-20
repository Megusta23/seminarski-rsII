using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class RecommendationLog : Entity
{
    public Guid UserId { get; set; }
    public Guid RecommendedUserId { get; set; }
    public int MutualFriendCount { get; set; }
    public string Explanation { get; set; } = string.Empty;
    public DateTime CreatedAtUtc { get; set; }
}
