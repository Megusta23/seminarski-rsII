using System.Text.Json;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Messaging;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Features.Auth;
using LadderSocial.Infrastructure.Messaging;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace LadderSocial.Worker;

public sealed class PasswordResetEmailConsumerService(
    IRabbitMqConnection rabbitMqConnection,
    IServiceScopeFactory scopeFactory,
    IOptions<RabbitMqOptions> rabbitOptions,
    ILogger<PasswordResetEmailConsumerService> logger) : BackgroundService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly TimeSpan[] RetryDelays =
    [
        TimeSpan.Zero,
        TimeSpan.FromSeconds(1),
        TimeSpan.FromSeconds(2),
        TimeSpan.FromSeconds(4),
        TimeSpan.FromSeconds(8)
    ];

    private readonly RabbitMqOptions _rabbitOptions = rabbitOptions.Value;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var connection = await rabbitMqConnection.GetConnectionAsync(stoppingToken);
                await using var channel = await connection.CreateChannelAsync(
                    cancellationToken: stoppingToken);

                await RabbitMqTopology.DeclarePasswordResetTopologyAsync(
                    channel,
                    _rabbitOptions,
                    stoppingToken);
                await channel.BasicQosAsync(
                    prefetchSize: 0,
                    prefetchCount: 1,
                    global: false,
                    cancellationToken: stoppingToken);

                var consumer = new AsyncEventingBasicConsumer(channel);
                consumer.ReceivedAsync += (_, eventArgs) =>
                    HandleMessageAsync(channel, eventArgs, stoppingToken);

                await channel.BasicConsumeAsync(
                    queue: _rabbitOptions.PasswordResetQueueName,
                    autoAck: false,
                    consumer: consumer,
                    cancellationToken: stoppingToken);

                logger.LogInformation(
                    "Password reset email worker is consuming queue {QueueName}.",
                    _rabbitOptions.PasswordResetQueueName);

                await Task.Delay(Timeout.InfiniteTimeSpan, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                logger.LogError(
                    exception,
                    "Password reset email consumer stopped unexpectedly. Retrying in five seconds.");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }

    private async Task HandleMessageAsync(
        IChannel channel,
        BasicDeliverEventArgs eventArgs,
        CancellationToken stoppingToken)
    {
        // RabbitMQ only guarantees the body memory during the callback.
        var body = eventArgs.Body.ToArray();
        PasswordResetRequestedEvent? message;

        try
        {
            message = JsonSerializer.Deserialize<PasswordResetRequestedEvent>(body, JsonOptions);
            if (message is null)
            {
                throw new JsonException("The password reset event body is empty.");
            }
        }
        catch (Exception exception) when (exception is JsonException or NotSupportedException)
        {
            logger.LogError(
                exception,
                "Dead-lettering malformed password reset event with delivery tag {DeliveryTag}.",
                eventArgs.DeliveryTag);
            await channel.BasicNackAsync(
                eventArgs.DeliveryTag,
                multiple: false,
                requeue: false,
                cancellationToken: stoppingToken);
            return;
        }

        Exception? lastException = null;
        for (var attempt = 1; attempt <= RetryDelays.Length; attempt++)
        {
            if (RetryDelays[attempt - 1] > TimeSpan.Zero)
            {
                await Task.Delay(RetryDelays[attempt - 1], stoppingToken);
            }

            try
            {
                await ProcessMessageAsync(message, stoppingToken);
                await channel.BasicAckAsync(
                    eventArgs.DeliveryTag,
                    multiple: false,
                    cancellationToken: stoppingToken);
                return;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                lastException = exception;
                await RecordDeliveryFailureAsync(
                    message.PasswordResetRequestId,
                    exception,
                    stoppingToken);

                logger.LogWarning(
                    exception,
                    "Password reset email delivery attempt {Attempt}/{MaximumAttempts} failed for request {PasswordResetRequestId}.",
                    attempt,
                    RetryDelays.Length,
                    message.PasswordResetRequestId);
            }
        }

        logger.LogError(
            lastException,
            "Password reset email event {MessageId} exhausted retries and will be dead-lettered.",
            message.MessageId);
        await channel.BasicNackAsync(
            eventArgs.DeliveryTag,
            multiple: false,
            requeue: false,
            cancellationToken: stoppingToken);
    }

    private async Task ProcessMessageAsync(
        PasswordResetRequestedEvent message,
        CancellationToken cancellationToken)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var codeService = scope.ServiceProvider.GetRequiredService<IPasswordResetCodeService>();
        var emailSender = scope.ServiceProvider.GetRequiredService<IEmailSender>();
        var dateTimeProvider = scope.ServiceProvider.GetRequiredService<IDateTimeProvider>();

        var resetRequest = await dbContext.PasswordResetRequests
            .SingleOrDefaultAsync(
                item => item.Id == message.PasswordResetRequestId &&
                        item.UserId == message.UserId,
                cancellationToken);

        if (resetRequest is null)
        {
            logger.LogWarning(
                "Ignoring password reset event {MessageId}; request {PasswordResetRequestId} no longer exists.",
                message.MessageId,
                message.PasswordResetRequestId);
            return;
        }

        if (resetRequest.EmailSentAtUtc.HasValue)
        {
            logger.LogInformation(
                "Password reset email for request {PasswordResetRequestId} was already sent at {EmailSentAtUtc}.",
                resetRequest.Id,
                resetRequest.EmailSentAtUtc);
            return;
        }

        var now = dateTimeProvider.UtcNow;
        if (resetRequest.UsedAtUtc.HasValue ||
            resetRequest.InvalidatedAtUtc.HasValue ||
            resetRequest.ExpiresAtUtc <= now)
        {
            logger.LogInformation(
                "Ignoring inactive password reset request {PasswordResetRequestId}.",
                resetRequest.Id);
            return;
        }

        var code = codeService.UnprotectFromTransport(message.ProtectedCode);
        await emailSender.SendPasswordResetAsync(
            message.Email,
            message.DisplayName,
            code,
            message.ExpiresAtUtc,
            cancellationToken);

        resetRequest.EmailDeliveryAttemptCount++;
        resetRequest.EmailSentAtUtc = dateTimeProvider.UtcNow;
        resetRequest.LastDeliveryError = null;
        await dbContext.SaveChangesAsync(cancellationToken);

        logger.LogInformation(
            "Password reset email was sent for request {PasswordResetRequestId} and event {MessageId}.",
            resetRequest.Id,
            message.MessageId);
    }

    private async Task RecordDeliveryFailureAsync(
        Guid requestId,
        Exception exception,
        CancellationToken cancellationToken)
    {
        try
        {
            await using var scope = scopeFactory.CreateAsyncScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var resetRequest = await dbContext.PasswordResetRequests
                .SingleOrDefaultAsync(item => item.Id == requestId, cancellationToken);

            if (resetRequest is null || resetRequest.EmailSentAtUtc.HasValue)
            {
                return;
            }

            resetRequest.EmailDeliveryAttemptCount++;
            resetRequest.LastDeliveryError = Truncate(exception.Message, 2000);
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (Exception updateException) when (updateException is not OperationCanceledException)
        {
            logger.LogError(
                updateException,
                "Could not persist email delivery failure for password reset request {PasswordResetRequestId}.",
                requestId);
        }
    }

    private static string Truncate(string value, int maximumLength) =>
        value.Length <= maximumLength ? value : value[..maximumLength];
}
