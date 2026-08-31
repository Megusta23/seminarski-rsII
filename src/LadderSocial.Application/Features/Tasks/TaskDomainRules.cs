using LadderSocial.Domain.Entities;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Tasks;

public sealed record CompletionDateOptionsResponse(
    DateOnly BusinessDate,
    DateOnly RecurrenceAnchorDate,
    string RecurrenceCode,
    IReadOnlyCollection<DateOnly> AllowedDates);

public sealed record UserCompletionAggregate(
    Guid UserId,
    int CompletionCount,
    int Score);

public interface IRecurrenceRuleService
{
    string NormalizeSupportedCode(string code, string fieldName = "code");

    DateOnly GetAnchorDate(TaskItem task, string recurrenceCode);

    bool IsScheduledOn(TaskItem task, string recurrenceCode, DateOnly date);

    bool IsCompletionDateAllowed(
        TaskItem task,
        string recurrenceCode,
        DateOnly occurrenceDate,
        DateOnly businessDate);

    void ValidateCompletionDate(
        TaskItem task,
        string recurrenceCode,
        DateOnly occurrenceDate,
        DateOnly businessDate);

    IReadOnlyCollection<DateOnly> GetAllowedCompletionDates(
        TaskItem task,
        string recurrenceCode,
        DateOnly businessDate,
        IReadOnlySet<DateOnly>? excludedDates = null);

    IQueryable<Guid> GetScheduledTaskIds(
        IQueryable<TaskItem> tasks,
        DateOnly date);

    IQueryable<Guid> GetCompletableTaskIds(
        IQueryable<TaskItem> tasks,
        DateOnly businessDate);
}

public interface ITaskStateMachine
{
    bool CanEdit(TaskItemStatus status);

    bool CanComplete(TaskItemStatus status);

    IReadOnlyCollection<TaskItemStatus> GetAllowedEditStatuses(
        TaskItemStatus currentStatus);

    void ValidateDefinedStatus(
        TaskItemStatus status,
        string fieldName = "status");

    void EnsureCanEdit(TaskItemStatus currentStatus);

    void EnsureEditTransition(
        TaskItemStatus currentStatus,
        TaskItemStatus requestedStatus);
}

public interface ICompletionStatisticsService
{
    Task<int> GetTotalCompletionCountAsync(
        Guid userId,
        CancellationToken cancellationToken);

    Task<IReadOnlyDictionary<Guid, int>> GetTotalCompletionCountsAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken);

    Task<int> GetCurrentStreakAsync(
        Guid userId,
        DateOnly businessDate,
        CancellationToken cancellationToken);

    Task<IReadOnlyDictionary<Guid, int>> GetCurrentStreaksAsync(
        IReadOnlyCollection<Guid> userIds,
        DateOnly businessDate,
        CancellationToken cancellationToken);

    Task<int> GetCompletionCountAsync(
        DateOnly fromDate,
        DateOnly toDate,
        CancellationToken cancellationToken);

    Task<IReadOnlyDictionary<Guid, int>> GetScoresAsync(
        IReadOnlyCollection<Guid> userIds,
        DateOnly fromDate,
        DateOnly toDate,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<UserCompletionAggregate>> GetTopUsersAsync(
        DateOnly? fromDate,
        DateOnly? toDate,
        int take,
        CancellationToken cancellationToken);
}
