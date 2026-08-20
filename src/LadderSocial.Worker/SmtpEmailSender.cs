using LadderSocial.Application.Common.Options;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;

namespace LadderSocial.Worker;

public sealed class SmtpEmailSender(IOptions<SmtpOptions> options) : IEmailSender
{
    private readonly SmtpOptions _options = options.Value;

    public async Task SendPasswordResetAsync(
        string recipientEmail,
        string displayName,
        string resetCode,
        DateTime expiresAtUtc,
        CancellationToken cancellationToken)
    {
        var greetingName = string.IsNullOrWhiteSpace(displayName)
            ? "Ladder Social user"
            : displayName.Trim();
        var expiryText = expiresAtUtc.ToString("yyyy-MM-dd HH:mm 'UTC'");

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_options.FromName, _options.FromAddress));
        message.To.Add(MailboxAddress.Parse(recipientEmail));
        message.Subject = "Your Ladder Social password reset code";
        message.Body = new BodyBuilder
        {
            TextBody = $"""
                Hello {greetingName},

                Your Ladder Social password reset code is: {resetCode}

                The code expires at {expiryText}. If you did not request this reset, you can ignore this message.

                Ladder Social
                """,
            HtmlBody = $"""
                <p>Hello {System.Net.WebUtility.HtmlEncode(greetingName)},</p>
                <p>Your Ladder Social password reset code is:</p>
                <p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">{resetCode}</p>
                <p>The code expires at <strong>{expiryText}</strong>.</p>
                <p>If you did not request this reset, you can ignore this message.</p>
                <p>Ladder Social</p>
                """
        }.ToMessageBody();

        using var client = new SmtpClient();
        var socketOptions = _options.UseSsl
            ? SecureSocketOptions.SslOnConnect
            : _options.UseStartTls
                ? SecureSocketOptions.StartTls
                : SecureSocketOptions.None;

        await client.ConnectAsync(
            _options.Host,
            _options.Port,
            socketOptions,
            cancellationToken);

        if (!string.IsNullOrWhiteSpace(_options.Username))
        {
            await client.AuthenticateAsync(
                _options.Username,
                _options.Password,
                cancellationToken);
        }

        await client.SendAsync(message, cancellationToken);
        await client.DisconnectAsync(true, cancellationToken);
    }
}
