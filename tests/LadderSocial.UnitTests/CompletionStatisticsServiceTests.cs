using LadderSocial.Infrastructure.Services;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class CompletionStatisticsServiceTests
{
    [Fact]
    public void CurrentStreak_HasNoArbitraryThreeHundredSixtySixDayCap()
    {
        var businessDate = new DateOnly(2026, 8, 31);
        var dates = Enumerable.Range(0, 500)
            .Select(offset => businessDate.AddDays(-offset));

        var result = CompletionStatisticsService.CalculateCurrentStreak(
            dates,
            businessDate);

        Assert.Equal(500, result);
    }

    [Fact]
    public void CurrentStreak_RemainsActiveUntilCurrentDayEnds()
    {
        var businessDate = new DateOnly(2026, 8, 31);
        var dates = new[]
        {
            businessDate.AddDays(-1),
            businessDate.AddDays(-2),
            businessDate.AddDays(-3)
        };

        var result = CompletionStatisticsService.CalculateCurrentStreak(
            dates,
            businessDate);

        Assert.Equal(3, result);
    }

    [Fact]
    public void CurrentStreak_StopsAtFirstMissingOccurrenceDate()
    {
        var businessDate = new DateOnly(2026, 8, 31);
        var dates = new[]
        {
            businessDate,
            businessDate.AddDays(-1),
            businessDate.AddDays(-3)
        };

        var result = CompletionStatisticsService.CalculateCurrentStreak(
            dates,
            businessDate);

        Assert.Equal(2, result);
    }
}
