using LadderSocial.Application.Abstractions;

namespace LadderSocial.Application.Features.Media;

public interface IMediaService
{
    Task<FileContentResult> GetTaskProofAsync(Guid mediaId, CancellationToken cancellationToken);
    Task<FileContentResult> GetMessageAttachmentAsync(Guid attachmentId, CancellationToken cancellationToken);
    Task<FileContentResult> GetAvatarAsync(Guid userId, CancellationToken cancellationToken);
}
