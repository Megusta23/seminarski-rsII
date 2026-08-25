using LadderSocial.Application.Features.Feed;
using LadderSocial.Domain.Enums;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/feed")]
public sealed class FeedController(IFeedService feedService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<FeedPageResponse>> Get(
        [FromQuery] FeedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await feedService.GetFeedAsync(request, cancellationToken));

    // Legacy completed-post details route retained for existing clients.
    [HttpGet("{postId:guid}")]
    public async Task<ActionResult<FeedItemResponse>> GetById(
        Guid postId,
        CancellationToken cancellationToken) =>
        Ok(await feedService.GetPostAsync(postId, cancellationToken));

    [HttpGet("items/{itemId:guid}")]
    public async Task<ActionResult<FeedItemResponse>> GetItem(
        Guid itemId,
        [FromQuery] FeedActivityType activityType,
        [FromQuery] DateOnly? date,
        CancellationToken cancellationToken) =>
        Ok(await feedService.GetItemAsync(itemId, activityType, date, cancellationToken));

    // Legacy operation: remains a no-op for visible posts without proof.
    [HttpPost("{postId:guid}/view")]
    public async Task<IActionResult> MarkViewed(Guid postId, CancellationToken cancellationToken)
    {
        await feedService.MarkViewedAsync(postId, requireProof: false, cancellationToken);
        return NoContent();
    }

    [HttpPost("{postId:guid}/view-proof")]
    public async Task<IActionResult> MarkProofViewed(Guid postId, CancellationToken cancellationToken)
    {
        await feedService.MarkViewedAsync(postId, requireProof: true, cancellationToken);
        return NoContent();
    }
}
