using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Admin;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Infrastructure.Identity;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class AdminService(
    ApplicationDbContext dbContext,
    UserManager<AppUser> userManager,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    ICompletionStatisticsService completionStatisticsService) : IAdminService
{
    public async Task<AdminDashboardResponse> GetDashboardAsync(
        CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(dateTimeProvider.UtcNow);
        var totalUsers = await dbContext.Users.CountAsync(cancellationToken);
        var activeUsers = await dbContext.Users.CountAsync(item => item.IsActive, cancellationToken);
        var tasksCreated = await dbContext.Tasks.CountAsync(cancellationToken);
        var tasksCompletedToday = await completionStatisticsService.GetCompletionCountAsync(
            today,
            today,
            cancellationToken);
        var sharedPosts = await dbContext.Posts.CountAsync(cancellationToken);
        var friendRequests = await dbContext.FriendRequests.CountAsync(cancellationToken);
        var messages = await dbContext.Messages.CountAsync(cancellationToken);
        var topRows = await completionStatisticsService.GetTopUsersAsync(
            null,
            null,
            5,
            cancellationToken);
        var topIds = topRows.Select(item => item.UserId).ToArray();
        var names = await dbContext.Users
            .AsNoTracking()
            .Where(item => topIds.Contains(item.Id))
            .ToDictionaryAsync(item => item.Id, item => item.DisplayName, cancellationToken);
        var topUsers = topRows
            .Where(item => names.ContainsKey(item.UserId))
            .Select(item => new AdminTopUserResponse(
                item.UserId,
                names[item.UserId],
                item.CompletionCount))
            .ToArray();

        return new AdminDashboardResponse(
            dateTimeProvider.UtcNow,
            totalUsers,
            activeUsers,
            tasksCreated,
            tasksCompletedToday,
            sharedPosts,
            friendRequests,
            messages,
            topUsers);
    }

    public async Task<PagedResult<AdminUserListItemResponse>> GetUsersAsync(
        AdminUserListRequest request,
        CancellationToken cancellationToken)
    {
        var query =
            from user in dbContext.Users.AsNoTracking()
            join profile in dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId
            join city in dbContext.Cities.AsNoTracking() on profile.CityId equals (Guid?)city.Id into cities
            from city in cities.DefaultIfEmpty()
            select new
            {
                User = user,
                Profile = profile,
                CityName = city == null ? null : city.Name,
                FriendCount = dbContext.Friendships.Count(item => item.UserId == user.Id)
            };

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.User.DisplayName, $"%{search}%") ||
                (item.User.Email != null && EF.Functions.Like(item.User.Email, $"%{search}%")) ||
                EF.Functions.Like(item.Profile.FirstName, $"%{search}%") ||
                EF.Functions.Like(item.Profile.LastName, $"%{search}%"));
        }

        if (request.IsActive.HasValue)
        {
            query = query.Where(item => item.User.IsActive == request.IsActive.Value);
        }

        if (request.CityId.HasValue)
        {
            query = query.Where(item => item.Profile.CityId == request.CityId.Value);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var rows = await query
            .OrderBy(item => item.User.DisplayName)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new
            {
                item.User.Id,
                item.User.DisplayName,
                item.User.Email,
                item.User.IsActive,
                item.CityName,
                item.User.CreatedAtUtc,
                item.FriendCount,
                HasAvatar = item.Profile.AvatarStorageKey != null
            })
            .ToArrayAsync(cancellationToken);
        var completionCounts = await completionStatisticsService.GetTotalCompletionCountsAsync(
            rows.Select(item => item.Id).ToArray(),
            cancellationToken);
        var items = rows
            .Select(item => new AdminUserListItemResponse(
                item.Id,
                item.DisplayName,
                item.Email ?? string.Empty,
                item.IsActive,
                item.CityName,
                item.CreatedAtUtc,
                item.FriendCount,
                completionCounts.GetValueOrDefault(item.Id),
                item.HasAvatar ? $"/api/media/avatars/{item.Id}" : null))
            .ToArray();

        return new PagedResult<AdminUserListItemResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<AdminUserDetailResponse> GetUserAsync(
        Guid id,
        CancellationToken cancellationToken)
    {
        var data = await (
                from user in dbContext.Users.AsNoTracking()
                join profile in dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId
                join city in dbContext.Cities.AsNoTracking() on profile.CityId equals (Guid?)city.Id into cities
                from city in cities.DefaultIfEmpty()
                where user.Id == id
                select new
                {
                    User = user,
                    Profile = profile,
                    CityName = city == null ? null : city.Name,
                    FriendCount = dbContext.Friendships.Count(item => item.UserId == user.Id),
                    TaskCount = dbContext.Tasks.Count(item => item.OwnerUserId == user.Id),
                    PostCount = dbContext.Posts.Count(item => item.AuthorUserId == user.Id),
                    MessageCount = dbContext.Messages.Count(item => item.SenderUserId == user.Id)
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested user was not found.");
        var userEntity = await userManager.FindByIdAsync(id.ToString())
            ?? throw new NotFoundException("The requested user was not found.");
        var roles = await userManager.GetRolesAsync(userEntity);
        var completedTaskCount = await completionStatisticsService.GetTotalCompletionCountAsync(
            id,
            cancellationToken);

        return new AdminUserDetailResponse(
            data.User.Id,
            data.User.DisplayName,
            data.User.Email ?? string.Empty,
            data.User.IsActive,
            data.Profile.FirstName,
            data.Profile.LastName,
            data.Profile.Bio,
            data.CityName,
            data.Profile.DateOfBirth,
            data.User.CreatedAtUtc,
            data.FriendCount,
            data.TaskCount,
            completedTaskCount,
            data.PostCount,
            data.MessageCount,
            data.Profile.AvatarStorageKey != null ? $"/api/media/avatars/{data.User.Id}" : null,
            roles.OrderBy(item => item, StringComparer.Ordinal).ToArray());
    }

    public async Task SetUserActiveAsync(
        Guid id,
        bool isActive,
        CancellationToken cancellationToken)
    {
        var currentUserId = currentUserService.UserId;
        if (!isActive && currentUserId == id)
        {
            throw new BusinessException("You cannot deactivate the administrator account currently in use.");
        }

        var strategy = dbContext.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
            var user = await userManager.FindByIdAsync(id.ToString())
                ?? throw new NotFoundException("The requested user was not found.");
            user.IsActive = isActive;
            if (!isActive)
            {
                user.SecurityStamp = Guid.NewGuid().ToString("N");
            }

            var result = await userManager.UpdateAsync(user);
            if (!result.Succeeded)
            {
                throw new BusinessException(string.Join("; ", result.Errors.Select(item => item.Description)));
            }

            if (!isActive)
            {
                var revokedAtUtc = dateTimeProvider.UtcNow;
                var activeRefreshTokens = await dbContext.RefreshTokens
                    .Where(item => item.UserId == id && item.RevokedAtUtc == null)
                    .ToArrayAsync(cancellationToken);
                foreach (var token in activeRefreshTokens)
                {
                    token.RevokedAtUtc = revokedAtUtc;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
        });
    }

    public async Task<PagedResult<AdminPostListItemResponse>> GetPostsAsync(
        AdminPostListRequest request,
        CancellationToken cancellationToken)
    {
        var query =
            from post in dbContext.Posts.IgnoreQueryFilters().AsNoTracking()
            join user in dbContext.Users.AsNoTracking() on post.AuthorUserId equals user.Id
            join completion in dbContext.TaskCompletions.AsNoTracking() on post.TaskCompletionId equals completion.Id
            join task in dbContext.Tasks.IgnoreQueryFilters().AsNoTracking() on completion.TaskItemId equals task.Id
            select new
            {
                Post = post,
                AuthorDisplayName = user.DisplayName,
                TaskTitle = task.Title
            };

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.AuthorDisplayName, $"%{search}%") ||
                EF.Functions.Like(item.TaskTitle, $"%{search}%") ||
                (item.Post.Caption != null && EF.Functions.Like(item.Post.Caption, $"%{search}%")));
        }

        if (request.IsVisible.HasValue)
        {
            query = query.Where(item => item.Post.IsVisible == request.IsVisible.Value);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderByDescending(item => item.Post.CreatedAtUtc)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new AdminPostListItemResponse(
                item.Post.Id,
                item.Post.AuthorUserId,
                item.AuthorDisplayName,
                item.TaskTitle,
                item.Post.Caption,
                item.Post.IsVisible,
                item.Post.CreatedAtUtc))
            .ToArrayAsync(cancellationToken);
        return new PagedResult<AdminPostListItemResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task SetPostVisibilityAsync(
        Guid id,
        bool isVisible,
        CancellationToken cancellationToken)
    {
        var post = await dbContext.Posts
            .IgnoreQueryFilters()
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested post was not found.");
        post.IsVisible = isVisible;
        if (!isVisible)
        {
            post.IsHighlighted = false;
            post.HighlightedAtUtc = null;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
