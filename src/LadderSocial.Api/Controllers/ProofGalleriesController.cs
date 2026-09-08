using LadderSocial.Application.Features.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/proof-galleries")]
public sealed class ProofGalleriesController(
    IProofGalleryService proofGalleryService) : ControllerBase
{
    [HttpGet("by-media/{primaryMediaId:guid}")]
    public async Task<ActionResult<ProofGalleryResponse>> GetByPrimaryMedia(
        Guid primaryMediaId,
        CancellationToken cancellationToken) =>
        Ok(await proofGalleryService.GetByPrimaryMediaAsync(
            primaryMediaId,
            cancellationToken));

    [HttpGet("posts/{postId:guid}")]
    public async Task<ActionResult<ProofGalleryResponse>> GetByPost(
        Guid postId,
        CancellationToken cancellationToken) =>
        Ok(await proofGalleryService.GetByPostAsync(postId, cancellationToken));

    [HttpGet("items/{itemId:guid}")]
    public async Task<IActionResult> GetItem(
        Guid itemId,
        CancellationToken cancellationToken)
    {
        var file = await proofGalleryService.GetItemAsync(itemId, cancellationToken);
        return File(
            file.Content,
            file.ContentType,
            file.DownloadName,
            enableRangeProcessing: false);
    }
}
