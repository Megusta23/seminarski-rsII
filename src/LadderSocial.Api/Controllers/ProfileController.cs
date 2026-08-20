using LadderSocial.Api.Services;
using LadderSocial.Application.Features.Auth;
using LadderSocial.Application.Features.Profiles;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/profile")]
public sealed class ProfileController(
    IProfileService profileService,
    IPasswordRecoveryService passwordRecoveryService) : ControllerBase
{
    [HttpGet("me")]
    [ProducesResponseType<CurrentProfileResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CurrentProfileResponse>> GetCurrent(
        CancellationToken cancellationToken) =>
        Ok(await profileService.GetCurrentAsync(cancellationToken));

    [HttpPut("me")]
    [ProducesResponseType<CurrentProfileResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<CurrentProfileResponse>> UpdateCurrent(
        [FromBody] UpdateProfileRequest request,
        CancellationToken cancellationToken) =>
        Ok(await profileService.UpdateCurrentAsync(request, cancellationToken));

    [HttpPost("me/avatar")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType<CurrentProfileResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CurrentProfileResponse>> UpdateAvatar(
        IFormFile file,
        CancellationToken cancellationToken)
    {
        var upload = await FormFileReader.ReadAsync(file, cancellationToken);
        return Ok(await profileService.UpdateAvatarAsync(upload, cancellationToken));
    }

    [HttpDelete("me/avatar")]
    [ProducesResponseType<CurrentProfileResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CurrentProfileResponse>> RemoveAvatar(
        CancellationToken cancellationToken) =>
        Ok(await profileService.RemoveAvatarAsync(cancellationToken));

    [HttpPost("change-password")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ChangePassword(
        [FromBody] ChangePasswordRequest request,
        CancellationToken cancellationToken)
    {
        await passwordRecoveryService.ChangePasswordAsync(request, cancellationToken);
        return NoContent();
    }
}
