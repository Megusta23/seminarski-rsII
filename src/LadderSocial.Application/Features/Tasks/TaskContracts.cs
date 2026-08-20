using System.ComponentModel.DataAnnotations;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Tasks;

public sealed class TaskListRequest : PagedRequest
{
    public Guid? CategoryId { get; set; }
    public Guid? RecurrenceTypeId { get; set; }
    public TaskItemStatus? Status { get; set; }
    public DateTime? DueFromUtc { get; set; }
    public DateTime? DueToUtc { get; set; }
    public string? SortBy { get; set; }
    public string? SortDirection { get; set; }
}

public sealed record CreateTaskRequest(
    [Required, StringLength(200)] string Title,
    [StringLength(2000)] string? Description,
    Guid TaskCategoryId,
    Guid RecurrenceTypeId,
    DateTime? DueAtUtc,
    bool RequiresProofImage,
    bool ShareWithFriends);

public sealed record UpdateTaskRequest(
    [Required, StringLength(200)] string Title,
    [StringLength(2000)] string? Description,
    Guid TaskCategoryId,
    Guid RecurrenceTypeId,
    DateTime? DueAtUtc,
    bool RequiresProofImage,
    bool ShareWithFriends,
    TaskItemStatus Status);

public sealed record TaskListItemResponse(
    Guid Id,
    string Title,
    string CategoryName,
    string CategoryCode,
    string RecurrenceName,
    string RecurrenceCode,
    DateTime? DueAtUtc,
    TaskItemStatus Status,
    bool RequiresProofImage,
    bool ShareWithFriends,
    bool IsCompletedForToday,
    DateTime CreatedAtUtc);

public sealed record TaskDetailResponse(
    Guid Id,
    string Title,
    string? Description,
    Guid TaskCategoryId,
    string CategoryName,
    string CategoryCode,
    Guid RecurrenceTypeId,
    string RecurrenceName,
    string RecurrenceCode,
    DateTime? DueAtUtc,
    TaskItemStatus Status,
    bool RequiresProofImage,
    bool ShareWithFriends,
    DateTime CreatedAtUtc,
    DateTime? UpdatedAtUtc,
    IReadOnlyCollection<TaskCompletionResponse> RecentCompletions);

public sealed record CompleteTaskRequest(
    DateOnly OccurrenceDate,
    [StringLength(1000)] string? Note,
    [StringLength(1000)] string? Caption);

public sealed record CompleteTaskCommand(
    DateOnly OccurrenceDate,
    string? Note,
    string? Caption,
    UploadPayload? ProofImage);

public sealed record TaskCompletionResponse(
    Guid Id,
    Guid TaskId,
    DateOnly OccurrenceDate,
    DateTime CompletedAtUtc,
    string? Note,
    int ScorePoints,
    Guid? ProofMediaId,
    string? ProofUrl,
    Guid? PostId);

public interface ITaskService
{
    Task<PagedResult<TaskListItemResponse>> GetMyTasksAsync(
        TaskListRequest request,
        CancellationToken cancellationToken);

    Task<TaskDetailResponse> GetMyTaskAsync(Guid id, CancellationToken cancellationToken);
    Task<TaskDetailResponse> CreateAsync(CreateTaskRequest request, CancellationToken cancellationToken);
    Task<TaskDetailResponse> UpdateAsync(Guid id, UpdateTaskRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid id, CancellationToken cancellationToken);
    Task<TaskCompletionResponse> CompleteAsync(Guid id, CompleteTaskCommand command, CancellationToken cancellationToken);
    Task<PagedResult<TaskCompletionResponse>> GetCompletionsAsync(Guid id, PagedRequest request, CancellationToken cancellationToken);
}
