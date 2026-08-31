using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Domain.Constants;
using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Services;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class RecurrenceRuleServiceTests
{
    private readonly RecurrenceRuleService service = new(null!);

    [Fact]
    public void WeeklyRule_RejectsDatesBeforeAnchorAndAcceptsMatchingOccurrences()
    {
        var task = Task(
            createdAtUtc: new DateTime(2026, 8, 1, 10, 0, 0, DateTimeKind.Utc),
            dueAtUtc: new DateTime(2026, 8, 10, 9, 0, 0, DateTimeKind.Utc));
        var businessDate = new DateOnly(2026, 8, 31);

        Assert.False(service.IsCompletionDateAllowed(
            task,
            RecurrenceCodes.Weekly,
            new DateOnly(2026, 8, 3),
            businessDate));
        Assert.True(service.IsCompletionDateAllowed(
            task,
            RecurrenceCodes.Weekly,
            new DateOnly(2026, 8, 17),
            businessDate));
        Assert.False(service.IsCompletionDateAllowed(
            task,
            RecurrenceCodes.Weekly,
            new DateOnly(2026, 8, 18),
            businessDate));

        Assert.Throws<ValidationException>(() => service.ValidateCompletionDate(
            task,
            RecurrenceCodes.Weekly,
            new DateOnly(2026, 8, 3),
            businessDate));
    }

    [Fact]
    public void MonthlyRule_UsesAnchorDayAndNeverAllowsPreCreationDates()
    {
        var task = Task(
            createdAtUtc: new DateTime(2026, 1, 20, 10, 0, 0, DateTimeKind.Utc),
            dueAtUtc: new DateTime(2026, 1, 15, 9, 0, 0, DateTimeKind.Utc));
        var businessDate = new DateOnly(2026, 4, 30);

        Assert.False(service.IsCompletionDateAllowed(
            task,
            RecurrenceCodes.Monthly,
            new DateOnly(2026, 1, 15),
            businessDate));
        Assert.True(service.IsCompletionDateAllowed(
            task,
            RecurrenceCodes.Monthly,
            new DateOnly(2026, 2, 15),
            businessDate));
        Assert.False(service.IsCompletionDateAllowed(
            task,
            RecurrenceCodes.Monthly,
            new DateOnly(2026, 2, 14),
            businessDate));
    }

    [Fact]
    public void AllowedDates_ExcludeCompletedOccurrencesAndFutureDates()
    {
        var task = Task(
            createdAtUtc: new DateTime(2026, 8, 20, 10, 0, 0, DateTimeKind.Utc));
        var businessDate = new DateOnly(2026, 8, 23);
        IReadOnlySet<DateOnly> completed = new HashSet<DateOnly>
        {
            new(2026, 8, 21)
        };

        var result = service.GetAllowedCompletionDates(
            task,
            RecurrenceCodes.Daily,
            businessDate,
            completed);

        var expected = new[]
        {
            new DateOnly(2026, 8, 20),
            new DateOnly(2026, 8, 22),
            new DateOnly(2026, 8, 23)
        };

        Assert.Equal(expected, result);
        Assert.DoesNotContain(result, item => item > businessDate);
    }

    [Fact]
    public void NormalizeSupportedCode_RejectsUnknownSemanticValues()
    {
        Assert.Equal(
            RecurrenceCodes.Weekly,
            service.NormalizeSupportedCode(" WEEKLY "));
        Assert.Throws<ValidationException>(() =>
            service.NormalizeSupportedCode("every-other-day"));
    }

    private static TaskItem Task(DateTime createdAtUtc, DateTime? dueAtUtc = null) => new()
    {
        CreatedAtUtc = createdAtUtc,
        DueAtUtc = dueAtUtc
    };
}
