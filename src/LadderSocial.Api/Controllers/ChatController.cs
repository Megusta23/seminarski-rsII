using LadderSocial.Api.Models;
using LadderSocial.Api.Services;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Chat;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/conversations")]
public sealed class ChatController(IChatService chatService) : ControllerBase
{
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

    [HttpGet("{conversationId:guid}/messages")]
    public async Task<ActionResult<PagedResult<MessageResponse>>> GetMessages(
        Guid conversationId,
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await chatService.GetMessagesAsync(conversationId, request, cancellationToken));

    [HttpPost("{conversationId:guid}/messages")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<MessageResponse>> SendMessage(
        Guid conversationId,
        [FromForm] SendMessageForm form,
        CancellationToken cancellationToken)
    {
        var attachment = form.Attachment is null
            ? null
            : await FormFileReader.ReadAsync(form.Attachment, cancellationToken);
        var message = await chatService.SendMessageAsync(
            conversationId,
            new SendMessageCommand(form.Content, attachment),
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
