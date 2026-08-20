using LadderSocial.Application.Abstractions;

namespace LadderSocial.Infrastructure.Services;

public sealed class NoOpRealtimeNotifier : IRealtimeNotifier
{
    public Task NotifyUserAsync(
        Guid userId,
        string method,
        object payload,
        CancellationToken cancellationToken) => Task.CompletedTask;

    public Task NotifyConversationAsync(
        Guid conversationId,
        string method,
        object payload,
        CancellationToken cancellationToken) => Task.CompletedTask;
}
