using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Notifications;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/notifications")]
public sealed class NotificationsController(INotificationService service) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<NotificationResponse>>> Get(
        [FromQuery] NotificationListRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.GetMyNotificationsAsync(request, cancellationToken));

    [HttpGet("summary")]
    public async Task<ActionResult<NotificationSummaryResponse>> GetSummary(
        CancellationToken cancellationToken) =>
        Ok(await service.GetSummaryAsync(cancellationToken));

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken cancellationToken)
    {
        await service.MarkReadAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken cancellationToken)
    {
        await service.MarkAllReadAsync(cancellationToken);
        return NoContent();
    }
}
