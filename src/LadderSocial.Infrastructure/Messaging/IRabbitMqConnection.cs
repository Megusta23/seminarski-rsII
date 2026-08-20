using RabbitMQ.Client;

namespace LadderSocial.Infrastructure.Messaging;

public interface IRabbitMqConnection : IAsyncDisposable
{
    Task<IConnection> GetConnectionAsync(CancellationToken cancellationToken);
}
