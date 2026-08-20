using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Notifications;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class NotificationService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider) : INotificationService
{
    public async Task<PagedResult<NotificationResponse>> GetMyNotificationsAsync(
        NotificationListRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var query = dbContext.Notifications
            .AsNoTracking()
            .Where(item => item.UserId == userId);

        if (request.IsRead.HasValue)
        {
            query = query.Where(item => item.IsRead == request.IsRead.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.Title, $"%{search}%") ||
                EF.Functions.Like(item.Body, $"%{search}%"));
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderByDescending(item => item.CreatedAtUtc)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new NotificationResponse(
                item.Id,
                item.Kind,
                item.Title,
                item.Body,
                item.IsRead,
                item.CreatedAtUtc,
                item.ReadAtUtc,
                item.RelatedEntityType,
                item.RelatedEntityId))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<NotificationResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<NotificationSummaryResponse> GetSummaryAsync(
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var unreadCount = await dbContext.Notifications
            .CountAsync(item => item.UserId == userId && !item.IsRead, cancellationToken);
        return new NotificationSummaryResponse(unreadCount, dateTimeProvider.UtcNow);
    }

    public async Task MarkReadAsync(Guid id, CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var notification = await dbContext.Notifications
            .SingleOrDefaultAsync(item => item.Id == id && item.UserId == userId, cancellationToken)
            ?? throw new NotFoundException("The requested notification was not found.");
        if (!notification.IsRead)
        {
            notification.IsRead = true;
            notification.ReadAtUtc = dateTimeProvider.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    public async Task MarkAllReadAsync(CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var now = dateTimeProvider.UtcNow;
        var notifications = await dbContext.Notifications
            .Where(item => item.UserId == userId && !item.IsRead)
            .ToArrayAsync(cancellationToken);
        foreach (var notification in notifications)
        {
            notification.IsRead = true;
            notification.ReadAtUtc = now;
        }

        if (notifications.Length > 0)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access notifications.");
}
