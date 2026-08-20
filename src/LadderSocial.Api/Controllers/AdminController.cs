using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Common.Security;
using LadderSocial.Application.Features.Admin;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize(Roles = RoleNames.Admin)]
[Route("api/admin")]
public sealed class AdminController(IAdminService service) : ControllerBase
{
    [HttpGet("dashboard")]
    public async Task<ActionResult<AdminDashboardResponse>> GetDashboard(
        CancellationToken cancellationToken) =>
        Ok(await service.GetDashboardAsync(cancellationToken));

    [HttpGet("users")]
    public async Task<ActionResult<PagedResult<AdminUserListItemResponse>>> GetUsers(
        [FromQuery] AdminUserListRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.GetUsersAsync(request, cancellationToken));

    [HttpGet("users/{id:guid}")]
    public async Task<ActionResult<AdminUserDetailResponse>> GetUser(
        Guid id,
        CancellationToken cancellationToken) =>
        Ok(await service.GetUserAsync(id, cancellationToken));

    [HttpPut("users/{id:guid}/active")]
    public async Task<IActionResult> SetUserActive(
        Guid id,
        [FromBody] SetUserActiveRequest request,
        CancellationToken cancellationToken)
    {
        await service.SetUserActiveAsync(id, request.IsActive, cancellationToken);
        return NoContent();
    }

    [HttpGet("posts")]
    public async Task<ActionResult<PagedResult<AdminPostListItemResponse>>> GetPosts(
        [FromQuery] AdminPostListRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.GetPostsAsync(request, cancellationToken));

    [HttpPut("posts/{id:guid}/visibility")]
    public async Task<IActionResult> SetPostVisibility(
        Guid id,
        [FromBody] SetPostVisibilityRequest request,
        CancellationToken cancellationToken)
    {
        await service.SetPostVisibilityAsync(id, request.IsVisible, cancellationToken);
        return NoContent();
    }
}
