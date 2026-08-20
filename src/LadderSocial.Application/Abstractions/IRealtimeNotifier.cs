namespace LadderSocial.Application.Abstractions;

public interface IRealtimeNotifier
{
    Task NotifyUserAsync(
        Guid userId,
        string method,
        object payload,
        CancellationToken cancellationToken);

    Task NotifyConversationAsync(
        Guid conversationId,
        string method,
        object payload,
        CancellationToken cancellationToken);
}
