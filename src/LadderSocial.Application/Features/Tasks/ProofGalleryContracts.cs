using LadderSocial.Application.Abstractions;

namespace LadderSocial.Application.Features.Tasks;

public sealed record ProofGalleryItemResponse(
    Guid Id,
    string Url,
    string ContentType,
    int OrderIndex,
    int LayoutSlot);

public sealed record ProofGalleryResponse(
    Guid TaskCompletionId,
    string LayoutCode,
    IReadOnlyCollection<ProofGalleryItemResponse> Items);

public interface IProofGalleryService
{
    Task<ProofGalleryResponse> GetByPrimaryMediaAsync(
        Guid primaryMediaId,
        CancellationToken cancellationToken);

    Task<ProofGalleryResponse> GetByPostAsync(
        Guid postId,
        CancellationToken cancellationToken);

    Task<FileContentResult> GetItemAsync(
        Guid itemId,
        CancellationToken cancellationToken);
}
