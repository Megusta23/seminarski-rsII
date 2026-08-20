using LadderSocial.Api.Hubs;
using LadderSocial.Application.Abstractions;
using Microsoft.AspNetCore.SignalR;

namespace LadderSocial.Api.Services;

public sealed class SignalRRealtimeNotifier(
    IHubContext<NotificationHub> notificationHub,
    IHubContext<ChatHub> chatHub) : IRealtimeNotifier
{
    public Task NotifyUserAsync(
        Guid userId,
        string method,
        object payload,
        CancellationToken cancellationToken) =>
        notificationHub.Clients
            .Group(NotificationHub.UserGroup(userId))
            .SendAsync(method, payload, cancellationToken);

    public Task NotifyConversationAsync(
        Guid conversationId,
        string method,
        object payload,
        CancellationToken cancellationToken) =>
        chatHub.Clients
            .Group(ChatHub.ConversationGroup(conversationId))
            .SendAsync(method, payload, cancellationToken);
}
