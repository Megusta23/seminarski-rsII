using LadderSocial.Application.Common.Models;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Notifications;

public sealed class NotificationListRequest : PagedRequest
{
    public bool? IsRead { get; set; }
}

public sealed record NotificationResponse(
    Guid Id,
    NotificationKind Kind,
    string Title,
    string Body,
    bool IsRead,
    DateTime CreatedAtUtc,
    DateTime? ReadAtUtc,
    string? RelatedEntityType,
    Guid? RelatedEntityId);

public sealed record NotificationSummaryResponse(
    int UnreadCount,
    DateTime GeneratedAtUtc);

public interface INotificationService
{
    Task<PagedResult<NotificationResponse>> GetMyNotificationsAsync(NotificationListRequest request, CancellationToken cancellationToken);
    Task<NotificationSummaryResponse> GetSummaryAsync(CancellationToken cancellationToken);
    Task MarkReadAsync(Guid id, CancellationToken cancellationToken);
    Task MarkAllReadAsync(CancellationToken cancellationToken);
}
