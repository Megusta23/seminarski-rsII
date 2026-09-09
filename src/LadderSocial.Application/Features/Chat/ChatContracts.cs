using System.ComponentModel.DataAnnotations;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Chat;

public sealed record ConversationResponse(
    Guid Id,
    string DisplayTitle,
    bool IsGroup,
    bool CanSendMessages,
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
    byte[]? EncryptedContent,
    byte[]? ContentNonce,
    int EncryptionVersion,
    int? KeyVersion,
    DateTime SentAtUtc,
    Guid? AttachmentId,
    string? AttachmentUrl,
    string? AttachmentMimeType,
    byte[]? AttachmentNonce,
    int? AttachmentEncryptionVersion,
    int? AttachmentKeyVersion,
    long? AttachmentSizeBytes,
    int? AttachmentDurationMilliseconds);

public sealed record UserDeviceKeyResponse(
    Guid Id,
    Guid UserId,
    string DeviceId,
    byte[] PublicKey,
    DateTime CreatedAtUtc,
    DateTime LastSeenAtUtc);

public sealed record ConversationKeyEnvelopeResponse(
    Guid Id,
    Guid ConversationId,
    Guid RecipientDeviceKeyId,
    Guid SenderDeviceKeyId,
    byte[] EncryptedConversationKey,
    byte[] Nonce,
    int KeyVersion,
    DateTime CreatedAtUtc);

public sealed record RegisterDeviceKeyRequest(
    [Required, StringLength(128)] string DeviceId,
    [Required] byte[] PublicKey);

public sealed record CreateConversationKeyEnvelopeRequest(
    Guid RecipientDeviceKeyId,
    Guid SenderDeviceKeyId,
    [Required] byte[] EncryptedConversationKey,
    [Required] byte[] Nonce,
    [Range(1, int.MaxValue)] int KeyVersion);

public sealed record SendMessageRequest(
    [StringLength(4000)] string? Content);

public sealed record SendMessageCommand(
    string? Content,
    UploadPayload? Attachment);

public sealed record SendEncryptedMessageCommand(
    MessageType Type,
    Guid SenderDeviceKeyId,
    int KeyVersion,
    byte[]? EncryptedContent,
    byte[]? ContentNonce,
    UploadPayload? Attachment,
    byte[]? AttachmentNonce,
    int? DurationMilliseconds);

public interface IChatService
{
    Task<PagedResult<ConversationResponse>> GetConversationsAsync(PagedRequest request, CancellationToken cancellationToken);
    Task<ConversationResponse> GetConversationAsync(Guid conversationId, CancellationToken cancellationToken);
    Task<ConversationResponse> StartDirectConversationAsync(Guid friendUserId, CancellationToken cancellationToken);
    Task<PagedResult<MessageResponse>> GetMessagesAsync(Guid conversationId, PagedRequest request, CancellationToken cancellationToken);
    Task<MessageResponse> SendMessageAsync(Guid conversationId, SendMessageCommand command, CancellationToken cancellationToken);
    Task<MessageResponse> SendEncryptedMessageAsync(
        Guid conversationId,
        SendEncryptedMessageCommand command,
        CancellationToken cancellationToken);
    Task<UserDeviceKeyResponse> RegisterDeviceKeyAsync(
        RegisterDeviceKeyRequest request,
        CancellationToken cancellationToken);
    Task<PagedResult<UserDeviceKeyResponse>> GetConversationDeviceKeysAsync(
        Guid conversationId,
        PagedRequest request,
        CancellationToken cancellationToken);
    Task<ConversationKeyEnvelopeResponse> PutConversationKeyEnvelopeAsync(
        Guid conversationId,
        CreateConversationKeyEnvelopeRequest request,
        CancellationToken cancellationToken);
    Task<ConversationKeyEnvelopeResponse> GetConversationKeyEnvelopeAsync(
        Guid conversationId,
        Guid recipientDeviceKeyId,
        int? keyVersion,
        CancellationToken cancellationToken);
    Task MarkReadAsync(Guid conversationId, Guid? throughMessageId, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<Guid>> GetMyConversationIdsAsync(CancellationToken cancellationToken);
    Task EnsureMembershipAsync(Guid conversationId, CancellationToken cancellationToken);
}
