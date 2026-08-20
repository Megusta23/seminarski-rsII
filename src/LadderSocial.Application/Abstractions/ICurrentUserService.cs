namespace LadderSocial.Application.Abstractions;

public interface ICurrentUserService
{
    Guid? UserId { get; }
    bool IsAuthenticated { get; }
    bool IsInRole(string roleName);
}
