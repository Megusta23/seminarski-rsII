using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Feed;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/feed")]
public sealed class FeedController(IFeedService feedService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<FeedPostResponse>>> Get(
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await feedService.GetFeedAsync(request, cancellationToken));

    [HttpGet("{postId:guid}")]
    public async Task<ActionResult<FeedPostResponse>> GetById(
        Guid postId,
        CancellationToken cancellationToken) =>
        Ok(await feedService.GetPostAsync(postId, cancellationToken));

    [HttpPost("{postId:guid}/view")]
    public async Task<IActionResult> MarkViewed(Guid postId, CancellationToken cancellationToken)
    {
        await feedService.MarkViewedAsync(postId, cancellationToken);
        return NoContent();
    }
}
