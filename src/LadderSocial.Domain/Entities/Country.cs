using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class Country : ReferenceEntity
{
    public string IsoCode { get; set; } = string.Empty;
}
