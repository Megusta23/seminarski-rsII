namespace LadderSocial.Application.Common.Exceptions;

public sealed class ValidationException(
    string message,
    IReadOnlyDictionary<string, string[]>? errors = null) : AppException(message)
{
    public IReadOnlyDictionary<string, string[]> Errors { get; } =
        errors ?? new Dictionary<string, string[]>();
}
