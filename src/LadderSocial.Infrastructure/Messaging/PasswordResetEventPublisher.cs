using System.Text;
using System.Text.Json;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Messaging;
using LadderSocial.Application.Common.Options;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;

namespace LadderSocial.Infrastructure.Messaging;

public sealed class PasswordResetEventPublisher(
    IRabbitMqConnection rabbitMqConnection,
    IOptions<RabbitMqOptions> options) : IPasswordResetEventPublisher
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly RabbitMqOptions _options = options.Value;

    public async Task PublishAsync(
        PasswordResetRequestedEvent message,
        CancellationToken cancellationToken)
    {
        var connection = await rabbitMqConnection.GetConnectionAsync(cancellationToken);
        await using var channel = await connection.CreateChannelAsync(
            cancellationToken: cancellationToken);

        await RabbitMqTopology.DeclarePasswordResetTopologyAsync(
            channel,
            _options,
            cancellationToken);

        var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message, JsonOptions));
        var properties = new BasicProperties
        {
            AppId = "LadderSocial.Api",
            ContentType = "application/json",
            ContentEncoding = "utf-8",
            MessageId = message.MessageId.ToString(),
            Type = PasswordResetRequestedEvent.EventType,
            Persistent = true,
            Timestamp = new AmqpTimestamp(
                new DateTimeOffset(message.RequestedAtUtc).ToUnixTimeSeconds())
        };

        await channel.BasicPublishAsync(
            _options.ExchangeName,
            _options.PasswordResetRoutingKey,
            mandatory: true,
            basicProperties: properties,
            body: body,
            cancellationToken: cancellationToken);
    }
}
