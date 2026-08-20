namespace LadderSocial.Application.Common.Exceptions;

public sealed class ForbiddenException(string message) : AppException(message)
{
}
