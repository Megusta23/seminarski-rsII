using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Common.Security;
using LadderSocial.Domain.Entities;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace LadderSocial.Infrastructure.Persistence.Seed;

public sealed class DemoDataSeeder(
    ApplicationDbContext dbContext,
    UserManager<AppUser> userManager,
    IDateTimeProvider dateTimeProvider,
    IOptions<FileStorageOptions> fileStorageOptions,
    IConfiguration configuration,
    ILogger<DemoDataSeeder> logger)
{
    private static readonly Guid SeedMarkerId = DemoSeedIds.For("marker:v1");
    private readonly FileStorageOptions _fileStorageOptions = fileStorageOptions.Value;

    public async Task SeedAsync(CancellationToken cancellationToken)
    {
        if (!IsEnabled(configuration["SEED_DEMO_DATA"]))
        {
            logger.LogInformation("Demo data seeding is disabled by SEED_DEMO_DATA.");
            return;
        }

        await EnsureSeedAssetFilesAsync(cancellationToken);

        if (await dbContext.AuditLogs.AnyAsync(item => item.Id == SeedMarkerId, cancellationToken))
        {
            logger.LogInformation("Demo data is already initialized; startup seeding was skipped.");
            return;
        }

        var now = dateTimeProvider.UtcNow;
        var references = await EnsureReferenceDataAsync(cancellationToken);
        var users = await EnsureUsersAsync(references.CitiesByName, now, cancellationToken);
        await EnsureFriendshipsAsync(users, cancellationToken);
        var requests = await EnsureFriendRequestsAsync(users, cancellationToken);
        var tasks = await EnsureTasksAsync(users, references, now, cancellationToken);
        var seededContent = await EnsureCompletionsPostsAndProofsAsync(
            users,
            tasks,
            now,
            cancellationToken);
        await EnsurePostViewsAsync(users, seededContent.PostByTaskKey, now, cancellationToken);
        var conversations = await EnsureConversationsAsync(users, now, cancellationToken);
        await EnsureNotificationsAsync(
            users,
            requests,
            seededContent.PostByTaskKey,
            conversations,
            now,
            cancellationToken);
        await EnsureRecommendationLogsAsync(users, now, cancellationToken);

        if (!await dbContext.AuditLogs.AnyAsync(item => item.Id == SeedMarkerId, cancellationToken))
        {
            dbContext.AuditLogs.Add(new AuditLog
            {
                Id = SeedMarkerId,
                Action = "DemoDataSeeded",
                EntityName = "Database",
                EntityId = "ladder-social-demo-v1",
                DetailsJson = "{\"seedDemoData\":true,\"version\":1}",
                CreatedAtUtc = now
            });
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        logger.LogInformation(
            "Demo data initialization completed with {UserCount} mobile users and {TaskCount} tasks.",
            users.Count,
            tasks.Count);
    }

    private async Task<ReferenceLookup> EnsureReferenceDataAsync(
        CancellationToken cancellationToken)
    {
        var bosnia = await dbContext.Countries
            .SingleOrDefaultAsync(item => item.IsoCode == "BIH", cancellationToken);
        if (bosnia is null)
        {
            bosnia = new Country
            {
                Id = DemoSeedIds.For("country:bih"),
                Name = "Bosnia and Herzegovina",
                IsoCode = "BIH",
                SortOrder = 10,
                IsActive = true
            };
            dbContext.Countries.Add(bosnia);
        }

        var croatia = await EnsureCountryAsync(
            DemoSeedIds.For("country:hrv"),
            "Croatia",
            "HRV",
            20,
            cancellationToken);
        var serbia = await EnsureCountryAsync(
            DemoSeedIds.For("country:srb"),
            "Serbia",
            "SRB",
            30,
            cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        await EnsureTaskCategoryAsync("creative", "Creative", 10, cancellationToken);
        await EnsureTaskCategoryAsync("social", "Social", 20, cancellationToken);
        await EnsureTaskCategoryAsync("self-care", "Self-care", 30, cancellationToken);
        await EnsureTaskCategoryAsync("work", "Work", 40, cancellationToken);
        await EnsureRecurrenceTypeAsync("none", "Does not repeat", 10, cancellationToken);
        await EnsureRecurrenceTypeAsync("daily", "Daily", 20, cancellationToken);
        await EnsureRecurrenceTypeAsync("weekly", "Weekly", 30, cancellationToken);
        await EnsureRecurrenceTypeAsync("monthly", "Monthly", 40, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        await EnsureCityAsync(bosnia.Id, "Sarajevo", 10, cancellationToken);
        await EnsureCityAsync(bosnia.Id, "Mostar", 20, cancellationToken);
        await EnsureCityAsync(bosnia.Id, "Tuzla", 30, cancellationToken);
        await EnsureCityAsync(bosnia.Id, "Zenica", 40, cancellationToken);
        await EnsureCityAsync(bosnia.Id, "Banja Luka", 50, cancellationToken);
        await EnsureCityAsync(croatia.Id, "Zagreb", 10, cancellationToken);
        await EnsureCityAsync(serbia.Id, "Belgrade", 10, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        var categoryRows = await dbContext.TaskCategories
            .ToArrayAsync(cancellationToken);
        var recurrenceRows = await dbContext.RecurrenceTypes
            .ToArrayAsync(cancellationToken);
        var cityRows = await dbContext.Cities
            .ToArrayAsync(cancellationToken);

        return new ReferenceLookup(
            categoryRows.ToDictionary(item => item.Code, StringComparer.OrdinalIgnoreCase),
            recurrenceRows.ToDictionary(item => item.Code, StringComparer.OrdinalIgnoreCase),
            cityRows.ToDictionary(item => item.Name, StringComparer.OrdinalIgnoreCase));
    }

    private async Task<Country> EnsureCountryAsync(
        Guid id,
        string name,
        string isoCode,
        int sortOrder,
        CancellationToken cancellationToken)
    {
        var country = await dbContext.Countries
            .SingleOrDefaultAsync(item => item.IsoCode == isoCode, cancellationToken);
        if (country is not null)
        {
            return country;
        }

        country = new Country
        {
            Id = id,
            Name = name,
            IsoCode = isoCode,
            SortOrder = sortOrder,
            IsActive = true
        };
        dbContext.Countries.Add(country);
        return country;
    }

    private async Task EnsureTaskCategoryAsync(
        string code,
        string name,
        int sortOrder,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.TaskCategories.AnyAsync(
            item => item.Code == code,
            cancellationToken);
        if (exists)
        {
            return;
        }

        dbContext.TaskCategories.Add(new TaskCategory
        {
            Id = DemoSeedIds.For($"task-category:{code}"),
            Code = code,
            Name = name,
            SortOrder = sortOrder,
            IsActive = true
        });
    }

    private async Task EnsureRecurrenceTypeAsync(
        string code,
        string name,
        int sortOrder,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.RecurrenceTypes.AnyAsync(
            item => item.Code == code,
            cancellationToken);
        if (exists)
        {
            return;
        }

        dbContext.RecurrenceTypes.Add(new RecurrenceType
        {
            Id = DemoSeedIds.For($"recurrence-type:{code}"),
            Code = code,
            Name = name,
            SortOrder = sortOrder,
            IsActive = true
        });
    }

    private async Task EnsureCityAsync(
        Guid countryId,
        string name,
        int sortOrder,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.Cities.AnyAsync(
            item => item.CountryId == countryId && item.Name == name,
            cancellationToken);
        if (exists)
        {
            return;
        }

        dbContext.Cities.Add(new City
        {
            Id = DemoSeedIds.For($"city:{countryId:N}:{name.ToLowerInvariant()}"),
            CountryId = countryId,
            Name = name,
            SortOrder = sortOrder,
            IsActive = true
        });
    }

    private async Task<Dictionary<string, AppUser>> EnsureUsersAsync(
        IReadOnlyDictionary<string, City> citiesByName,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var password = configuration["SEED_MOBILE_PASSWORD"];
        if (string.IsNullOrWhiteSpace(password))
        {
            throw new InvalidOperationException(
                "SEED_MOBILE_PASSWORD must be configured when SEED_DEMO_DATA is enabled.");
        }

        var mobileEmail = configuration["SEED_MOBILE_EMAIL"];
        if (string.IsNullOrWhiteSpace(mobileEmail))
        {
            throw new InvalidOperationException(
                "SEED_MOBILE_EMAIL must be configured when SEED_DEMO_DATA is enabled.");
        }

        var users = new Dictionary<string, AppUser>(StringComparer.OrdinalIgnoreCase);
        var mainSpec = new DemoUserSpec(
            "mobile",
            mobileEmail.Trim(),
            "Hasan",
            "Brkic",
            "Building productive routines and sharing progress with friends.",
            "hasan.png",
            "Mostar",
            new DateOnly(2000, 5, 18),
            120);

        users[mainSpec.Key] = await EnsureUserAsync(
            mainSpec,
            password,
            citiesByName,
            now,
            isPrimaryMobileUser: true,
            cancellationToken);

        foreach (var spec in DemoSeedCatalog.Users)
        {
            users[spec.Key] = await EnsureUserAsync(
                spec,
                password,
                citiesByName,
                now,
                isPrimaryMobileUser: false,
                cancellationToken);
        }

        return users;
    }

    private async Task<AppUser> EnsureUserAsync(
        DemoUserSpec spec,
        string password,
        IReadOnlyDictionary<string, City> citiesByName,
        DateTime now,
        bool isPrimaryMobileUser,
        CancellationToken cancellationToken)
    {
        var user = await userManager.FindByEmailAsync(spec.Email);
        var created = user is null;
        if (user is null)
        {
            user = new AppUser
            {
                Id = DemoSeedIds.For($"user:{spec.Key}"),
                Email = spec.Email,
                UserName = spec.Email,
                EmailConfirmed = true,
                DisplayName = $"{spec.FirstName} {spec.LastName}",
                CreatedAtUtc = now.AddDays(-spec.CreatedDaysAgo),
                IsActive = true,
                LockoutEnabled = true
            };
            EnsureSucceeded(
                await userManager.CreateAsync(user, password),
                $"creating demo user {spec.Email}");
        }
        else
        {
            var changed = false;
            if (!user.IsActive)
            {
                user.IsActive = true;
                changed = true;
            }

            if (!user.EmailConfirmed)
            {
                user.EmailConfirmed = true;
                changed = true;
            }

            if (!user.LockoutEnabled)
            {
                user.LockoutEnabled = true;
                changed = true;
            }

            if (isPrimaryMobileUser &&
                (string.IsNullOrWhiteSpace(user.DisplayName) || user.DisplayName == "Mobile User"))
            {
                user.DisplayName = $"{spec.FirstName} {spec.LastName}";
                changed = true;
            }

            if (isPrimaryMobileUser && user.CreatedAtUtc > now.AddDays(-30))
            {
                user.CreatedAtUtc = now.AddDays(-spec.CreatedDaysAgo);
                changed = true;
            }

            if (changed)
            {
                EnsureSucceeded(
                    await userManager.UpdateAsync(user),
                    $"updating demo user {spec.Email}");
            }
        }

        if (!await userManager.IsInRoleAsync(user, RoleNames.User))
        {
            EnsureSucceeded(
                await userManager.AddToRoleAsync(user, RoleNames.User),
                $"assigning User role to {spec.Email}");
        }

        var profile = await dbContext.UserProfiles
            .IgnoreQueryFilters()
            .SingleOrDefaultAsync(item => item.UserId == user.Id, cancellationToken);
        if (profile is null)
        {
            profile = new UserProfile
            {
                Id = DemoSeedIds.For($"profile:{spec.Key}"),
                UserId = user.Id,
                FirstName = spec.FirstName,
                LastName = spec.LastName,
                Bio = spec.Bio,
                AvatarStorageKey = AvatarStorageKey(spec.AvatarAsset),
                CityId = citiesByName[spec.CityName].Id,
                DateOfBirth = spec.DateOfBirth
            };
            dbContext.UserProfiles.Add(profile);
        }
        else
        {
            if (profile.IsDeleted)
            {
                profile.IsDeleted = false;
                profile.DeletedAtUtc = null;
                profile.DeletedByUserId = null;
            }

            if (created || (isPrimaryMobileUser && profile.FirstName == "Mobile" && profile.LastName == "User"))
            {
                profile.FirstName = spec.FirstName;
                profile.LastName = spec.LastName;
                profile.Bio = spec.Bio;
                profile.CityId = citiesByName[spec.CityName].Id;
                profile.DateOfBirth = spec.DateOfBirth;
            }

            profile.AvatarStorageKey ??= AvatarStorageKey(spec.AvatarAsset);
            profile.Bio ??= spec.Bio;
            profile.CityId ??= citiesByName[spec.CityName].Id;
            profile.DateOfBirth ??= spec.DateOfBirth;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return user;
    }

    private async Task EnsureFriendshipsAsync(
        IReadOnlyDictionary<string, AppUser> users,
        CancellationToken cancellationToken)
    {
        foreach (var (leftKey, rightKey) in DemoSeedCatalog.Friendships)
        {
            var left = users[leftKey];
            var right = users[rightKey];
            await EnsureFriendshipDirectionAsync(left.Id, right.Id, cancellationToken);
            await EnsureFriendshipDirectionAsync(right.Id, left.Id, cancellationToken);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureFriendshipDirectionAsync(
        Guid userId,
        Guid friendUserId,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.Friendships.AnyAsync(
            item => item.UserId == userId && item.FriendUserId == friendUserId,
            cancellationToken);
        if (exists)
        {
            return;
        }

        dbContext.Friendships.Add(new Friendship
        {
            Id = DemoSeedIds.For($"friendship:{userId:N}:{friendUserId:N}"),
            UserId = userId,
            FriendUserId = friendUserId
        });
    }

    private async Task<Dictionary<string, FriendRequest>> EnsureFriendRequestsAsync(
        IReadOnlyDictionary<string, AppUser> users,
        CancellationToken cancellationToken)
    {
        var requests = new Dictionary<string, FriendRequest>(StringComparer.OrdinalIgnoreCase);
        foreach (var spec in DemoSeedCatalog.FriendRequests)
        {
            var sender = users[spec.SenderKey];
            var receiver = users[spec.ReceiverKey];
            var key = $"{spec.SenderKey}-{spec.ReceiverKey}";
            var request = await dbContext.FriendRequests
                .SingleOrDefaultAsync(
                    item => item.SenderUserId == sender.Id &&
                        item.ReceiverUserId == receiver.Id &&
                        item.Status == FriendRequestStatus.Pending,
                    cancellationToken);
            if (request is null)
            {
                request = new FriendRequest
                {
                    Id = DemoSeedIds.For($"friend-request:{key}"),
                    SenderUserId = sender.Id,
                    ReceiverUserId = receiver.Id,
                    Status = FriendRequestStatus.Pending
                };
                dbContext.FriendRequests.Add(request);
            }

            requests[key] = request;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return requests;
    }

    private async Task<Dictionary<string, TaskItem>> EnsureTasksAsync(
        IReadOnlyDictionary<string, AppUser> users,
        ReferenceLookup references,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(now);
        var tasks = new Dictionary<string, TaskItem>(StringComparer.OrdinalIgnoreCase);
        foreach (var spec in DemoSeedCatalog.Tasks)
        {
            var id = DemoSeedIds.For($"task:{spec.Key}");
            var task = await dbContext.Tasks
                .IgnoreQueryFilters()
                .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
            if (task is null)
            {
                var dueAtUtc = GetDueAtUtc(spec, today);
                task = new TaskItem
                {
                    Id = id,
                    OwnerUserId = users[spec.OwnerKey].Id,
                    TaskCategoryId = references.CategoriesByCode[spec.CategoryCode].Id,
                    RecurrenceTypeId = references.RecurrenceByCode[spec.RecurrenceCode].Id,
                    Title = spec.Title,
                    Description = spec.Description,
                    DueAtUtc = dueAtUtc,
                    Status = TaskItemStatus.Active,
                    RequiresProofImage = spec.RequiresProof,
                    ShareWithFriends = spec.ShareWithFriends
                };
                dbContext.Tasks.Add(task);
            }

            tasks[spec.Key] = task;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return tasks;
    }

    private async Task<SeededContent> EnsureCompletionsPostsAndProofsAsync(
        IReadOnlyDictionary<string, AppUser> users,
        IReadOnlyDictionary<string, TaskItem> tasks,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(now);
        var taskSpecs = DemoSeedCatalog.Tasks.ToDictionary(
            item => item.Key,
            StringComparer.OrdinalIgnoreCase);
        var postByTaskKey = new Dictionary<string, Post>(StringComparer.OrdinalIgnoreCase);
        foreach (var spec in DemoSeedCatalog.Completions)
        {
            var task = tasks[spec.TaskKey];
            var occurrenceDate = today.AddDays(spec.DayOffset);
            var completion = await dbContext.TaskCompletions
                .SingleOrDefaultAsync(
                    item => item.TaskItemId == task.Id &&
                        item.UserId == task.OwnerUserId &&
                        item.OccurrenceDate == occurrenceDate,
                    cancellationToken);
            if (completion is null)
            {
                completion = new TaskCompletion
                {
                    Id = DemoSeedIds.For($"completion:{spec.TaskKey}:{occurrenceDate:yyyy-MM-dd}"),
                    TaskItemId = task.Id,
                    UserId = task.OwnerUserId,
                    OccurrenceDate = occurrenceDate,
                    CompletedAtUtc = GetCompletedAtUtc(occurrenceDate, spec.Hour, now),
                    ScorePoints = 1,
                    Note = spec.Note
                };
                dbContext.TaskCompletions.Add(completion);
            }

            if (string.Equals(
                    taskSpecs[spec.TaskKey].RecurrenceCode,
                    "none",
                    StringComparison.OrdinalIgnoreCase))
            {
                task.Status = TaskItemStatus.Completed;
            }

            if (spec.ProofAsset is not null)
            {
                var proof = await dbContext.TaskProofMedia
                    .SingleOrDefaultAsync(item => item.TaskCompletionId == completion.Id, cancellationToken);
                if (proof is null)
                {
                    var storageKey = ProofStorageKey(spec.ProofAsset);
                    proof = new TaskProofMedia
                    {
                        Id = DemoSeedIds.For($"proof:{spec.TaskKey}:{occurrenceDate:yyyy-MM-dd}"),
                        TaskCompletionId = completion.Id,
                        OwnerUserId = task.OwnerUserId,
                        StorageKey = storageKey,
                        MimeType = "image/png",
                        SizeBytes = GetSeedFileSize(storageKey)
                    };
                    dbContext.TaskProofMedia.Add(proof);
                }
            }

            if (task.ShareWithFriends)
            {
                var post = await dbContext.Posts
                    .IgnoreQueryFilters()
                    .SingleOrDefaultAsync(item => item.TaskCompletionId == completion.Id, cancellationToken);
                if (post is null)
                {
                    post = new Post
                    {
                        Id = DemoSeedIds.For($"post:{spec.TaskKey}:{occurrenceDate:yyyy-MM-dd}"),
                        AuthorUserId = task.OwnerUserId,
                        TaskCompletionId = completion.Id,
                        Caption = spec.Caption,
                        IsVisible = spec.PostVisible,
                        IsHighlighted = spec.Highlight && spec.ProofAsset is not null && spec.PostVisible,
                        HighlightedAtUtc = spec.Highlight && spec.ProofAsset is not null && spec.PostVisible
                            ? completion.CompletedAtUtc.AddMinutes(5)
                            : null
                    };
                    dbContext.Posts.Add(post);
                }

                if (spec.DayOffset == 0 || spec.Highlight)
                {
                    postByTaskKey[spec.TaskKey] = post;
                }
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return new SeededContent(postByTaskKey);
    }

    private async Task EnsurePostViewsAsync(
        IReadOnlyDictionary<string, AppUser> users,
        IReadOnlyDictionary<string, Post> postByTaskKey,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var mobileUserId = users["mobile"].Id;
        foreach (var taskKey in new[] { "faruk-stretch", "ajdin-design" })
        {
            if (!postByTaskKey.TryGetValue(taskKey, out var post))
            {
                continue;
            }

            var exists = await dbContext.PostViews.AnyAsync(
                item => item.PostId == post.Id && item.ViewerUserId == mobileUserId,
                cancellationToken);
            if (!exists)
            {
                dbContext.PostViews.Add(new PostView
                {
                    Id = DemoSeedIds.For($"post-view:{post.Id:N}:{mobileUserId:N}"),
                    PostId = post.Id,
                    ViewerUserId = mobileUserId,
                    ViewedAtUtc = now.AddMinutes(-20)
                });
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<Dictionary<string, Conversation>> EnsureConversationsAsync(
        IReadOnlyDictionary<string, AppUser> users,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var result = new Dictionary<string, Conversation>(StringComparer.OrdinalIgnoreCase);
        foreach (var spec in DemoSeedCatalog.Conversations)
        {
            var conversationId = DemoSeedIds.For($"conversation:{spec.Key}");
            var conversation = await dbContext.Conversations
                .IgnoreQueryFilters()
                .SingleOrDefaultAsync(item => item.Id == conversationId, cancellationToken);
            if (conversation is null)
            {
                conversation = new Conversation
                {
                    Id = conversationId,
                    IsGroup = false,
                    Title = null,
                    LastMessageAtUtc = spec.Messages.Max(item => now.AddMinutes(item.MinuteOffset))
                };
                dbContext.Conversations.Add(conversation);
            }

            var firstUser = users[spec.FirstUserKey];
            var secondUser = users[spec.SecondUserKey];
            var messages = new List<Message>();
            var index = 0;
            foreach (var messageSpec in spec.Messages)
            {
                index++;
                var messageId = DemoSeedIds.For($"message:{spec.Key}:{index}");
                var message = await dbContext.Messages
                    .IgnoreQueryFilters()
                    .SingleOrDefaultAsync(item => item.Id == messageId, cancellationToken);
                if (message is null)
                {
                    message = new Message
                    {
                        Id = messageId,
                        ConversationId = conversation.Id,
                        SenderUserId = users[messageSpec.SenderKey].Id,
                        Type = messageSpec.HasImage ? MessageType.Image : MessageType.Text,
                        Content = messageSpec.Content,
                        SentAtUtc = now.AddMinutes(messageSpec.MinuteOffset)
                    };
                    dbContext.Messages.Add(message);
                }

                messages.Add(message);
                if (messageSpec.HasImage)
                {
                    var attachment = await dbContext.MessageAttachments
                        .SingleOrDefaultAsync(item => item.MessageId == message.Id, cancellationToken);
                    if (attachment is null)
                    {
                        var storageKey = ProofStorageKey("friends.png");
                        dbContext.MessageAttachments.Add(new MessageAttachment
                        {
                            Id = DemoSeedIds.For($"message-attachment:{message.Id:N}"),
                            MessageId = message.Id,
                            OwnerUserId = message.SenderUserId,
                            StorageKey = storageKey,
                            MimeType = "image/png",
                            SizeBytes = GetSeedFileSize(storageKey)
                        });
                    }
                }
            }

            // Persist conversations and messages first so participant read pointers
            // always reference rows that already exist in SQL Server.
            await dbContext.SaveChangesAsync(cancellationToken);

            var firstLastRead = messages.Count > 1 ? messages[^2].Id : messages[^1].Id;
            await EnsureParticipantAsync(
                conversation.Id,
                firstUser.Id,
                now.AddDays(-10),
                firstLastRead,
                cancellationToken);
            await EnsureParticipantAsync(
                conversation.Id,
                secondUser.Id,
                now.AddDays(-10),
                messages[^1].Id,
                cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);

            result[spec.Key] = conversation;
        }

        return result;
    }

    private async Task EnsureParticipantAsync(
        Guid conversationId,
        Guid userId,
        DateTime joinedAtUtc,
        Guid lastReadMessageId,
        CancellationToken cancellationToken)
    {
        var participant = await dbContext.ConversationParticipants
            .SingleOrDefaultAsync(
                item => item.ConversationId == conversationId && item.UserId == userId,
                cancellationToken);
        if (participant is null)
        {
            dbContext.ConversationParticipants.Add(new ConversationParticipant
            {
                Id = DemoSeedIds.For($"participant:{conversationId:N}:{userId:N}"),
                ConversationId = conversationId,
                UserId = userId,
                JoinedAtUtc = joinedAtUtc,
                LastReadMessageId = lastReadMessageId
            });
        }
    }

    private async Task EnsureNotificationsAsync(
        IReadOnlyDictionary<string, AppUser> users,
        IReadOnlyDictionary<string, FriendRequest> requests,
        IReadOnlyDictionary<string, Post> postByTaskKey,
        IReadOnlyDictionary<string, Conversation> conversations,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var mobileId = users["mobile"].Id;
        var specs = new List<NotificationSeedSpec>
        {
            new("incoming-edhem", mobileId, NotificationKind.FriendRequestReceived,
                "New friend request", "Edhem Kevric sent you a friend request.", false,
                "FriendRequest", requests["edhem-mobile"].Id),
            new("incoming-amar", mobileId, NotificationKind.FriendRequestReceived,
                "New friend request", "Amar Kovac sent you a friend request.", false,
                "FriendRequest", requests["amar-mobile"].Id),
            new("faruk-task", mobileId, NotificationKind.TaskCompleted,
                "Faruk completed a task", "Faruk completed Stretch for 10 minutes.", false,
                "Post", postByTaskKey.GetValueOrDefault("faruk-stretch")?.Id),
            new("ajdin-task", mobileId, NotificationKind.TaskCompleted,
                "Ajdin completed a task", "Ajdin completed Review mobile design.", true,
                "Post", postByTaskKey.GetValueOrDefault("ajdin-design")?.Id),
            new("faruk-message", mobileId, NotificationKind.NewMessage,
                "New message from Faruk", "The proof image is from this morning's run.", false,
                "Conversation", conversations["mobile-faruk"].Id),
            new("amina-message", mobileId, NotificationKind.NewMessage,
                "New message from Amina", "Great, I finished yoga this morning too.", true,
                "Conversation", conversations["mobile-amina"].Id),
            new("system", mobileId, NotificationKind.System,
                "Welcome to Ladder Social", "Your demo profile is ready to explore.", true,
                null, null)
        };

        foreach (var spec in specs)
        {
            var id = DemoSeedIds.For($"notification:{spec.Key}");
            if (await dbContext.Notifications.AnyAsync(item => item.Id == id, cancellationToken))
            {
                continue;
            }

            dbContext.Notifications.Add(new Notification
            {
                Id = id,
                UserId = spec.UserId,
                Kind = spec.Kind,
                Title = spec.Title,
                Body = spec.Body,
                IsRead = spec.IsRead,
                ReadAtUtc = spec.IsRead ? now.AddMinutes(-45) : null,
                RelatedEntityType = spec.RelatedEntityType,
                RelatedEntityId = spec.RelatedEntityId
            });
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureRecommendationLogsAsync(
        IReadOnlyDictionary<string, AppUser> users,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var specs = new[]
        {
            (Key: "harun", Count: 2, Explanation: "Recommended because you have 2 mutual friends: Ajdin Hajdarevic and Faruk Chaluk."),
            (Key: "selma", Count: 1, Explanation: "Recommended because you and Selma Alic both know Ajdin Hajdarevic.")
        };
        foreach (var spec in specs)
        {
            var id = DemoSeedIds.For($"recommendation-log:mobile:{spec.Key}");
            if (await dbContext.RecommendationLogs.AnyAsync(item => item.Id == id, cancellationToken))
            {
                continue;
            }

            dbContext.RecommendationLogs.Add(new RecommendationLog
            {
                Id = id,
                UserId = users["mobile"].Id,
                RecommendedUserId = users[spec.Key].Id,
                MutualFriendCount = spec.Count,
                Explanation = spec.Explanation,
                CreatedAtUtc = now.AddMinutes(-30)
            });
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureSeedAssetFilesAsync(CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_fileStorageOptions.RootPath))
        {
            throw new InvalidOperationException("UPLOAD_ROOT is required for demo seed assets.");
        }

        var sourceRoot = Path.Combine(AppContext.BaseDirectory, "SeedAssets");
        if (!Directory.Exists(sourceRoot))
        {
            throw new InvalidOperationException(
                $"Demo seed assets were not published to {sourceRoot}.");
        }

        var destinationRoot = Path.GetFullPath(_fileStorageOptions.RootPath);
        Directory.CreateDirectory(destinationRoot);
        foreach (var sourcePath in Directory.EnumerateFiles(sourceRoot, "*", SearchOption.AllDirectories))
        {
            cancellationToken.ThrowIfCancellationRequested();
            var relative = Path.GetRelativePath(sourceRoot, sourcePath);
            var destinationPath = Path.Combine(destinationRoot, "seed", relative);
            var directory = Path.GetDirectoryName(destinationPath)
                ?? throw new InvalidOperationException("The demo asset destination is invalid.");
            Directory.CreateDirectory(directory);
            if (File.Exists(destinationPath))
            {
                continue;
            }

            await using var source = File.OpenRead(sourcePath);
            await using var destination = File.Create(destinationPath);
            await source.CopyToAsync(destination, cancellationToken);
        }
    }

    private long GetSeedFileSize(string storageKey)
    {
        var path = Path.Combine(
            Path.GetFullPath(_fileStorageOptions.RootPath),
            storageKey.Replace('/', Path.DirectorySeparatorChar));
        return new FileInfo(path).Length;
    }

    private static DateTime GetCompletedAtUtc(
        DateOnly occurrenceDate,
        int hour,
        DateTime now)
    {
        var proposed = occurrenceDate.ToDateTime(
            new TimeOnly(Math.Clamp(hour, 0, 23), 0),
            DateTimeKind.Utc);

        return proposed < now
            ? proposed
            : now.AddMinutes(-5);
    }

    private static DateTime? GetDueAtUtc(DemoTaskSpec spec, DateOnly today)
    {
        if (!spec.DueDayOffset.HasValue)
        {
            return null;
        }

        var date = spec.RecurrenceCode == "monthly"
            ? today.AddMonths(-2)
            : today.AddDays(spec.DueDayOffset.Value);
        return date.ToDateTime(new TimeOnly(Math.Clamp(spec.DueHour, 0, 23), 0), DateTimeKind.Utc);
    }

    private static string AvatarStorageKey(string assetName) => $"seed/avatars/{assetName}";
    private static string ProofStorageKey(string assetName) => $"seed/proofs/{assetName}";

    private static bool IsEnabled(string? value) =>
        string.IsNullOrWhiteSpace(value) ||
        bool.TryParse(value, out var enabled) && enabled;

    private static void EnsureSucceeded(IdentityResult result, string operation)
    {
        if (result.Succeeded)
        {
            return;
        }

        var errors = string.Join("; ", result.Errors.Select(item => item.Description));
        throw new InvalidOperationException($"Identity operation failed while {operation}: {errors}");
    }

    private sealed record ReferenceLookup(
        IReadOnlyDictionary<string, TaskCategory> CategoriesByCode,
        IReadOnlyDictionary<string, RecurrenceType> RecurrenceByCode,
        IReadOnlyDictionary<string, City> CitiesByName);

    private sealed record SeededContent(IReadOnlyDictionary<string, Post> PostByTaskKey);

    private sealed record NotificationSeedSpec(
        string Key,
        Guid UserId,
        NotificationKind Kind,
        string Title,
        string Body,
        bool IsRead,
        string? RelatedEntityType,
        Guid? RelatedEntityId);
}
