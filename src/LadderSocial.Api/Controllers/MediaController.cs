using LadderSocial.Application.Features.Media;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/media")]
public sealed class MediaController(IMediaService mediaService) : ControllerBase
{
    [HttpGet("task-proofs/{mediaId:guid}")]
    public async Task<IActionResult> GetTaskProof(Guid mediaId, CancellationToken cancellationToken)
    {
        var file = await mediaService.GetTaskProofAsync(mediaId, cancellationToken);
        return File(file.Content, file.ContentType, file.DownloadName, enableRangeProcessing: false);
    }

    [HttpGet("message-attachments/{attachmentId:guid}")]
    public async Task<IActionResult> GetMessageAttachment(Guid attachmentId, CancellationToken cancellationToken)
    {
        var file = await mediaService.GetMessageAttachmentAsync(attachmentId, cancellationToken);
        return File(file.Content, file.ContentType, file.DownloadName, enableRangeProcessing: false);
    }

    [HttpGet("avatars/{userId:guid}")]
    public async Task<IActionResult> GetAvatar(Guid userId, CancellationToken cancellationToken)
    {
        var file = await mediaService.GetAvatarAsync(userId, cancellationToken);
        return File(file.Content, file.ContentType, file.DownloadName, enableRangeProcessing: false);
    }
}
