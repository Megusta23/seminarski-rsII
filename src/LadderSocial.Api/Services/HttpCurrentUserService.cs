using System.Security.Claims;
using LadderSocial.Application.Abstractions;

namespace LadderSocial.Api.Services;

public sealed class HttpCurrentUserService(IHttpContextAccessor httpContextAccessor)
    : ICurrentUserService
{
    private ClaimsPrincipal? Principal => httpContextAccessor.HttpContext?.User;

    public Guid? UserId
    {
        get
        {
            var rawValue = Principal?.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? Principal?.FindFirstValue("sub");

            return Guid.TryParse(rawValue, out var userId) ? userId : null;
        }
    }

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated == true;

    public bool IsInRole(string roleName) => Principal?.IsInRole(roleName) == true;
}
