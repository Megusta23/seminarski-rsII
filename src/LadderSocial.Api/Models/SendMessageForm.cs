using System.ComponentModel.DataAnnotations;

namespace LadderSocial.Api.Models;

public sealed class SendMessageForm
{
    [StringLength(4000)]
    public string? Content { get; set; }

    public IFormFile? Attachment { get; set; }
}
