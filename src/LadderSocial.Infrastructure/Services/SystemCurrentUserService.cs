using LadderSocial.Application.Abstractions;

namespace LadderSocial.Infrastructure.Services;

public sealed class SystemCurrentUserService : ICurrentUserService
{
    public Guid? UserId => null;
    public bool IsAuthenticated => false;
    public bool IsInRole(string roleName) => false;
}
