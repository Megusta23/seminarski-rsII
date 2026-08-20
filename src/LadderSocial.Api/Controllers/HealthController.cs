using LadderSocial.Application.Abstractions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Route("api/health")]
public sealed class HealthController(IDateTimeProvider dateTimeProvider) : ControllerBase
{
    [AllowAnonymous]
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public IActionResult Get() => Ok(new
    {
        status = "ok",
        service = "LadderSocial.Api",
        timestampUtc = dateTimeProvider.UtcNow
    });
}
