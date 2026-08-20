using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class UserProfile : SoftDeletableEntity
{
    public Guid UserId { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string? Bio { get; set; }
    public string? AvatarStorageKey { get; set; }
    public Guid? CityId { get; set; }
    public DateOnly? DateOfBirth { get; set; }
}
