using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Domain.Entities;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class TaskService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IFileStorageService fileStorageService,
    IRealtimeNotifier realtimeNotifier) : ITaskService
{
    public async Task<PagedResult<TaskListItemResponse>> GetMyTasksAsync(
        TaskListRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var today = DateOnly.FromDateTime(dateTimeProvider.UtcNow);

        var query =
            from task in dbContext.Tasks.AsNoTracking()
            join category in dbContext.TaskCategories.AsNoTracking() on task.TaskCategoryId equals category.Id
            join recurrence in dbContext.RecurrenceTypes.AsNoTracking() on task.RecurrenceTypeId equals recurrence.Id
            where task.OwnerUserId == userId
            select new
            {
                Task = task,
                Category = category,
                Recurrence = recurrence,
                IsCompletedForToday = dbContext.TaskCompletions.Any(completion =>
                    completion.TaskItemId == task.Id &&
                    completion.UserId == userId &&
                    completion.OccurrenceDate == today)
            };

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.Task.Title, $"%{search}%") ||
                (item.Task.Description != null && EF.Functions.Like(item.Task.Description, $"%{search}%")));
        }

        if (request.CategoryId.HasValue)
        {
            query = query.Where(item => item.Task.TaskCategoryId == request.CategoryId.Value);
        }

        if (request.RecurrenceTypeId.HasValue)
        {
            query = query.Where(item => item.Task.RecurrenceTypeId == request.RecurrenceTypeId.Value);
        }

        if (request.Status.HasValue)
        {
            query = query.Where(item => item.Task.Status == request.Status.Value);
        }

        if (request.DueFromUtc.HasValue)
        {
            query = query.Where(item => item.Task.DueAtUtc >= request.DueFromUtc.Value);
        }

        if (request.DueToUtc.HasValue)
        {
            query = query.Where(item => item.Task.DueAtUtc <= request.DueToUtc.Value);
        }

        query = (request.SortBy?.Trim().ToLowerInvariant(), request.SortDirection?.Trim().ToLowerInvariant()) switch
        {
            ("title", "desc") => query.OrderByDescending(item => item.Task.Title),
            ("title", _) => query.OrderBy(item => item.Task.Title),
            ("createdatutc", "asc") => query.OrderBy(item => item.Task.CreatedAtUtc),
            ("createdatutc", _) => query.OrderByDescending(item => item.Task.CreatedAtUtc),
            ("dueatutc", "desc") => query.OrderByDescending(item => item.Task.DueAtUtc),
            _ => query.OrderBy(item => item.Task.DueAtUtc == null)
                .ThenBy(item => item.Task.DueAtUtc)
                .ThenByDescending(item => item.Task.CreatedAtUtc)
        };

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new TaskListItemResponse(
                item.Task.Id,
                item.Task.Title,
                item.Category.Name,
                item.Category.Code,
                item.Recurrence.Name,
                item.Recurrence.Code,
                item.Task.DueAtUtc,
                item.Task.Status,
                item.Task.RequiresProofImage,
                item.Task.ShareWithFriends,
                item.IsCompletedForToday,
                item.Task.CreatedAtUtc))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<TaskListItemResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<TaskDetailResponse> GetMyTaskAsync(Guid id, CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var task = await (
                from item in dbContext.Tasks.AsNoTracking()
                join category in dbContext.TaskCategories.AsNoTracking() on item.TaskCategoryId equals category.Id
                join recurrence in dbContext.RecurrenceTypes.AsNoTracking() on item.RecurrenceTypeId equals recurrence.Id
                where item.Id == id && item.OwnerUserId == userId
                select new
                {
                    Item = item,
                    CategoryName = category.Name,
                    CategoryCode = category.Code,
                    RecurrenceName = recurrence.Name,
                    RecurrenceCode = recurrence.Code
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested task was not found.");

        var recentRows = await GetCompletionQuery(task.Item.Id, userId)
            .Take(10)
            .ToArrayAsync(cancellationToken);
        var recentCompletions = recentRows
            .Select(item => MapCompletion(item.Completion, item.ProofMediaId, item.PostId))
            .ToArray();

        return new TaskDetailResponse(
            task.Item.Id,
            task.Item.Title,
            task.Item.Description,
            task.Item.TaskCategoryId,
            task.CategoryName,
            task.CategoryCode,
            task.Item.RecurrenceTypeId,
            task.RecurrenceName,
            task.RecurrenceCode,
            task.Item.DueAtUtc,
            task.Item.Status,
            task.Item.RequiresProofImage,
            task.Item.ShareWithFriends,
            task.Item.CreatedAtUtc,
            task.Item.UpdatedAtUtc,
            recentCompletions);
    }

    public async Task<TaskDetailResponse> CreateAsync(
        CreateTaskRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var normalized = await ValidateAndNormalizeAsync(
            request.Title,
            request.Description,
            request.TaskCategoryId,
            request.RecurrenceTypeId,
            request.DueAtUtc,
            cancellationToken);

        var entity = new TaskItem
        {
            OwnerUserId = userId,
            Title = normalized.Title,
            Description = normalized.Description,
            TaskCategoryId = request.TaskCategoryId,
            RecurrenceTypeId = request.RecurrenceTypeId,
            DueAtUtc = normalized.DueAtUtc,
            RequiresProofImage = request.RequiresProofImage,
            ShareWithFriends = request.ShareWithFriends,
            Status = TaskItemStatus.Active
        };

        dbContext.Tasks.Add(entity);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetMyTaskAsync(entity.Id, cancellationToken);
    }

    public async Task<TaskDetailResponse> UpdateAsync(
        Guid id,
        UpdateTaskRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var entity = await dbContext.Tasks
            .SingleOrDefaultAsync(item => item.Id == id && item.OwnerUserId == userId, cancellationToken)
            ?? throw new NotFoundException("The requested task was not found.");

        if (entity.Status == TaskItemStatus.Archived)
        {
            throw new BusinessException("An archived task cannot be edited.");
        }

        var normalized = await ValidateAndNormalizeAsync(
            request.Title,
            request.Description,
            request.TaskCategoryId,
            request.RecurrenceTypeId,
            request.DueAtUtc,
            cancellationToken);

        if (request.Status == TaskItemStatus.Completed)
        {
            throw new ValidationException(
                "Task validation failed.",
                new Dictionary<string, string[]>
                {
                    ["status"] = ["Complete a task through the completion action instead of changing its status directly."]
                });
        }

        entity.Title = normalized.Title;
        entity.Description = normalized.Description;
        entity.TaskCategoryId = request.TaskCategoryId;
        entity.RecurrenceTypeId = request.RecurrenceTypeId;
        entity.DueAtUtc = normalized.DueAtUtc;
        entity.RequiresProofImage = request.RequiresProofImage;
        entity.ShareWithFriends = request.ShareWithFriends;
        entity.Status = request.Status;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetMyTaskAsync(entity.Id, cancellationToken);
    }

    public async Task DeleteAsync(Guid id, CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var entity = await dbContext.Tasks
            .SingleOrDefaultAsync(item => item.Id == id && item.OwnerUserId == userId, cancellationToken)
            ?? throw new NotFoundException("The requested task was not found.");

        entity.IsDeleted = true;
        entity.DeletedAtUtc = dateTimeProvider.UtcNow;
        entity.DeletedByUserId = userId;
        entity.Status = TaskItemStatus.Archived;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<TaskCompletionResponse> CompleteAsync(
        Guid id,
        CompleteTaskCommand command,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var now = dateTimeProvider.UtcNow;
        var today = DateOnly.FromDateTime(now);
        var task = await (
                from item in dbContext.Tasks
                join recurrence in dbContext.RecurrenceTypes on item.RecurrenceTypeId equals recurrence.Id
                where item.Id == id && item.OwnerUserId == userId
                select new { Item = item, RecurrenceCode = recurrence.Code })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested task was not found.");

        if (task.Item.Status != TaskItemStatus.Active)
        {
            throw new BusinessException("Only active tasks can be completed.");
        }

        ValidateOccurrenceDate(task.Item, task.RecurrenceCode, command.OccurrenceDate, today);

        var duplicateExists = await dbContext.TaskCompletions.AnyAsync(
            completion => completion.TaskItemId == id &&
                completion.UserId == userId &&
                completion.OccurrenceDate == command.OccurrenceDate,
            cancellationToken);
        if (duplicateExists)
        {
            throw new ConflictException("This task occurrence has already been completed.");
        }

        if (task.Item.RequiresProofImage && command.ProofImage is null)
        {
            throw new ValidationException(
                "Task completion validation failed.",
                new Dictionary<string, string[]>
                {
                    ["proofImage"] = ["This task requires a proof image before it can be completed."]
                });
        }

        StoredFileInfo? storedFile = null;
        if (command.ProofImage is not null)
        {
            storedFile = await fileStorageService.SaveImageAsync(
                $"task-proofs/{now:yyyy/MM}",
                command.ProofImage,
                cancellationToken);
        }

        var occurrenceTime = command.OccurrenceDate == today
            ? TimeOnly.FromDateTime(now)
            : new TimeOnly(12, 0);
        var completion = new TaskCompletion
        {
            TaskItemId = task.Item.Id,
            UserId = userId,
            OccurrenceDate = command.OccurrenceDate,
            CompletedAtUtc = command.OccurrenceDate.ToDateTime(occurrenceTime, DateTimeKind.Utc),
            ScorePoints = 1,
            Note = string.IsNullOrWhiteSpace(command.Note) ? null : command.Note.Trim()
        };
        TaskProofMedia? proof = null;
        Post? post = null;
        var notifications = new List<Notification>();

        try
        {
            var strategy = dbContext.Database.CreateExecutionStrategy();
            await strategy.ExecuteAsync(async () =>
            {
                await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
                dbContext.TaskCompletions.Add(completion);

                if (storedFile is not null)
                {
                    proof = new TaskProofMedia
                    {
                        TaskCompletionId = completion.Id,
                        OwnerUserId = userId,
                        StorageKey = storedFile.StorageKey,
                        MimeType = storedFile.ContentType,
                        SizeBytes = storedFile.Length
                    };
                    dbContext.TaskProofMedia.Add(proof);
                }

                if (task.Item.ShareWithFriends)
                {
                    post = new Post
                    {
                        AuthorUserId = userId,
                        TaskCompletionId = completion.Id,
                        Caption = string.IsNullOrWhiteSpace(command.Caption) ? null : command.Caption.Trim(),
                        IsVisible = true
                    };
                    dbContext.Posts.Add(post);

                    var friendIds = await dbContext.Friendships
                        .Where(item => item.UserId == userId)
                        .Select(item => item.FriendUserId)
                        .ToArrayAsync(cancellationToken);
                    var authorName = await dbContext.UserProfiles
                        .Where(profile => profile.UserId == userId)
                        .Select(profile => profile.FirstName + " " + profile.LastName)
                        .SingleAsync(cancellationToken);

                    notifications.AddRange(friendIds.Select(friendId => new Notification
                    {
                        UserId = friendId,
                        Kind = NotificationKind.TaskCompleted,
                        Title = "A friend completed a task",
                        Body = $"{authorName.Trim()} completed \"{task.Item.Title}\".",
                        RelatedEntityType = "Post",
                        RelatedEntityId = post.Id
                    }));
                    dbContext.Notifications.AddRange(notifications);
                }

                if (string.Equals(task.RecurrenceCode, "none", StringComparison.OrdinalIgnoreCase))
                {
                    task.Item.Status = TaskItemStatus.Completed;
                }

                await dbContext.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
            });
        }
        catch
        {
            if (storedFile is not null)
            {
                await fileStorageService.DeleteIfExistsAsync(storedFile.StorageKey, cancellationToken);
            }

            throw;
        }

        foreach (var notification in notifications)
        {
            await realtimeNotifier.NotifyUserAsync(
                notification.UserId,
                "NotificationChanged",
                new { notification.Id, notification.Title, notification.Body },
                cancellationToken);
        }

        return MapCompletion(completion, proof?.Id, post?.Id);
    }

    public async Task<PagedResult<TaskCompletionResponse>> GetCompletionsAsync(
        Guid id,
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var taskExists = await dbContext.Tasks
            .AsNoTracking()
            .AnyAsync(item => item.Id == id && item.OwnerUserId == userId, cancellationToken);
        if (!taskExists)
        {
            throw new NotFoundException("The requested task was not found.");
        }

        var query = GetCompletionQuery(id, userId);
        var totalCount = await query.CountAsync(cancellationToken);
        var rows = await query
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArrayAsync(cancellationToken);
        var items = rows
            .Select(item => MapCompletion(item.Completion, item.ProofMediaId, item.PostId))
            .ToArray();

        return new PagedResult<TaskCompletionResponse>(items, request.Page, request.PageSize, totalCount);
    }

    private IQueryable<CompletionProjection> GetCompletionQuery(Guid taskId, Guid userId) =>
        from completion in dbContext.TaskCompletions.AsNoTracking()
        join media in dbContext.TaskProofMedia.AsNoTracking()
            on completion.Id equals media.TaskCompletionId into mediaGroup
        from media in mediaGroup.DefaultIfEmpty()
        join post in dbContext.Posts.AsNoTracking()
            on completion.Id equals post.TaskCompletionId into postGroup
        from post in postGroup.DefaultIfEmpty()
        where completion.TaskItemId == taskId && completion.UserId == userId
        orderby completion.CompletedAtUtc descending
        select new CompletionProjection(
            completion,
            media == null ? null : media.Id,
            post == null ? null : post.Id);

    private async Task<NormalizedTaskRequest> ValidateAndNormalizeAsync(
        string title,
        string? description,
        Guid categoryId,
        Guid recurrenceTypeId,
        DateTime? dueAtUtc,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
        var normalizedTitle = title?.Trim() ?? string.Empty;
        var normalizedDescription = string.IsNullOrWhiteSpace(description) ? null : description.Trim();

        if (normalizedTitle.Length is 0 or > 200)
        {
            errors["title"] = ["Title is required and may contain at most 200 characters."];
        }

        if (normalizedDescription?.Length > 2000)
        {
            errors["description"] = ["Description may contain at most 2000 characters."];
        }

        if (!await dbContext.TaskCategories.AnyAsync(
                item => item.Id == categoryId && item.IsActive,
                cancellationToken))
        {
            errors["taskCategoryId"] = ["Select an active task category."];
        }

        if (!await dbContext.RecurrenceTypes.AnyAsync(
                item => item.Id == recurrenceTypeId && item.IsActive,
                cancellationToken))
        {
            errors["recurrenceTypeId"] = ["Select an active recurrence type."];
        }

        DateTime? normalizedDueAtUtc = null;
        if (dueAtUtc.HasValue)
        {
            normalizedDueAtUtc = dueAtUtc.Value.Kind switch
            {
                DateTimeKind.Utc => dueAtUtc.Value,
                DateTimeKind.Local => dueAtUtc.Value.ToUniversalTime(),
                _ => DateTime.SpecifyKind(dueAtUtc.Value, DateTimeKind.Utc)
            };
        }

        if (errors.Count > 0)
        {
            throw new ValidationException("Task validation failed.", errors);
        }

        return new NormalizedTaskRequest(normalizedTitle, normalizedDescription, normalizedDueAtUtc);
    }

    private static void ValidateOccurrenceDate(
        TaskItem task,
        string recurrenceCode,
        DateOnly occurrenceDate,
        DateOnly today)
    {
        var errors = new Dictionary<string, string[]>();
        if (occurrenceDate > today)
        {
            errors["occurrenceDate"] = ["A task cannot be completed for a future date."];
        }

        var anchor = task.DueAtUtc.HasValue
            ? DateOnly.FromDateTime(task.DueAtUtc.Value)
            : DateOnly.FromDateTime(task.CreatedAtUtc);
        if (occurrenceDate < DateOnly.FromDateTime(task.CreatedAtUtc))
        {
            errors["occurrenceDate"] = ["The occurrence date cannot be earlier than the task creation date."];
        }

        switch (recurrenceCode.Trim().ToLowerInvariant())
        {
            case "none":
                break;
            case "daily":
                break;
            case "weekly" when occurrenceDate >= anchor &&
                (occurrenceDate.DayNumber - anchor.DayNumber) % 7 != 0:
                errors["occurrenceDate"] = ["Select a date that matches this task's weekly recurrence."];
                break;
            case "monthly" when occurrenceDate.Day != anchor.Day:
                errors["occurrenceDate"] = ["Select a date that matches this task's monthly recurrence day."];
                break;
        }

        if (errors.Count > 0)
        {
            throw new ValidationException("Task completion validation failed.", errors);
        }
    }

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access tasks.");

    private static TaskCompletionResponse MapCompletion(
        TaskCompletion completion,
        Guid? proofMediaId,
        Guid? postId) =>
        new(
            completion.Id,
            completion.TaskItemId,
            completion.OccurrenceDate,
            completion.CompletedAtUtc,
            completion.Note,
            completion.ScorePoints,
            proofMediaId,
            proofMediaId.HasValue ? $"/api/media/task-proofs/{proofMediaId.Value}" : null,
            postId);

    private sealed record NormalizedTaskRequest(
        string Title,
        string? Description,
        DateTime? DueAtUtc);

    private sealed record CompletionProjection(
        TaskCompletion Completion,
        Guid? ProofMediaId,
        Guid? PostId);
}
