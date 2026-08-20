using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Friends;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/friends")]
public sealed class FriendsController(IFriendService friendService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<FriendSummaryResponse>>> GetFriends(
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await friendService.GetFriendsAsync(request, cancellationToken));

    [HttpGet("search")]
    public async Task<ActionResult<PagedResult<UserSearchResponse>>> SearchUsers(
        [FromQuery] UserSearchRequest request,
        CancellationToken cancellationToken) =>
        Ok(await friendService.SearchUsersAsync(request, cancellationToken));

    [HttpGet("requests/incoming")]
    public async Task<ActionResult<PagedResult<FriendRequestResponse>>> GetIncomingRequests(
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await friendService.GetIncomingRequestsAsync(request, cancellationToken));

    [HttpGet("requests/outgoing")]
    public async Task<ActionResult<PagedResult<FriendRequestResponse>>> GetOutgoingRequests(
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await friendService.GetOutgoingRequestsAsync(request, cancellationToken));

    [HttpPost("requests/{receiverUserId:guid}")]
    public async Task<ActionResult<FriendRequestResponse>> SendRequest(
        Guid receiverUserId,
        CancellationToken cancellationToken)
    {
        var created = await friendService.SendRequestAsync(receiverUserId, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    [HttpPost("requests/{requestId:guid}/accept")]
    public async Task<IActionResult> Accept(Guid requestId, CancellationToken cancellationToken)
    {
        await friendService.AcceptRequestAsync(requestId, cancellationToken);
        return NoContent();
    }

    [HttpPost("requests/{requestId:guid}/reject")]
    public async Task<IActionResult> Reject(Guid requestId, CancellationToken cancellationToken)
    {
        await friendService.RejectRequestAsync(requestId, cancellationToken);
        return NoContent();
    }

    [HttpPost("requests/{requestId:guid}/cancel")]
    public async Task<IActionResult> Cancel(Guid requestId, CancellationToken cancellationToken)
    {
        await friendService.CancelRequestAsync(requestId, cancellationToken);
        return NoContent();
    }

    [HttpDelete("{friendUserId:guid}")]
    public async Task<IActionResult> Remove(Guid friendUserId, CancellationToken cancellationToken)
    {
        await friendService.RemoveFriendAsync(friendUserId, cancellationToken);
        return NoContent();
    }

    [HttpGet("{userId:guid}/profile")]
    public async Task<ActionResult<FriendProfileResponse>> GetProfile(
        Guid userId,
        CancellationToken cancellationToken) =>
        Ok(await friendService.GetFriendProfileAsync(userId, cancellationToken));

    [HttpGet("recommendations")]
    public async Task<ActionResult<IReadOnlyCollection<FriendRecommendationResponse>>> GetRecommendations(
        CancellationToken cancellationToken) =>
        Ok(await friendService.GetRecommendationsAsync(cancellationToken));
}
