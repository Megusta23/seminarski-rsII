namespace LadderSocial.Domain.Common;

public abstract class ReferenceEntity : Entity
{
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public int SortOrder { get; set; }
}
