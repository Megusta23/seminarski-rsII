namespace LadderSocial.Application.Common.Options;

public sealed class SmtpOptions
{
    public string Host { get; set; } = string.Empty;
    public int Port { get; set; } = 25;
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public bool UseSsl { get; set; }
    public bool UseStartTls { get; set; }
    public string FromAddress { get; set; } = string.Empty;
    public string FromName { get; set; } = "Ladder Social";
}
