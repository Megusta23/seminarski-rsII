namespace LadderSocial.Application.Abstractions;

public interface IDateTimeProvider
{
    DateTime UtcNow { get; }
}
