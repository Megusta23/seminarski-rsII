using System.Data;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Chat;
using LadderSocial.Domain.Entities;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class ChatService(
    ApplicationDbContext dbContext,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IFileStorageService fileStorageService,
    IRealtimeNotifier realtimeNotifier) : IChatService
{
    public async Task<PagedResult<ConversationResponse>> GetConversationsAsync(
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var query =
            from participant in dbContext.ConversationParticipants.AsNoTracking()
            join conversation in dbContext.Conversations.AsNoTracking()
                on participant.ConversationId equals conversation.Id
            where participant.UserId == userId
            select conversation;

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(conversation =>
                (conversation.Title != null && EF.Functions.Like(conversation.Title, $"%{search}%")) ||
                dbContext.ConversationParticipants.Any(otherParticipant =>
                    otherParticipant.ConversationId == conversation.Id &&
                    otherParticipant.UserId != userId &&
                    dbContext.Users.Any(user =>
                        user.Id == otherParticipant.UserId &&
                        EF.Functions.Like(user.DisplayName, $"%{search}%"))));
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var conversations = await query
            .OrderByDescending(item => item.LastMessageAtUtc)
            .ThenByDescending(item => item.CreatedAtUtc)
            .ThenByDescending(item => item.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArrayAsync(cancellationToken);
        var conversationIds = conversations.Select(item => item.Id).ToArray();
        var participantRows = await (
                from participant in dbContext.ConversationParticipants.AsNoTracking()
                join user in dbContext.Users.AsNoTracking() on participant.UserId equals user.Id
                join profile in dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId
                where conversationIds.Contains(participant.ConversationId)
                select new
                {
                    participant.ConversationId,
                    user.Id,
                    user.DisplayName,
                    HasAvatar = profile.AvatarStorageKey != null,
                    participant.LastReadMessageId
                })
            .ToArrayAsync(cancellationToken);
        var lastMessages = await dbContext.Messages
            .AsNoTracking()
            .Where(message => conversationIds.Contains(message.ConversationId))
            .GroupBy(message => message.ConversationId)
            .Select(group => group
                .OrderByDescending(message => message.SentAtUtc)
                .ThenByDescending(message => message.Id)
                .First())
            .ToArrayAsync(cancellationToken);

        var lastReadIds = participantRows
            .Where(item => item.Id == userId && item.LastReadMessageId.HasValue)
            .Select(item => item.LastReadMessageId!.Value)
            .ToArray();
        var lastReadTimes = await dbContext.Messages
            .AsNoTracking()
            .Where(message => lastReadIds.Contains(message.Id))
            .ToDictionaryAsync(message => message.Id, message => message.SentAtUtc, cancellationToken);
        var currentParticipantByConversation = participantRows
            .Where(item => item.Id == userId)
            .ToDictionary(item => item.ConversationId);
        var unreadRows = await dbContext.Messages
            .AsNoTracking()
            .Where(message => conversationIds.Contains(message.ConversationId) && message.SenderUserId != userId)
            .Select(message => new { message.ConversationId, message.SentAtUtc })
            .ToArrayAsync(cancellationToken);
        var unreadCounts = unreadRows
            .GroupBy(item => item.ConversationId)
            .ToDictionary(
                group => group.Key,
                group =>
                {
                    var participant = currentParticipantByConversation[group.Key];
                    if (!participant.LastReadMessageId.HasValue ||
                        !lastReadTimes.TryGetValue(participant.LastReadMessageId.Value, out var lastReadAt))
                    {
                        return group.Count();
                    }

                    return group.Count(item => item.SentAtUtc > lastReadAt);
                });
        var lastByConversation = lastMessages
            .GroupBy(item => item.ConversationId)
            .ToDictionary(
                group => group.Key,
                group => group.OrderByDescending(item => item.Id).First());
        var participantGroups = participantRows
            .GroupBy(item => item.ConversationId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyCollection<ConversationParticipantResponse>)group
                    .OrderBy(item => item.DisplayName)
                    .Select(item => new ConversationParticipantResponse(
                        item.Id,
                        item.DisplayName,
                        item.HasAvatar ? $"/api/media/avatars/{item.Id}" : null,
                        item.Id == userId))
                    .ToArray());
        var otherParticipantIds = participantRows
            .Where(item => item.Id != userId)
            .Select(item => item.Id)
            .Distinct()
            .ToArray();
        var activeFriendIds = (await dbContext.Friendships
            .AsNoTracking()
            .Where(item => item.UserId == userId && otherParticipantIds.Contains(item.FriendUserId))
            .Select(item => item.FriendUserId)
            .ToArrayAsync(cancellationToken))
            .ToHashSet();
        var items = conversations
            .Select(conversation =>
            {
                var participants = participantGroups.GetValueOrDefault(conversation.Id)
                    ?? Array.Empty<ConversationParticipantResponse>();
                lastByConversation.TryGetValue(conversation.Id, out var lastMessage);
                var title = !string.IsNullOrWhiteSpace(conversation.Title)
                    ? conversation.Title!
                    : string.Join(", ", participants
                        .Where(item => !item.IsCurrentUser)
                        .Select(item => item.DisplayName));
                var otherParticipants = participants
                    .Where(item => !item.IsCurrentUser)
                    .ToArray();
                var canSendMessages = conversation.IsGroup ||
                    (otherParticipants.Length == 1 &&
                     activeFriendIds.Contains(otherParticipants[0].UserId));
                return new ConversationResponse(
                    conversation.Id,
                    string.IsNullOrWhiteSpace(title) ? "Conversation" : title,
                    conversation.IsGroup,
                    canSendMessages,
                    conversation.LastMessageAtUtc,
                    lastMessage is null
                        ? null
                        : E2EChatRules.GetServerPreview(
                            lastMessage.Type,
                            lastMessage.Content,
                            lastMessage.EncryptionVersion),
                    unreadCounts.GetValueOrDefault(conversation.Id),
                    participants);
            })
            .ToArray();

        return new PagedResult<ConversationResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<ConversationResponse> StartDirectConversationAsync(
        Guid friendUserId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var isFriend = await dbContext.Friendships
            .AsNoTracking()
            .AnyAsync(item => item.UserId == userId && item.FriendUserId == friendUserId, cancellationToken);
        if (!isFriend)
        {
            throw new ForbiddenException("A direct conversation can be started only with an accepted friend.");
        }

        var existingId = await dbContext.ConversationParticipants
            .AsNoTracking()
            .Where(item => item.UserId == userId)
            .Select(item => item.ConversationId)
            .Where(conversationId =>
                dbContext.Conversations.Any(conversation => conversation.Id == conversationId && !conversation.IsGroup) &&
                dbContext.ConversationParticipants.Count(participant => participant.ConversationId == conversationId) == 2 &&
                dbContext.ConversationParticipants.Any(participant =>
                    participant.ConversationId == conversationId && participant.UserId == friendUserId))
            .FirstOrDefaultAsync(cancellationToken);
        if (existingId != Guid.Empty)
        {
            return await GetConversationAsync(existingId, cancellationToken);
        }

        var conversation = new Conversation
        {
            IsGroup = false,
            LastMessageAtUtc = null
        };
        dbContext.Conversations.Add(conversation);
        dbContext.ConversationParticipants.AddRange(
            new ConversationParticipant
            {
                ConversationId = conversation.Id,
                UserId = userId,
                JoinedAtUtc = dateTimeProvider.UtcNow
            },
            new ConversationParticipant
            {
                ConversationId = conversation.Id,
                UserId = friendUserId,
                JoinedAtUtc = dateTimeProvider.UtcNow
            });
        await dbContext.SaveChangesAsync(cancellationToken);
        var response = await GetConversationAsync(conversation.Id, cancellationToken);
        var conversationChanged = new { ConversationId = conversation.Id };
        await realtimeNotifier.NotifyUserAsync(
            userId,
            "ConversationChanged",
            conversationChanged,
            cancellationToken);
        await realtimeNotifier.NotifyUserAsync(
            friendUserId,
            "ConversationChanged",
            conversationChanged,
            cancellationToken);
        return response;
    }

    public async Task<UserDeviceKeyResponse> RegisterDeviceKeyAsync(
        RegisterDeviceKeyRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        E2EChatRules.ValidateDeviceRegistration(request);

        var deviceId = request.DeviceId.Trim();
        var publicKey = request.PublicKey.ToArray();
        var deviceKey = await dbContext.UserDeviceKeys
            .SingleOrDefaultAsync(
                item => item.UserId == userId && item.DeviceId == deviceId,
                cancellationToken);
        var isNew = deviceKey is null;
        var now = dateTimeProvider.UtcNow;

        if (deviceKey is null)
        {
            deviceKey = new UserDeviceKey
            {
                UserId = userId,
                DeviceId = deviceId,
                PublicKey = publicKey,
                CreatedAtUtc = now,
                LastSeenAtUtc = now
            };
            dbContext.UserDeviceKeys.Add(deviceKey);
        }
        else
        {
            EnsureMatchingPublicKey(deviceKey, publicKey);
            deviceKey.LastSeenAtUtc = now;
            deviceKey.RevokedAtUtc = null;
        }

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return MapDeviceKey(deviceKey);
        }
        catch (DbUpdateException) when (isNew)
        {
            dbContext.Entry(deviceKey).State = EntityState.Detached;
            var concurrent = await dbContext.UserDeviceKeys
                .AsNoTracking()
                .SingleOrDefaultAsync(
                    item => item.UserId == userId && item.DeviceId == deviceId,
                    cancellationToken);
            if (concurrent is null)
            {
                throw;
            }

            EnsureMatchingPublicKey(concurrent, publicKey);
            return MapDeviceKey(concurrent);
        }
    }

    public async Task<PagedResult<UserDeviceKeyResponse>> GetConversationDeviceKeysAsync(
        Guid conversationId,
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        await EnsureMembershipAsync(conversationId, cancellationToken);

        var query =
            from participant in dbContext.ConversationParticipants.AsNoTracking()
            join deviceKey in dbContext.UserDeviceKeys.AsNoTracking()
                on participant.UserId equals deviceKey.UserId
            where participant.ConversationId == conversationId &&
                deviceKey.RevokedAtUtc == null
            select deviceKey;
        var totalCount = await query.CountAsync(cancellationToken);
        var deviceKeys = await query
            .OrderBy(item => item.UserId)
            .ThenBy(item => item.DeviceId)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArrayAsync(cancellationToken);
        var items = deviceKeys.Select(MapDeviceKey).ToArray();

        return new PagedResult<UserDeviceKeyResponse>(
            items,
            request.Page,
            request.PageSize,
            totalCount);
    }

    public async Task<ConversationKeyEnvelopeResponse> PutConversationKeyEnvelopeAsync(
        Guid conversationId,
        CreateConversationKeyEnvelopeRequest request,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        await EnsureMembershipAsync(conversationId, cancellationToken);
        E2EChatRules.ValidateEnvelope(request);

        var senderDeviceExists = await dbContext.UserDeviceKeys
            .AsNoTracking()
            .AnyAsync(
                item => item.Id == request.SenderDeviceKeyId &&
                    item.UserId == userId &&
                    item.RevokedAtUtc == null,
                cancellationToken);
        if (!senderDeviceExists)
        {
            throw new NotFoundException("The active sender device key was not found.");
        }

        var recipientDeviceExists = await (
                from deviceKey in dbContext.UserDeviceKeys.AsNoTracking()
                join participant in dbContext.ConversationParticipants.AsNoTracking()
                    on deviceKey.UserId equals participant.UserId
                where deviceKey.Id == request.RecipientDeviceKeyId &&
                    deviceKey.RevokedAtUtc == null &&
                    participant.ConversationId == conversationId
                select deviceKey.Id)
            .AnyAsync(cancellationToken);
        if (!recipientDeviceExists)
        {
            throw new NotFoundException(
                "The active recipient device key was not found in this conversation.");
        }

        var existing = await dbContext.ConversationKeyEnvelopes
            .SingleOrDefaultAsync(
                item => item.ConversationId == conversationId &&
                    item.RecipientDeviceKeyId == request.RecipientDeviceKeyId &&
                    item.KeyVersion == request.KeyVersion,
                cancellationToken);
        if (existing is not null)
        {
            if (!EnvelopeMatches(existing, request))
            {
                throw new ConflictException(
                    "A different envelope already exists for this device and key version. " +
                    "Use a new KeyVersion when rotating the conversation key.");
            }

            return MapEnvelope(existing);
        }

        var envelope = new ConversationKeyEnvelope
        {
            ConversationId = conversationId,
            RecipientDeviceKeyId = request.RecipientDeviceKeyId,
            SenderDeviceKeyId = request.SenderDeviceKeyId,
            EncryptedConversationKey = request.EncryptedConversationKey.ToArray(),
            Nonce = request.Nonce.ToArray(),
            KeyVersion = request.KeyVersion,
            CreatedAtUtc = dateTimeProvider.UtcNow
        };
        dbContext.ConversationKeyEnvelopes.Add(envelope);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return MapEnvelope(envelope);
        }
        catch (DbUpdateException)
        {
            dbContext.Entry(envelope).State = EntityState.Detached;
            var concurrent = await dbContext.ConversationKeyEnvelopes
                .AsNoTracking()
                .SingleOrDefaultAsync(
                    item => item.ConversationId == conversationId &&
                        item.RecipientDeviceKeyId == request.RecipientDeviceKeyId &&
                        item.KeyVersion == request.KeyVersion,
                    cancellationToken);
            if (concurrent is null)
            {
                throw;
            }

            if (EnvelopeMatches(concurrent, request))
            {
                return MapEnvelope(concurrent);
            }

            throw new ConflictException(
                "A different envelope already exists for this device and key version. " +
                "Use a new KeyVersion when rotating the conversation key.");
        }
    }

    public async Task<ConversationKeyEnvelopeResponse> GetConversationKeyEnvelopeAsync(
        Guid conversationId,
        Guid recipientDeviceKeyId,
        int? keyVersion,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        await EnsureMembershipAsync(conversationId, cancellationToken);

        if (keyVersion.HasValue && keyVersion.Value < 1)
        {
            throw new ValidationException(
                "Conversation key envelope validation failed.",
                new Dictionary<string, string[]>
                {
                    ["keyVersion"] = ["KeyVersion must be greater than zero."]
                });
        }

        var ownsActiveDevice = await dbContext.UserDeviceKeys
            .AsNoTracking()
            .AnyAsync(
                item => item.Id == recipientDeviceKeyId &&
                    item.UserId == userId &&
                    item.RevokedAtUtc == null,
                cancellationToken);
        if (!ownsActiveDevice)
        {
            throw new NotFoundException("The requested recipient device key was not found.");
        }

        var query = dbContext.ConversationKeyEnvelopes
            .AsNoTracking()
            .Where(item => item.ConversationId == conversationId &&
                item.RecipientDeviceKeyId == recipientDeviceKeyId);
        if (keyVersion.HasValue)
        {
            query = query.Where(item => item.KeyVersion == keyVersion.Value);
        }

        var envelope = await query
            .OrderByDescending(item => item.KeyVersion)
            .ThenByDescending(item => item.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested conversation key envelope was not found.");

        return MapEnvelope(envelope);
    }

    public async Task<PagedResult<MessageResponse>> GetMessagesAsync(
        Guid conversationId,
        PagedRequest request,
        CancellationToken cancellationToken)
    {
        await EnsureMembershipAsync(conversationId, cancellationToken);
        var query = BuildMessageQuery(conversationId);
        var totalCount = await query.CountAsync(cancellationToken);
        var rows = await query
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArrayAsync(cancellationToken);
        var items = rows.Select(MapMessage).ToArray();
        return new PagedResult<MessageResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<MessageResponse> SendEncryptedMessageAsync(
        Guid conversationId,
        SendEncryptedMessageCommand command,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        E2EChatRules.ValidateEncryptedMessage(command);
        await EnsureCanSendMessageAsync(conversationId, userId, cancellationToken);
        await EnsureActiveSenderDeviceAsync(
            command.SenderDeviceKeyId,
            userId,
            cancellationToken);
        await EnsureEnvelopeCoverageAsync(
            conversationId,
            command.KeyVersion,
            cancellationToken);

        StoredFileInfo? storedFile = null;
        if (command.Attachment is not null)
        {
            storedFile = await fileStorageService.SaveEncryptedAsync(
                $"message-ciphertext/{dateTimeProvider.UtcNow:yyyy/MM}",
                command.Attachment,
                cancellationToken);
        }

        var message = E2EChatRules.CreateEncryptedMessage(
            conversationId,
            userId,
            command,
            dateTimeProvider.UtcNow);
        MessageAttachment? attachment = null;
        var notifications = new List<Notification>();

        try
        {
            var strategy = dbContext.Database.CreateExecutionStrategy();
            await strategy.ExecuteAsync(async () =>
            {
                await using var transaction = await dbContext.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable,
                    cancellationToken);
                await EnsureCanSendMessageAsync(conversationId, userId, cancellationToken);
                await EnsureActiveSenderDeviceAsync(
                    command.SenderDeviceKeyId,
                    userId,
                    cancellationToken);
                await EnsureEnvelopeCoverageAsync(
                    conversationId,
                    command.KeyVersion,
                    cancellationToken);

                dbContext.Messages.Add(message);
                if (storedFile is not null)
                {
                    attachment = E2EChatRules.CreateEncryptedAttachment(
                        message.Id,
                        userId,
                        storedFile,
                        command);
                    dbContext.MessageAttachments.Add(attachment);
                }

                var conversation = await dbContext.Conversations
                    .SingleAsync(item => item.Id == conversationId, cancellationToken);
                conversation.LastMessageAtUtc = message.SentAtUtc;
                var senderName = await dbContext.Users
                    .Where(item => item.Id == userId)
                    .Select(item => item.DisplayName)
                    .SingleAsync(cancellationToken);
                var recipientIds = await dbContext.ConversationParticipants
                    .Where(item => item.ConversationId == conversationId && item.UserId != userId)
                    .Select(item => item.UserId)
                    .ToArrayAsync(cancellationToken);
                notifications.AddRange(recipientIds.Select(recipientId => new Notification
                {
                    UserId = recipientId,
                    Kind = NotificationKind.NewMessage,
                    Title = "New message",
                    Body = E2EChatRules.GetNotificationBody(senderName, message.Type),
                    RelatedEntityType = "Conversation",
                    RelatedEntityId = conversationId
                }));
                dbContext.Notifications.AddRange(notifications);
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

        var response = await GetMessageAsync(message.Id, conversationId, cancellationToken);
        await realtimeNotifier.NotifyConversationAsync(
            conversationId,
            "MessageReceived",
            response,
            cancellationToken);
        foreach (var notification in notifications)
        {
            await realtimeNotifier.NotifyUserAsync(
                notification.UserId,
                "NotificationChanged",
                new { notification.Id, notification.Title, notification.Body },
                cancellationToken);
        }

        return response;
    }

    public async Task MarkReadAsync(
        Guid conversationId,
        Guid? throughMessageId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var participant = await dbContext.ConversationParticipants
            .SingleOrDefaultAsync(item => item.ConversationId == conversationId && item.UserId == userId, cancellationToken)
            ?? throw new NotFoundException("The requested conversation was not found.");
        Guid? messageId = throughMessageId;
        if (!messageId.HasValue)
        {
            messageId = await dbContext.Messages
                .Where(item => item.ConversationId == conversationId)
                .OrderByDescending(item => item.SentAtUtc)
                .ThenByDescending(item => item.Id)
                .Select(item => (Guid?)item.Id)
                .FirstOrDefaultAsync(cancellationToken);
        }
        else
        {
            var exists = await dbContext.Messages
                .AnyAsync(item => item.Id == messageId.Value && item.ConversationId == conversationId, cancellationToken);
            if (!exists)
            {
                throw new ValidationException(
                    "Read-state validation failed.",
                    new Dictionary<string, string[]>
                    {
                        ["throughMessageId"] = ["Select a message from this conversation."]
                    });
            }
        }

        participant.LastReadMessageId = messageId;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<Guid>> GetMyConversationIdsAsync(
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        return await dbContext.ConversationParticipants
            .AsNoTracking()
            .Where(item => item.UserId == userId)
            .Select(item => item.ConversationId)
            .ToArrayAsync(cancellationToken);
    }

    public async Task EnsureMembershipAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var isMember = await dbContext.ConversationParticipants
            .AsNoTracking()
            .AnyAsync(item => item.ConversationId == conversationId && item.UserId == userId, cancellationToken);
        if (!isMember)
        {
            throw new NotFoundException("The requested conversation was not found.");
        }
    }

    public async Task<ConversationResponse> GetConversationAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var conversation = await (
                from participant in dbContext.ConversationParticipants.AsNoTracking()
                join item in dbContext.Conversations.AsNoTracking()
                    on participant.ConversationId equals item.Id
                where participant.UserId == userId && item.Id == conversationId
                select item)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested conversation was not found.");
        var participants = await (
                from participant in dbContext.ConversationParticipants.AsNoTracking()
                join user in dbContext.Users.AsNoTracking() on participant.UserId equals user.Id
                join profile in dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId
                where participant.ConversationId == conversationId
                orderby user.DisplayName
                select new
                {
                    user.Id,
                    user.DisplayName,
                    HasAvatar = profile.AvatarStorageKey != null
                })
            .ToArrayAsync(cancellationToken);
        var participantResponses = participants
            .Select(item => new ConversationParticipantResponse(
                item.Id,
                item.DisplayName,
                item.HasAvatar ? $"/api/media/avatars/{item.Id}" : null,
                item.Id == userId))
            .ToArray();
        var lastMessage = await dbContext.Messages
            .AsNoTracking()
            .Where(item => item.ConversationId == conversationId)
            .OrderByDescending(item => item.SentAtUtc)
            .ThenByDescending(item => item.Id)
            .FirstOrDefaultAsync(cancellationToken);
        var currentParticipant = await dbContext.ConversationParticipants
            .AsNoTracking()
            .SingleAsync(item => item.ConversationId == conversationId && item.UserId == userId, cancellationToken);
        DateTime? lastReadAt = null;
        if (currentParticipant.LastReadMessageId.HasValue)
        {
            lastReadAt = await dbContext.Messages
                .AsNoTracking()
                .Where(item => item.Id == currentParticipant.LastReadMessageId.Value)
                .Select(item => (DateTime?)item.SentAtUtc)
                .SingleOrDefaultAsync(cancellationToken);
        }

        var unreadCount = await dbContext.Messages.CountAsync(
            item => item.ConversationId == conversationId &&
                item.SenderUserId != userId &&
                (!lastReadAt.HasValue || item.SentAtUtc > lastReadAt.Value),
            cancellationToken);
        var title = !string.IsNullOrWhiteSpace(conversation.Title)
            ? conversation.Title!
            : string.Join(", ", participantResponses
                .Where(item => !item.IsCurrentUser)
                .Select(item => item.DisplayName));
        var otherParticipantIds = participantResponses
            .Where(item => !item.IsCurrentUser)
            .Select(item => item.UserId)
            .ToArray();
        var canSendMessages = conversation.IsGroup ||
            (otherParticipantIds.Length == 1 &&
             await dbContext.Friendships
                 .AsNoTracking()
                 .AnyAsync(
                     item => item.UserId == userId &&
                         item.FriendUserId == otherParticipantIds[0],
                     cancellationToken));
        return new ConversationResponse(
            conversation.Id,
            string.IsNullOrWhiteSpace(title) ? "Conversation" : title,
            conversation.IsGroup,
            canSendMessages,
            conversation.LastMessageAtUtc,
            lastMessage is null
                ? null
                : E2EChatRules.GetServerPreview(
                    lastMessage.Type,
                    lastMessage.Content,
                    lastMessage.EncryptionVersion),
            unreadCount,
            participantResponses);
    }

    private async Task EnsureCanSendMessageAsync(
        Guid conversationId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var conversation = await (
                from participant in dbContext.ConversationParticipants.AsNoTracking()
                join item in dbContext.Conversations.AsNoTracking()
                    on participant.ConversationId equals item.Id
                where participant.UserId == userId && item.Id == conversationId
                select item)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The requested conversation was not found.");
        if (conversation.IsGroup)
        {
            return;
        }

        var otherParticipantIds = await dbContext.ConversationParticipants
            .AsNoTracking()
            .Where(item => item.ConversationId == conversationId && item.UserId != userId)
            .Select(item => item.UserId)
            .ToArrayAsync(cancellationToken);
        var isActiveFriendship = otherParticipantIds.Length == 1 &&
            await dbContext.Friendships
                .AsNoTracking()
                .AnyAsync(
                    item => item.UserId == userId &&
                        item.FriendUserId == otherParticipantIds[0],
                    cancellationToken);
        if (!isActiveFriendship)
        {
            throw new ForbiddenException(
                "You can send new direct messages only while you are friends.");
        }
    }

    private async Task EnsureActiveSenderDeviceAsync(
        Guid senderDeviceKeyId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.UserDeviceKeys
            .AsNoTracking()
            .AnyAsync(
                item => item.Id == senderDeviceKeyId &&
                    item.UserId == userId &&
                    item.RevokedAtUtc == null,
                cancellationToken);
        if (!exists)
        {
            throw new NotFoundException("The active sender device key was not found.");
        }
    }

    private async Task EnsureEnvelopeCoverageAsync(
        Guid conversationId,
        int keyVersion,
        CancellationToken cancellationToken)
    {
        var participantIds = await dbContext.ConversationParticipants
            .AsNoTracking()
            .Where(item => item.ConversationId == conversationId)
            .Select(item => item.UserId)
            .ToArrayAsync(cancellationToken);
        var activeDevices = await dbContext.UserDeviceKeys
            .AsNoTracking()
            .Where(item => participantIds.Contains(item.UserId) && item.RevokedAtUtc == null)
            .Select(item => new { item.Id, item.UserId })
            .ToArrayAsync(cancellationToken);
        var usersWithActiveDevices = activeDevices
            .Select(item => item.UserId)
            .ToHashSet();
        if (participantIds.Any(participantId => !usersWithActiveDevices.Contains(participantId)))
        {
            throw new ConflictException(
                "Every conversation participant must register an active device public key before E2E messages can be sent.");
        }

        var activeDeviceIds = activeDevices.Select(item => item.Id).ToArray();
        var coveredDeviceIds = (await dbContext.ConversationKeyEnvelopes
                .AsNoTracking()
                .Where(item => item.ConversationId == conversationId &&
                    item.KeyVersion == keyVersion &&
                    activeDeviceIds.Contains(item.RecipientDeviceKeyId))
                .Select(item => item.RecipientDeviceKeyId)
                .ToArrayAsync(cancellationToken))
            .ToHashSet();
        if (activeDeviceIds.Any(deviceId => !coveredDeviceIds.Contains(deviceId)))
        {
            throw new ConflictException(
                "Create a conversation key envelope for every active participant device before sending this key version.");
        }
    }

    private IQueryable<MessageProjection> BuildMessageQuery(
        Guid conversationId,
        Guid? messageId = null)
    {
        var query =
            from message in dbContext.Messages.AsNoTracking()
            join sender in dbContext.Users.AsNoTracking() on message.SenderUserId equals sender.Id
            join attachment in dbContext.MessageAttachments.AsNoTracking()
                on message.Id equals attachment.MessageId into attachments
            from attachment in attachments.DefaultIfEmpty()
            where message.ConversationId == conversationId
            select new
            {
                MessageId = message.Id,
                message.ConversationId,
                message.SenderUserId,
                SenderDisplayName = sender.DisplayName,
                message.Type,
                message.Content,
                message.EncryptedContent,
                message.ContentNonce,
                message.EncryptionVersion,
                message.KeyVersion,
                message.SentAtUtc,
                AttachmentId = attachment == null ? (Guid?)null : attachment.Id,
                AttachmentMimeType = attachment == null ? null : attachment.MimeType,
                AttachmentNonce = attachment == null ? null : attachment.ContentNonce,
                AttachmentEncryptionVersion = attachment == null
                    ? (int?)null
                    : attachment.EncryptionVersion,
                AttachmentKeyVersion = attachment == null ? null : attachment.KeyVersion,
                AttachmentSizeBytes = attachment == null ? (long?)null : attachment.SizeBytes,
                AttachmentDurationMilliseconds = attachment == null
                    ? null
                    : attachment.DurationMilliseconds
            };

        if (messageId.HasValue)
        {
            query = query.Where(item => item.MessageId == messageId.Value);
        }

        return query
            .OrderByDescending(item => item.SentAtUtc)
            .ThenByDescending(item => item.MessageId)
            .Select(item => new MessageProjection(
                item.MessageId,
                item.ConversationId,
                item.SenderUserId,
                item.SenderDisplayName,
                item.Type,
                item.Content,
                item.EncryptedContent,
                item.ContentNonce,
                item.EncryptionVersion,
                item.KeyVersion,
                item.SentAtUtc,
                item.AttachmentId,
                item.AttachmentMimeType,
                item.AttachmentNonce,
                item.AttachmentEncryptionVersion,
                item.AttachmentKeyVersion,
                item.AttachmentSizeBytes,
                item.AttachmentDurationMilliseconds));
    }

    private async Task<MessageResponse> GetMessageAsync(
        Guid messageId,
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var row = await BuildMessageQuery(conversationId, messageId)
            .SingleAsync(cancellationToken);
        return MapMessage(row);
    }

    private static MessageResponse MapMessage(MessageProjection item) =>
        new(
            item.MessageId,
            item.ConversationId,
            item.SenderUserId,
            item.SenderDisplayName,
            item.Type,
            item.Content,
            item.EncryptedContent,
            item.ContentNonce,
            item.EncryptionVersion,
            item.KeyVersion,
            item.SentAtUtc,
            item.AttachmentId,
            item.AttachmentId.HasValue
                ? $"/api/media/message-attachments/{item.AttachmentId.Value}"
                : null,
            item.AttachmentMimeType,
            item.AttachmentNonce,
            item.AttachmentEncryptionVersion,
            item.AttachmentKeyVersion,
            item.AttachmentSizeBytes,
            item.AttachmentDurationMilliseconds);

    private static void EnsureMatchingPublicKey(UserDeviceKey deviceKey, byte[] publicKey)
    {
        if (!deviceKey.PublicKey.SequenceEqual(publicKey))
        {
            throw new ConflictException(
                "This DeviceId is already registered with a different public key. " +
                "Create a new DeviceId instead of silently replacing key material.");
        }
    }

    private static bool EnvelopeMatches(
        ConversationKeyEnvelope envelope,
        CreateConversationKeyEnvelopeRequest request) =>
        envelope.SenderDeviceKeyId == request.SenderDeviceKeyId &&
        envelope.EncryptedConversationKey.SequenceEqual(request.EncryptedConversationKey) &&
        envelope.Nonce.SequenceEqual(request.Nonce);

    private static UserDeviceKeyResponse MapDeviceKey(UserDeviceKey item) =>
        new(
            item.Id,
            item.UserId,
            item.DeviceId,
            item.PublicKey.ToArray(),
            item.CreatedAtUtc,
            item.LastSeenAtUtc);

    private static ConversationKeyEnvelopeResponse MapEnvelope(ConversationKeyEnvelope item) =>
        new(
            item.Id,
            item.ConversationId,
            item.RecipientDeviceKeyId,
            item.SenderDeviceKeyId,
            item.EncryptedConversationKey.ToArray(),
            item.Nonce.ToArray(),
            item.KeyVersion,
            item.CreatedAtUtc);

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access chat.");

    private sealed record MessageProjection(
        Guid MessageId,
        Guid ConversationId,
        Guid SenderUserId,
        string SenderDisplayName,
        MessageType Type,
        string? Content,
        byte[]? EncryptedContent,
        byte[]? ContentNonce,
        int EncryptionVersion,
        int? KeyVersion,
        DateTime SentAtUtc,
        Guid? AttachmentId,
        string? AttachmentMimeType,
        byte[]? AttachmentNonce,
        int? AttachmentEncryptionVersion,
        int? AttachmentKeyVersion,
        long? AttachmentSizeBytes,
        int? AttachmentDurationMilliseconds);
}
