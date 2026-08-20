using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class City : ReferenceEntity
{
    public Guid CountryId { get; set; }
}
