using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Reports;
using LadderSocial.Infrastructure.Identity;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class ReportService(
    ApplicationDbContext dbContext,
    UserManager<AppUser> userManager,
    IDateTimeProvider dateTimeProvider) : IReportService
{
    public async Task<FileContentResult> GenerateActivityReportAsync(
        DateOnly fromDate,
        DateOnly toDate,
        CancellationToken cancellationToken)
    {
        if (fromDate > toDate)
        {
            throw new ValidationException(
                "Report validation failed.",
                new Dictionary<string, string[]>
                {
                    ["fromDate"] = ["The start date must not be later than the end date."]
                });
        }

        if (toDate.DayNumber - fromDate.DayNumber > 366)
        {
            throw new ValidationException(
                "Report validation failed.",
                new Dictionary<string, string[]>
                {
                    ["toDate"] = ["An activity report may cover at most 366 days."]
                });
        }

        var start = fromDate.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var end = toDate.AddDays(1).ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var newUsers = await dbContext.Users.CountAsync(
            item => item.CreatedAtUtc >= start && item.CreatedAtUtc < end,
            cancellationToken);
        var tasksCreated = await dbContext.Tasks.IgnoreQueryFilters().CountAsync(
            item => item.CreatedAtUtc >= start && item.CreatedAtUtc < end,
            cancellationToken);
        var completions = await dbContext.TaskCompletions.CountAsync(
            item => item.CompletedAtUtc >= start && item.CompletedAtUtc < end,
            cancellationToken);
        var posts = await dbContext.Posts.IgnoreQueryFilters().CountAsync(
            item => item.CreatedAtUtc >= start && item.CreatedAtUtc < end,
            cancellationToken);
        var friendRequests = await dbContext.FriendRequests.CountAsync(
            item => item.CreatedAtUtc >= start && item.CreatedAtUtc < end,
            cancellationToken);
        var messages = await dbContext.Messages.IgnoreQueryFilters().CountAsync(
            item => item.SentAtUtc >= start && item.SentAtUtc < end,
            cancellationToken);
        var topRows = await dbContext.TaskCompletions
            .AsNoTracking()
            .Where(item => item.CompletedAtUtc >= start && item.CompletedAtUtc < end)
            .GroupBy(item => item.UserId)
            .Select(group => new
            {
                UserId = group.Key,
                Count = group.Count(),
                Score = group.Sum(item => item.ScorePoints)
            })
            .OrderByDescending(item => item.Score)
            .Take(10)
            .ToArrayAsync(cancellationToken);
        var topIds = topRows.Select(item => item.UserId).ToArray();
        var names = await dbContext.Users
            .AsNoTracking()
            .Where(item => topIds.Contains(item.Id))
            .ToDictionaryAsync(item => item.Id, item => item.DisplayName, cancellationToken);
        var lines = new List<string>
        {
            $"Generated at (UTC): {dateTimeProvider.UtcNow:yyyy-MM-dd HH:mm:ss}",
            $"Reporting period: {fromDate:yyyy-MM-dd} to {toDate:yyyy-MM-dd}",
            string.Empty,
            $"New users: {newUsers}",
            $"Tasks created: {tasksCreated}",
            $"Tasks completed: {completions}",
            $"Shared posts: {posts}",
            $"Friend requests: {friendRequests}",
            $"Chat messages: {messages}",
            string.Empty,
            "Top users by completion score:"
        };
        if (topRows.Length == 0)
        {
            lines.Add("No task completions were recorded in the selected period.");
        }
        else
        {
            lines.AddRange(topRows.Select((item, index) =>
                $"{index + 1}. {names.GetValueOrDefault(item.UserId, item.UserId.ToString())} - " +
                $"{item.Count} completions, {item.Score} points"));
        }

        var bytes = SimplePdfDocument.Create("Ladder Social - Application Activity Report", lines);
        return new FileContentResult(
            bytes,
            "application/pdf",
            $"ladder-social-activity-{fromDate:yyyyMMdd}-{toDate:yyyyMMdd}.pdf");
    }

    public async Task<FileContentResult> GenerateUserReportAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString())
            ?? throw new NotFoundException("The requested user was not found.");
        var profile = await (
                from item in dbContext.UserProfiles.AsNoTracking()
                join city in dbContext.Cities.AsNoTracking() on item.CityId equals (Guid?)city.Id into cities
                from city in cities.DefaultIfEmpty()
                where item.UserId == userId
                select new
                {
                    item.FirstName,
                    item.LastName,
                    item.Bio,
                    CityName = city == null ? null : city.Name,
                    item.DateOfBirth
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested user profile was not found.");
        var roles = await userManager.GetRolesAsync(user);
        var friendCount = await dbContext.Friendships.CountAsync(item => item.UserId == userId, cancellationToken);
        var taskCount = await dbContext.Tasks.CountAsync(item => item.OwnerUserId == userId, cancellationToken);
        var completionCount = await dbContext.TaskCompletions.CountAsync(item => item.UserId == userId, cancellationToken);
        var postCount = await dbContext.Posts.CountAsync(item => item.AuthorUserId == userId, cancellationToken);
        var recentCompletions = await (
                from completion in dbContext.TaskCompletions.AsNoTracking()
                join task in dbContext.Tasks.IgnoreQueryFilters().AsNoTracking()
                    on completion.TaskItemId equals task.Id
                where completion.UserId == userId
                orderby completion.CompletedAtUtc descending
                select new
                {
                    task.Title,
                    completion.CompletedAtUtc,
                    completion.ScorePoints
                })
            .Take(20)
            .ToArrayAsync(cancellationToken);
        var lines = new List<string>
        {
            $"Generated at (UTC): {dateTimeProvider.UtcNow:yyyy-MM-dd HH:mm:ss}",
            $"User: {user.DisplayName}",
            $"Email: {user.Email}",
            $"Active: {(user.IsActive ? "Yes" : "No")}",
            $"Roles: {string.Join(", ", roles)}",
            $"Profile name: {profile.FirstName} {profile.LastName}",
            $"City: {profile.CityName ?? "Not selected"}",
            $"Date of birth: {(profile.DateOfBirth.HasValue ? profile.DateOfBirth.Value.ToString("yyyy-MM-dd") : "Not provided")}",
            $"Biography: {profile.Bio ?? "Not provided"}",
            string.Empty,
            $"Friends: {friendCount}",
            $"Tasks: {taskCount}",
            $"Task completions: {completionCount}",
            $"Shared posts: {postCount}",
            string.Empty,
            "Recent task completions:"
        };
        if (recentCompletions.Length == 0)
        {
            lines.Add("No task completions have been recorded.");
        }
        else
        {
            lines.AddRange(recentCompletions.Select(item =>
                $"{item.CompletedAtUtc:yyyy-MM-dd HH:mm} - {item.Title} ({item.ScorePoints} point(s))"));
        }

        var bytes = SimplePdfDocument.Create("Ladder Social - User Activity Report", lines);
        return new FileContentResult(
            bytes,
            "application/pdf",
            $"ladder-social-user-{userId:N}.pdf");
    }
}
