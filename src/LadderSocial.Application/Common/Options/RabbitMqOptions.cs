namespace LadderSocial.Application.Common.Options;

public sealed class RabbitMqOptions
{
    public string Host { get; set; } = string.Empty;
    public int Port { get; set; } = 5672;
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string VirtualHost { get; set; } = "/";
    public string ExchangeName { get; set; } = "ladder-social.events";
    public string PasswordResetQueueName { get; set; } = "ladder-social.password-reset-email";
    public string PasswordResetRoutingKey { get; set; } = "auth.password-reset.requested";
    public string DeadLetterExchangeName { get; set; } = "ladder-social.dead-letter";
    public string PasswordResetDeadLetterQueueName { get; set; } = "ladder-social.password-reset-email.dead";
    public string PasswordResetDeadLetterRoutingKey { get; set; } = "auth.password-reset.dead";
}
