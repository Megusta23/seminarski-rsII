using LadderSocial.Domain.Enums;

namespace LadderSocial.Api.Models;

public sealed class SendEncryptedMessageForm
{
    public MessageType Type { get; set; }
    public Guid SenderDeviceKeyId { get; set; }
    public int KeyVersion { get; set; }
    public string? EncryptedContentBase64 { get; set; }
    public string? ContentNonceBase64 { get; set; }
    public IFormFile? Attachment { get; set; }
    public string? AttachmentNonceBase64 { get; set; }
    public int? DurationMilliseconds { get; set; }
}
