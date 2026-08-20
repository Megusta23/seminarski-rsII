namespace LadderSocial.Application.Common.Options;

public sealed class PasswordResetOptions
{
    public string HashKey { get; set; } = string.Empty;
    public string EventEncryptionKey { get; set; } = string.Empty;
    public int CodeLifetimeMinutes { get; set; } = 15;
    public int MaxAttempts { get; set; } = 5;
    public int MinimumRequestIntervalSeconds { get; set; } = 60;
}
