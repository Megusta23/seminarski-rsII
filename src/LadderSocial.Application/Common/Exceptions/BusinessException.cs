namespace LadderSocial.Application.Common.Exceptions;

public sealed class BusinessException(string message) : AppException(message)
{
}
