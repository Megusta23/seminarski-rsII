using LadderSocial.Api.Models;
using LadderSocial.Api.Services;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Features.Chat;
using LadderSocial.Domain.Constants;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/conversations")]
public sealed class ChatController(
    IChatService chatService,
    IOptions<FileStorageOptions> fileStorageOptions) : ControllerBase
{
    private readonly FileStorageOptions _fileStorageOptions = fileStorageOptions.Value;

    [HttpGet]
    public async Task<ActionResult<PagedResult<ConversationResponse>>> GetConversations(
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await chatService.GetConversationsAsync(request, cancellationToken));

    [HttpGet("{conversationId:guid}")]
    public async Task<ActionResult<ConversationResponse>> GetConversation(
        Guid conversationId,
        CancellationToken cancellationToken) =>
        Ok(await chatService.GetConversationAsync(conversationId, cancellationToken));

    [HttpPost("direct/{friendUserId:guid}")]
    public async Task<ActionResult<ConversationResponse>> StartDirect(
        Guid friendUserId,
        CancellationToken cancellationToken)
    {
        var conversation = await chatService.StartDirectConversationAsync(friendUserId, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, conversation);
    }

    [HttpPut("device-keys")]
    public async Task<ActionResult<UserDeviceKeyResponse>> RegisterDeviceKey(
        [FromBody] RegisterDeviceKeyRequest request,
        CancellationToken cancellationToken) =>
        Ok(await chatService.RegisterDeviceKeyAsync(request, cancellationToken));

    [HttpGet("{conversationId:guid}/device-keys")]
    public async Task<ActionResult<PagedResult<UserDeviceKeyResponse>>> GetConversationDeviceKeys(
        Guid conversationId,
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await chatService.GetConversationDeviceKeysAsync(
            conversationId,
            request,
            cancellationToken));

    [HttpPut("{conversationId:guid}/key-envelopes")]
    public async Task<ActionResult<ConversationKeyEnvelopeResponse>> PutConversationKeyEnvelope(
        Guid conversationId,
        [FromBody] CreateConversationKeyEnvelopeRequest request,
        CancellationToken cancellationToken) =>
        Ok(await chatService.PutConversationKeyEnvelopeAsync(
            conversationId,
            request,
            cancellationToken));

    [HttpGet("{conversationId:guid}/key-envelopes/{recipientDeviceKeyId:guid}")]
    public async Task<ActionResult<ConversationKeyEnvelopeResponse>> GetConversationKeyEnvelope(
        Guid conversationId,
        Guid recipientDeviceKeyId,
        [FromQuery] int? keyVersion,
        CancellationToken cancellationToken) =>
        Ok(await chatService.GetConversationKeyEnvelopeAsync(
            conversationId,
            recipientDeviceKeyId,
            keyVersion,
            cancellationToken));

    [HttpGet("{conversationId:guid}/messages")]
    public async Task<ActionResult<PagedResult<MessageResponse>>> GetMessages(
        Guid conversationId,
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await chatService.GetMessagesAsync(conversationId, request, cancellationToken));

    [HttpPost("{conversationId:guid}/messages/e2e")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<MessageResponse>> SendEncryptedMessage(
        Guid conversationId,
        [FromForm] SendEncryptedMessageForm form,
        CancellationToken cancellationToken)
    {
        var attachment = form.Attachment is null
            ? null
            : await FormFileReader.ReadEncryptedAsync(
                form.Attachment,
                _fileStorageOptions.MaximumEncryptedChatMediaBytes,
                cancellationToken);
        var command = new SendEncryptedMessageCommand(
            form.Type,
            form.SenderDeviceKeyId,
            form.KeyVersion,
            Base64PayloadReader.DecodeOptional(
                form.EncryptedContentBase64,
                "encryptedContentBase64",
                ChatCryptoConstants.MaximumEncryptedMessageBytes),
            Base64PayloadReader.DecodeOptional(
                form.ContentNonceBase64,
                "contentNonceBase64",
                ChatCryptoConstants.AeadNonceBytes),
            attachment,
            Base64PayloadReader.DecodeOptional(
                form.AttachmentNonceBase64,
                "attachmentNonceBase64",
                ChatCryptoConstants.AeadNonceBytes),
            form.DurationMilliseconds);
        var message = await chatService.SendEncryptedMessageAsync(
            conversationId,
            command,
            cancellationToken);
        return StatusCode(StatusCodes.Status201Created, message);
    }

    [HttpPost("{conversationId:guid}/read")]
    public async Task<IActionResult> MarkRead(
        Guid conversationId,
        [FromQuery] Guid? throughMessageId,
        CancellationToken cancellationToken)
    {
        await chatService.MarkReadAsync(conversationId, throughMessageId, cancellationToken);
        return NoContent();
    }
}
