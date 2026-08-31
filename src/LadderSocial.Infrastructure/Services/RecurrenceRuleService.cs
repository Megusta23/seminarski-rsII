using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Domain.Constants;
using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class RecurrenceRuleService(ApplicationDbContext dbContext) : IRecurrenceRuleService
{
    public string NormalizeSupportedCode(string code, string fieldName = "code")
    {
        var normalized = string.IsNullOrWhiteSpace(code)
            ? string.Empty
            : RecurrenceCodes.Normalize(code);

        if (RecurrenceCodes.IsSupported(normalized))
        {
            return normalized;
        }

        throw new ValidationException(
            "Recurrence validation failed.",
            new Dictionary<string, string[]>
            {
                [fieldName] =
                [
                    $"Select one of the supported recurrence codes: {string.Join(", ", RecurrenceCodes.Supported)}."
                ]
            });
    }

    public DateOnly GetAnchorDate(TaskItem task, string recurrenceCode)
    {
        var normalized = NormalizeSupportedCode(recurrenceCode, "recurrenceTypeId");
        var createdDate = DateOnly.FromDateTime(task.CreatedAtUtc);

        return normalized is RecurrenceCodes.Weekly or RecurrenceCodes.Monthly
            ? task.DueAtUtc.HasValue
                ? DateOnly.FromDateTime(task.DueAtUtc.Value)
                : createdDate
            : createdDate;
    }

    public bool IsScheduledOn(TaskItem task, string recurrenceCode, DateOnly date)
    {
        if (!RecurrenceCodes.IsSupported(recurrenceCode))
        {
            return false;
        }

        var normalized = RecurrenceCodes.Normalize(recurrenceCode);
        var createdDate = DateOnly.FromDateTime(task.CreatedAtUtc);
        var anchor = GetAnchorDate(task, normalized);
        if (date < createdDate)
        {
            return false;
        }

        return normalized switch
        {
            RecurrenceCodes.None => task.DueAtUtc.HasValue
                ? DateOnly.FromDateTime(task.DueAtUtc.Value) == date
                : createdDate == date,
            RecurrenceCodes.Daily => true,
            RecurrenceCodes.Weekly => date >= anchor &&
                (date.DayNumber - anchor.DayNumber) % 7 == 0,
            RecurrenceCodes.Monthly => date >= anchor && date.Day == anchor.Day,
            _ => false
        };
    }

    public bool IsCompletionDateAllowed(
        TaskItem task,
        string recurrenceCode,
        DateOnly occurrenceDate,
        DateOnly businessDate)
    {
        if (!RecurrenceCodes.IsSupported(recurrenceCode) || occurrenceDate > businessDate)
        {
            return false;
        }

        var normalized = RecurrenceCodes.Normalize(recurrenceCode);
        var createdDate = DateOnly.FromDateTime(task.CreatedAtUtc);
        var anchor = GetAnchorDate(task, normalized);
        var earliestDate = normalized is RecurrenceCodes.Weekly or RecurrenceCodes.Monthly
            ? Max(createdDate, anchor)
            : createdDate;

        if (occurrenceDate < earliestDate)
        {
            return false;
        }

        return normalized is RecurrenceCodes.None or RecurrenceCodes.Daily ||
            IsScheduledOn(task, normalized, occurrenceDate);
    }

    public void ValidateCompletionDate(
        TaskItem task,
        string recurrenceCode,
        DateOnly occurrenceDate,
        DateOnly businessDate)
    {
        var normalized = NormalizeSupportedCode(recurrenceCode, "recurrenceTypeId");
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);

        if (occurrenceDate > businessDate)
        {
            errors["occurrenceDate"] = ["A task cannot be completed for a future UTC business date."];
        }

        var createdDate = DateOnly.FromDateTime(task.CreatedAtUtc);
        var anchor = GetAnchorDate(task, normalized);
        var earliestDate = normalized is RecurrenceCodes.Weekly or RecurrenceCodes.Monthly
            ? Max(createdDate, anchor)
            : createdDate;

        if (occurrenceDate < earliestDate)
        {
            errors["occurrenceDate"] = normalized is RecurrenceCodes.Weekly or RecurrenceCodes.Monthly
                ? [$"The occurrence date cannot be earlier than the recurrence anchor ({anchor:yyyy-MM-dd})."]
                : [$"The occurrence date cannot be earlier than the task creation date ({createdDate:yyyy-MM-dd})."];
        }
        else if (normalized == RecurrenceCodes.Weekly && !IsScheduledOn(task, normalized, occurrenceDate))
        {
            errors["occurrenceDate"] = ["Select a date that matches this task's weekly recurrence."];
        }
        else if (normalized == RecurrenceCodes.Monthly && !IsScheduledOn(task, normalized, occurrenceDate))
        {
            errors["occurrenceDate"] = ["Select a date that matches this task's monthly recurrence day."];
        }

        if (errors.Count > 0)
        {
            throw new ValidationException("Task completion validation failed.", errors);
        }
    }

    public IReadOnlyCollection<DateOnly> GetAllowedCompletionDates(
        TaskItem task,
        string recurrenceCode,
        DateOnly businessDate,
        IReadOnlySet<DateOnly>? excludedDates = null)
    {
        var normalized = NormalizeSupportedCode(recurrenceCode, "recurrenceTypeId");
        var createdDate = DateOnly.FromDateTime(task.CreatedAtUtc);
        var anchor = GetAnchorDate(task, normalized);
        var firstDate = normalized is RecurrenceCodes.Weekly or RecurrenceCodes.Monthly
            ? Max(createdDate, anchor)
            : createdDate;

        if (firstDate > businessDate)
        {
            return Array.Empty<DateOnly>();
        }

        var result = new List<DateOnly>();
        for (var date = firstDate; date <= businessDate; date = date.AddDays(1))
        {
            if ((excludedDates is null || !excludedDates.Contains(date)) &&
                IsCompletionDateAllowed(task, normalized, date, businessDate))
            {
                result.Add(date);
            }
        }

        return result;
    }

    public IQueryable<Guid> GetScheduledTaskIds(
        IQueryable<TaskItem> tasks,
        DateOnly date)
    {
        var dateStart = DateTime.SpecifyKind(date.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc);
        var dateEnd = dateStart.AddDays(1);

        return
            from task in tasks
            join recurrence in dbContext.RecurrenceTypes.AsNoTracking()
                on task.RecurrenceTypeId equals recurrence.Id
            where EF.Functions.DateDiffDay(task.CreatedAtUtc, dateStart) >= 0 &&
                (
                    (recurrence.Code == RecurrenceCodes.None &&
                        ((task.DueAtUtc.HasValue &&
                            task.DueAtUtc.Value >= dateStart &&
                            task.DueAtUtc.Value < dateEnd) ||
                         (!task.DueAtUtc.HasValue &&
                            task.CreatedAtUtc >= dateStart &&
                            task.CreatedAtUtc < dateEnd))) ||
                    recurrence.Code == RecurrenceCodes.Daily ||
                    (recurrence.Code == RecurrenceCodes.Weekly &&
                        EF.Functions.DateDiffDay(task.DueAtUtc ?? task.CreatedAtUtc, dateStart) >= 0 &&
                        EF.Functions.DateDiffDay(task.DueAtUtc ?? task.CreatedAtUtc, dateStart) % 7 == 0) ||
                    (recurrence.Code == RecurrenceCodes.Monthly &&
                        EF.Functions.DateDiffDay(task.DueAtUtc ?? task.CreatedAtUtc, dateStart) >= 0 &&
                        (task.DueAtUtc ?? task.CreatedAtUtc).Day == dateStart.Day)
                )
            select task.Id;
    }

    public IQueryable<Guid> GetCompletableTaskIds(
        IQueryable<TaskItem> tasks,
        DateOnly businessDate)
    {
        var dateStart = DateTime.SpecifyKind(
            businessDate.ToDateTime(TimeOnly.MinValue),
            DateTimeKind.Utc);

        return
            from task in tasks
            join recurrence in dbContext.RecurrenceTypes.AsNoTracking()
                on task.RecurrenceTypeId equals recurrence.Id
            where EF.Functions.DateDiffDay(task.CreatedAtUtc, dateStart) >= 0 &&
                (
                    recurrence.Code == RecurrenceCodes.None ||
                    recurrence.Code == RecurrenceCodes.Daily ||
                    (recurrence.Code == RecurrenceCodes.Weekly &&
                        EF.Functions.DateDiffDay(task.DueAtUtc ?? task.CreatedAtUtc, dateStart) >= 0 &&
                        EF.Functions.DateDiffDay(task.DueAtUtc ?? task.CreatedAtUtc, dateStart) % 7 == 0) ||
                    (recurrence.Code == RecurrenceCodes.Monthly &&
                        EF.Functions.DateDiffDay(task.DueAtUtc ?? task.CreatedAtUtc, dateStart) >= 0 &&
                        (task.DueAtUtc ?? task.CreatedAtUtc).Day == dateStart.Day)
                )
            select task.Id;
    }

    private static DateOnly Max(DateOnly left, DateOnly right) =>
        left >= right ? left : right;
}
