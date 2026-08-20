using LadderSocial.Application.Features.Leaderboard;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/leaderboard")]
public sealed class LeaderboardController(ILeaderboardService service) : ControllerBase
{
    [HttpGet("daily")]
    public async Task<ActionResult<LeaderboardResponse>> GetDaily(
        [FromQuery] DateOnly? date,
        CancellationToken cancellationToken) =>
        Ok(await service.GetDailyAsync(date, cancellationToken));

    [HttpGet("weekly")]
    public async Task<ActionResult<LeaderboardResponse>> GetWeekly(
        [FromQuery] DateOnly? weekContaining,
        CancellationToken cancellationToken) =>
        Ok(await service.GetWeeklyAsync(weekContaining, cancellationToken));
}
