using LadderSocial.Application.Abstractions;

namespace LadderSocial.Worker;

public sealed class WorkerBootstrapService(
    IConfiguration configuration,
    IDateTimeProvider dateTimeProvider,
    ILogger<WorkerBootstrapService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var pollSeconds = int.TryParse(configuration["WORKER_POLL_SECONDS"], out var configuredSeconds)
            ? Math.Clamp(configuredSeconds, 5, 300)
            : 30;

        logger.LogInformation(
            "LadderSocial.Worker scaffold started. RabbitMQ consumer and real notification handling are the next implementation slice.");

        while (!stoppingToken.IsCancellationRequested)
        {
            logger.LogDebug("Worker process is alive at {TimestampUtc}", dateTimeProvider.UtcNow);
            await Task.Delay(TimeSpan.FromSeconds(pollSeconds), stoppingToken);
        }
    }
}
