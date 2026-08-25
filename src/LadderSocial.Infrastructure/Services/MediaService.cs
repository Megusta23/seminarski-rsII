using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Media;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class MediaService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IFileStorageService fileStorageService) : IMediaService
{
    public async Task<FileContentResult> GetTaskProofAsync(
        Guid mediaId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var media = await (
                from item in dbContext.TaskProofMedia.AsNoTracking()
                join completion in dbContext.TaskCompletions.AsNoTracking()
                    on item.TaskCompletionId equals completion.Id
                join task in dbContext.Tasks.AsNoTracking()
                    on completion.TaskItemId equals task.Id
                join owner in dbContext.Users.AsNoTracking()
                    on completion.UserId equals owner.Id
                join post in dbContext.Posts.AsNoTracking()
                    on completion.Id equals post.TaskCompletionId into posts
                from post in posts.DefaultIfEmpty()
                where item.Id == mediaId
                select new
                {
                    Media = item,
                    OwnerUserId = completion.UserId,
                    OwnerIsActive = owner.IsActive,
                    IsShared = task.ShareWithFriends && post != null && post.IsVisible
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested task proof was not found.");

        var isFriend = media.OwnerUserId != userId && await dbContext.Friendships
            .AsNoTracking()
            .AnyAsync(
                friendship => friendship.UserId == userId && friendship.FriendUserId == media.OwnerUserId,
                cancellationToken);
        if (media.OwnerUserId != userId && (!media.OwnerIsActive || !media.IsShared || !isFriend))
        {
            throw new ForbiddenException("You do not have access to this task proof.");
        }

        return await fileStorageService.ReadAsync(
            media.Media.StorageKey,
            $"task-proof-{media.Media.Id}{ExtensionFor(media.Media.MimeType)}",
            media.Media.MimeType,
            cancellationToken);
    }

    public async Task<FileContentResult> GetMessageAttachmentAsync(
        Guid attachmentId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var attachment = await (
                from item in dbContext.MessageAttachments.AsNoTracking()
                join message in dbContext.Messages.AsNoTracking() on item.MessageId equals message.Id
                join participant in dbContext.ConversationParticipants.AsNoTracking()
                    on message.ConversationId equals participant.ConversationId
                where item.Id == attachmentId && participant.UserId == userId
                select item)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested message attachment was not found.");

        return await fileStorageService.ReadAsync(
            attachment.StorageKey,
            $"message-image-{attachment.Id}{ExtensionFor(attachment.MimeType)}",
            attachment.MimeType,
            cancellationToken);
    }

    public async Task<FileContentResult> GetAvatarAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        RequireCurrentUserId();
        var storageKey = await dbContext.UserProfiles
            .AsNoTracking()
            .Where(profile => profile.UserId == userId && profile.AvatarStorageKey != null)
            .Select(profile => profile.AvatarStorageKey)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested user does not have an avatar.");
        var contentType = ContentTypeFor(storageKey);
        return await fileStorageService.ReadAsync(
            storageKey,
            $"avatar-{userId}{ExtensionFor(contentType)}",
            contentType,
            cancellationToken);
    }

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access media.");

    private static string ExtensionFor(string contentType) =>
        contentType.ToLowerInvariant() switch
        {
            "image/png" => ".png",
            "image/webp" => ".webp",
            _ => ".jpg"
        };

    private static string ContentTypeFor(string storageKey) =>
        Path.GetExtension(storageKey).ToLowerInvariant() switch
        {
            ".png" => "image/png",
            ".webp" => "image/webp",
            _ => "image/jpeg"
        };
}
