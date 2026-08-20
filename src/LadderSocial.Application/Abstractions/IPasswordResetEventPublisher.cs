using LadderSocial.Application.Common.Messaging;

namespace LadderSocial.Application.Abstractions;

public interface IPasswordResetEventPublisher
{
    Task PublishAsync(
        PasswordResetRequestedEvent message,
        CancellationToken cancellationToken);
}
