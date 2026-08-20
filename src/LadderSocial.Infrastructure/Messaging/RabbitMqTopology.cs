using LadderSocial.Application.Common.Options;
using RabbitMQ.Client;

namespace LadderSocial.Infrastructure.Messaging;

public static class RabbitMqTopology
{
    public static async Task DeclarePasswordResetTopologyAsync(
        IChannel channel,
        RabbitMqOptions options,
        CancellationToken cancellationToken)
    {
        await channel.ExchangeDeclareAsync(
            options.ExchangeName,
            ExchangeType.Direct,
            durable: true,
            autoDelete: false,
            cancellationToken: cancellationToken);

        await channel.ExchangeDeclareAsync(
            options.DeadLetterExchangeName,
            ExchangeType.Direct,
            durable: true,
            autoDelete: false,
            cancellationToken: cancellationToken);

        await channel.QueueDeclareAsync(
            options.PasswordResetDeadLetterQueueName,
            durable: true,
            exclusive: false,
            autoDelete: false,
            cancellationToken: cancellationToken);

        await channel.QueueBindAsync(
            options.PasswordResetDeadLetterQueueName,
            options.DeadLetterExchangeName,
            options.PasswordResetDeadLetterRoutingKey,
            cancellationToken: cancellationToken);

        var queueArguments = new Dictionary<string, object?>
        {
            ["x-dead-letter-exchange"] = options.DeadLetterExchangeName,
            ["x-dead-letter-routing-key"] = options.PasswordResetDeadLetterRoutingKey
        };

        await channel.QueueDeclareAsync(
            options.PasswordResetQueueName,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: queueArguments,
            cancellationToken: cancellationToken);

        await channel.QueueBindAsync(
            options.PasswordResetQueueName,
            options.ExchangeName,
            options.PasswordResetRoutingKey,
            cancellationToken: cancellationToken);
    }
}
