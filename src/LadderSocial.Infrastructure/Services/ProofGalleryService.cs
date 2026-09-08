using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Domain.Constants;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class ProofGalleryService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IFileStorageService fileStorageService) : IProofGalleryService
{
    public async Task<ProofGalleryResponse> GetByPrimaryMediaAsync(
        Guid primaryMediaId,
        CancellationToken cancellationToken)
    {
        var completionId = await dbContext.TaskProofMedia
            .AsNoTracking()
            .Where(item => item.Id == primaryMediaId)
            .Select(item => (Guid?)item.TaskCompletionId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested proof gallery was not found.");

        return await BuildGalleryAsync(completionId, cancellationToken);
    }

    public async Task<ProofGalleryResponse> GetByPostAsync(
        Guid postId,
        CancellationToken cancellationToken)
    {
        var completionId = await dbContext.Posts
            .AsNoTracking()
            .Where(post => post.Id == postId && post.IsVisible)
            .Select(post => (Guid?)post.TaskCompletionId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested proof gallery was not found.");

        return await BuildGalleryAsync(completionId, cancellationToken);
    }

    public async Task<FileContentResult> GetItemAsync(
        Guid itemId,
        CancellationToken cancellationToken)
    {
        var item = await dbContext.TaskProofItems
            .AsNoTracking()
            .Where(value => value.Id == itemId)
            .Select(value => new StoredProofRow(
                value.TaskCompletionId,
                value.StorageKey,
                value.MimeType,
                value.Id))
            .SingleOrDefaultAsync(cancellationToken);

        // Existing single-photo completions do not have TaskProofItem rows.
        // Treat their primary cover as a one-item gallery for compatibility.
        item ??= await dbContext.TaskProofMedia
            .AsNoTracking()
            .Where(value => value.Id == itemId)
            .Select(value => new StoredProofRow(
                value.TaskCompletionId,
                value.StorageKey,
                value.MimeType,
                value.Id))
            .SingleOrDefaultAsync(cancellationToken);

        if (item is null)
        {
            throw new NotFoundException("The requested proof photo was not found.");
        }

        await EnsureCanAccessAsync(item.TaskCompletionId, cancellationToken);
        return await fileStorageService.ReadAsync(
            item.StorageKey,
            $"task-proof-photo-{item.Id}{ExtensionFor(item.MimeType)}",
            item.MimeType,
            cancellationToken);
    }

    private async Task<ProofGalleryResponse> BuildGalleryAsync(
        Guid completionId,
        CancellationToken cancellationToken)
    {
        await EnsureCanAccessAsync(completionId, cancellationToken);

        var completion = await (
                from item in dbContext.TaskCompletions.AsNoTracking()
                join primary in dbContext.TaskProofMedia.AsNoTracking()
                    on item.Id equals primary.TaskCompletionId into primaryGroup
                from primary in primaryGroup.DefaultIfEmpty()
                where item.Id == completionId
                select new
                {
                    item.Id,
                    item.ProofLayoutCode,
                    PrimaryId = primary == null ? (Guid?)null : primary.Id,
                    PrimaryMimeType = primary == null ? null : primary.MimeType
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested proof gallery was not found.");

        var items = await dbContext.TaskProofItems
            .AsNoTracking()
            .Where(item => item.TaskCompletionId == completionId)
            .OrderBy(item => item.OrderIndex)
            .ThenBy(item => item.Id)
            .Select(item => new ProofGalleryItemResponse(
                item.Id,
                $"/api/proof-galleries/items/{item.Id}",
                item.MimeType,
                item.OrderIndex,
                item.LayoutSlot))
            .ToArrayAsync(cancellationToken);

        if (items.Length == 0 && completion.PrimaryId.HasValue)
        {
            items =
            [
                new ProofGalleryItemResponse(
                    completion.PrimaryId.Value,
                    $"/api/proof-galleries/items/{completion.PrimaryId.Value}",
                    completion.PrimaryMimeType ?? "image/jpeg",
                    0,
                    0)
            ];
        }

        if (items.Length == 0)
        {
            throw new NotFoundException("The requested task completion does not contain proof photos.");
        }

        return new ProofGalleryResponse(
            completion.Id,
            string.IsNullOrWhiteSpace(completion.ProofLayoutCode)
                ? ProofLayoutCodes.Single
                : completion.ProofLayoutCode,
            items);
    }

    private async Task EnsureCanAccessAsync(
        Guid completionId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var access = await (
                from completion in dbContext.TaskCompletions.AsNoTracking()
                join task in dbContext.Tasks.AsNoTracking()
                    on completion.TaskItemId equals task.Id
                join owner in dbContext.Users.AsNoTracking()
                    on completion.UserId equals owner.Id
                join post in dbContext.Posts.AsNoTracking()
                    on completion.Id equals post.TaskCompletionId into postGroup
                from post in postGroup.DefaultIfEmpty()
                where completion.Id == completionId
                select new
                {
                    OwnerUserId = completion.UserId,
                    OwnerIsActive = owner.IsActive,
                    IsShared = task.ShareWithFriends && post != null && post.IsVisible
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested task proof was not found.");

        if (access.OwnerUserId == userId)
        {
            return;
        }

        var isFriend = await dbContext.Friendships
            .AsNoTracking()
            .AnyAsync(
                friendship => friendship.UserId == userId &&
                    friendship.FriendUserId == access.OwnerUserId,
                cancellationToken);
        if (!access.OwnerIsActive || !access.IsShared || !isFriend)
        {
            throw new ForbiddenException("You do not have access to this task proof.");
        }
    }

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access proof galleries.");

    private static string ExtensionFor(string contentType) =>
        contentType.ToLowerInvariant() switch
        {
            "image/png" => ".png",
            "image/webp" => ".webp",
            _ => ".jpg"
        };

    private sealed record StoredProofRow(
        Guid TaskCompletionId,
        string StorageKey,
        string MimeType,
        Guid Id);
}
