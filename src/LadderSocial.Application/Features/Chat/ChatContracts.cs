using System.ComponentModel.DataAnnotations;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Chat;

public sealed record ConversationResponse(
    Guid Id,
    string DisplayTitle,
    bool IsGroup,
    DateTime? LastMessageAtUtc,
    string? LastMessagePreview,
    int UnreadCount,
    IReadOnlyCollection<ConversationParticipantResponse> Participants);

public sealed record ConversationParticipantResponse(
    Guid UserId,
    string DisplayName,
    string? AvatarUrl,
    bool IsCurrentUser);

public sealed record MessageResponse(
    Guid Id,
    Guid ConversationId,
    Guid SenderUserId,
    string SenderDisplayName,
    MessageType Type,
    string? Content,
    DateTime SentAtUtc,
    Guid? AttachmentId,
    string? AttachmentUrl,
    string? AttachmentMimeType);

public sealed record SendMessageRequest(
    [StringLength(4000)] string? Content);

public sealed record SendMessageCommand(
    string? Content,
    UploadPayload? Attachment);

public interface IChatService
{
    Task<PagedResult<ConversationResponse>> GetConversationsAsync(PagedRequest request, CancellationToken cancellationToken);
    Task<ConversationResponse> StartDirectConversationAsync(Guid friendUserId, CancellationToken cancellationToken);
    Task<PagedResult<MessageResponse>> GetMessagesAsync(Guid conversationId, PagedRequest request, CancellationToken cancellationToken);
    Task<MessageResponse> SendMessageAsync(Guid conversationId, SendMessageCommand command, CancellationToken cancellationToken);
    Task MarkReadAsync(Guid conversationId, Guid? throughMessageId, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<Guid>> GetMyConversationIdsAsync(CancellationToken cancellationToken);
    Task EnsureMembershipAsync(Guid conversationId, CancellationToken cancellationToken);
}
