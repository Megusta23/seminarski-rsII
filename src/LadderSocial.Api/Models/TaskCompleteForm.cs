using System.ComponentModel.DataAnnotations;

namespace LadderSocial.Api.Models;

public sealed class TaskCompleteForm
{
    [Required]
    public DateOnly? OccurrenceDate { get; set; }

    [StringLength(1000)]
    public string? Note { get; set; }

    [StringLength(1000)]
    public string? Caption { get; set; }

    public IFormFile? ProofImage { get; set; }
}
