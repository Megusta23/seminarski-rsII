using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class RecurrenceType : ReferenceEntity
{
    public string Code { get; set; } = string.Empty;
}
