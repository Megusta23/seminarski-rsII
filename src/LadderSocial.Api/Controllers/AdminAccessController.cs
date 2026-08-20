using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize(Roles = RoleNames.Admin)]
[Route("api/admin/access")]
public sealed class AdminAccessController(ICurrentUserService currentUserService) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<AdminAccessResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public ActionResult<AdminAccessResponse> Get() =>
        Ok(new AdminAccessResponse(
            currentUserService.UserId!.Value,
            "Administrator access granted."));
}

public sealed record AdminAccessResponse(Guid UserId, string Message);
