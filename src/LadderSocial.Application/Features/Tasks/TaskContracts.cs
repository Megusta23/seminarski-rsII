using LadderSocial.Application.Common.Models;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Tasks;

public sealed record CreateTaskRequest(
    string Title,
    string? Description,
    Guid TaskCategoryId,
    Guid RecurrenceTypeId,
    DateTime? DueAtUtc,
    bool RequiresProofImage,
    bool ShareWithFriends);

public sealed record TaskListItemResponse(
    Guid Id,
    string Title,
    string CategoryName,
    DateTime? DueAtUtc,
    TaskItemStatus Status,
    bool RequiresProofImage,
    bool ShareWithFriends);

public interface ITaskService
{
    Task<PagedResult<TaskListItemResponse>> GetMyTasksAsync(
        PagedRequest request,
        CancellationToken cancellationToken);

    Task<Guid> CreateAsync(CreateTaskRequest request, CancellationToken cancellationToken);
}
