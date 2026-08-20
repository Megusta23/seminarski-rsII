using LadderSocial.Application.Features.Profiles;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/profile")]
public sealed class ProfileController(IProfileService profileService) : ControllerBase
{
    [HttpGet("me")]
    [ProducesResponseType<CurrentProfileResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CurrentProfileResponse>> GetCurrent(
        CancellationToken cancellationToken) =>
        Ok(await profileService.GetCurrentAsync(cancellationToken));

    [HttpPut("me")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> UpdateCurrent(
        [FromBody] UpdateProfileRequest request,
        CancellationToken cancellationToken)
    {
        await profileService.UpdateCurrentAsync(request, cancellationToken);
        return NoContent();
    }
}
