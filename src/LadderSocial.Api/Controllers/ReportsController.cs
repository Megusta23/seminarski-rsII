using LadderSocial.Application.Common.Security;
using LadderSocial.Application.Features.Reports;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize(Roles = RoleNames.Admin)]
[Route("api/admin/reports")]
public sealed class ReportsController(IReportService reportService) : ControllerBase
{
    [HttpGet("activity")]
    public async Task<IActionResult> Activity(
        [FromQuery] DateOnly fromDate,
        [FromQuery] DateOnly toDate,
        CancellationToken cancellationToken)
    {
        var file = await reportService.GenerateActivityReportAsync(fromDate, toDate, cancellationToken);
        return File(file.Content, file.ContentType, file.DownloadName);
    }

    [HttpGet("users/{userId:guid}")]
    public async Task<IActionResult> User(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var file = await reportService.GenerateUserReportAsync(userId, cancellationToken);
        return File(file.Content, file.ContentType, file.DownloadName);
    }
}
