using LadderSocial.Application.Features.Chat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace LadderSocial.Api.Hubs;

[Authorize]
public sealed class ChatHub(IChatService chatService) : Hub
{
    public override async Task OnConnectedAsync()
    {
        var conversationIds = await chatService.GetMyConversationIdsAsync(Context.ConnectionAborted);
        foreach (var conversationId in conversationIds)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, ConversationGroup(conversationId));
        }

        await base.OnConnectedAsync();
    }

    public async Task JoinConversation(Guid conversationId)
    {
        await chatService.EnsureMembershipAsync(conversationId, Context.ConnectionAborted);
        await Groups.AddToGroupAsync(Context.ConnectionId, ConversationGroup(conversationId));
    }

    public async Task LeaveConversation(Guid conversationId)
    {
        await chatService.EnsureMembershipAsync(conversationId, Context.ConnectionAborted);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, ConversationGroup(conversationId));
    }

    public static string ConversationGroup(Guid conversationId) => $"conversation:{conversationId:N}";
}
