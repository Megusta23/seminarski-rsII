using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Feed;
using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class FeedService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider) : IFeedService
{
    public async Task<PagedResult<FeedPostResponse>> GetFeedAsync(
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var query = BuildVisibleFeedQuery(userId, search: request.Search);

        var totalCount = await query.CountAsync(cancellationToken);
        var rows = await query
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArrayAsync(cancellationToken);
        var items = rows.Select(MapPost).ToArray();

        return new PagedResult<FeedPostResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<FeedPostResponse> GetPostAsync(
        Guid postId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var row = await BuildVisibleFeedQuery(userId, postId: postId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested feed post was not found.");
        return MapPost(row);
    }

    public async Task MarkViewedAsync(Guid postId, CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var visible = await BuildVisibleFeedQuery(userId, postId: postId)
            .AnyAsync(cancellationToken);
        if (!visible)
        {
            throw new NotFoundException("The requested feed post was not found.");
        }

        var exists = await dbContext.PostViews
            .AnyAsync(item => item.PostId == postId && item.ViewerUserId == userId, cancellationToken);
        if (!exists)
        {
            dbContext.PostViews.Add(new PostView
            {
                PostId = postId,
                ViewerUserId = userId,
                ViewedAtUtc = dateTimeProvider.UtcNow
            });
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    private IQueryable<FeedProjection> BuildVisibleFeedQuery(
        Guid userId,
        string? search = null,
        Guid? postId = null)
    {
        var query =
            from post in dbContext.Posts.AsNoTracking()
            join completion in dbContext.TaskCompletions.AsNoTracking() on post.TaskCompletionId equals completion.Id
            join task in dbContext.Tasks.AsNoTracking() on completion.TaskItemId equals task.Id
            join category in dbContext.TaskCategories.AsNoTracking() on task.TaskCategoryId equals category.Id
            join profile in dbContext.UserProfiles.AsNoTracking() on post.AuthorUserId equals profile.UserId
            join media in dbContext.TaskProofMedia.AsNoTracking()
                on completion.Id equals media.TaskCompletionId into mediaGroup
            from media in mediaGroup.DefaultIfEmpty()
            where post.IsVisible &&
                (post.AuthorUserId == userId || dbContext.Friendships.Any(friendship =>
                    friendship.UserId == userId && friendship.FriendUserId == post.AuthorUserId))
            select new
            {
                PostId = post.Id,
                post.AuthorUserId,
                AuthorDisplayName = (profile.FirstName + " " + profile.LastName).Trim(),
                HasAvatar = profile.AvatarStorageKey != null,
                TaskId = task.Id,
                TaskTitle = task.Title,
                CategoryName = category.Name,
                post.Caption,
                completion.CompletedAtUtc,
                ProofMediaId = media == null ? (Guid?)null : media.Id,
                HasBeenViewed = dbContext.PostViews.Any(view =>
                    view.PostId == post.Id && view.ViewerUserId == userId)
            };

        if (postId.HasValue)
        {
            query = query.Where(item => item.PostId == postId.Value);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var normalizedSearch = search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.TaskTitle, $"%{normalizedSearch}%") ||
                EF.Functions.Like(item.AuthorDisplayName, $"%{normalizedSearch}%") ||
                (item.Caption != null && EF.Functions.Like(item.Caption, $"%{normalizedSearch}%")));
        }

        return query
            .OrderByDescending(item => item.CompletedAtUtc)
            .Select(item => new FeedProjection(
                item.PostId,
                item.AuthorUserId,
                item.AuthorDisplayName,
                item.HasAvatar,
                item.TaskId,
                item.TaskTitle,
                item.CategoryName,
                item.Caption,
                item.CompletedAtUtc,
                item.ProofMediaId,
                item.HasBeenViewed));
    }

    private static FeedPostResponse MapPost(FeedProjection item) =>
        new(
            item.PostId,
            item.AuthorUserId,
            item.AuthorDisplayName,
            item.HasAvatar ? $"/api/media/avatars/{item.AuthorUserId}" : null,
            item.TaskId,
            item.TaskTitle,
            item.CategoryName,
            item.Caption,
            item.CompletedAtUtc,
            item.ProofMediaId,
            item.ProofMediaId.HasValue ? $"/api/media/task-proofs/{item.ProofMediaId.Value}" : null,
            item.HasBeenViewed);

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access the feed.");

    private sealed record FeedProjection(
        Guid PostId,
        Guid AuthorUserId,
        string AuthorDisplayName,
        bool HasAvatar,
        Guid TaskId,
        string TaskTitle,
        string CategoryName,
        string? Caption,
        DateTime CompletedAtUtc,
        Guid? ProofMediaId,
        bool HasBeenViewed);
}
