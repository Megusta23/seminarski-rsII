using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Infrastructure.Services;

public sealed class TaskStateMachine : ITaskStateMachine
{
    private static readonly TaskItemStatus[] EditableStatuses =
    [
        TaskItemStatus.Active,
        TaskItemStatus.Cancelled,
        TaskItemStatus.Archived
    ];

    public bool CanEdit(TaskItemStatus status) =>
        status is TaskItemStatus.Active or TaskItemStatus.Cancelled;

    public bool CanComplete(TaskItemStatus status) => status == TaskItemStatus.Active;

    public IReadOnlyCollection<TaskItemStatus> GetAllowedEditStatuses(
        TaskItemStatus currentStatus)
    {
        ValidateDefinedStatus(currentStatus);
        return CanEdit(currentStatus)
            ? EditableStatuses
            : Array.Empty<TaskItemStatus>();
    }

    public void ValidateDefinedStatus(
        TaskItemStatus status,
        string fieldName = "status")
    {
        if (Enum.IsDefined(typeof(TaskItemStatus), status))
        {
            return;
        }

        throw new ValidationException(
            "Task status validation failed.",
            new Dictionary<string, string[]>
            {
                [fieldName] = ["Select a supported task status."]
            });
    }

    public void EnsureCanEdit(TaskItemStatus currentStatus)
    {
        ValidateDefinedStatus(currentStatus);

        if (currentStatus == TaskItemStatus.Completed)
        {
            throw new BusinessException(
                "A completed task is terminal and cannot be edited. Archive or delete it instead.");
        }

        if (currentStatus == TaskItemStatus.Archived)
        {
            throw new BusinessException("An archived task cannot be edited.");
        }
    }

    public void EnsureEditTransition(
        TaskItemStatus currentStatus,
        TaskItemStatus requestedStatus)
    {
        ValidateDefinedStatus(currentStatus);
        ValidateDefinedStatus(requestedStatus);
        EnsureCanEdit(currentStatus);

        if (requestedStatus == TaskItemStatus.Completed)
        {
            throw new ValidationException(
                "Task status validation failed.",
                new Dictionary<string, string[]>
                {
                    ["status"] =
                    [
                        "Complete a task through the completion action instead of changing its status directly."
                    ]
                });
        }

        if (!EditableStatuses.Contains(requestedStatus))
        {
            throw new ValidationException(
                "Task status validation failed.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["The requested task status transition is not supported."]
                });
        }
    }
}
