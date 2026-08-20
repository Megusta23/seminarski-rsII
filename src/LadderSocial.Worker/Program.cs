using LadderSocial.Application.Common.Options;
using LadderSocial.Infrastructure;
using LadderSocial.Worker;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddInfrastructure(builder.Configuration);
builder.Services
    .AddOptions<SmtpOptions>()
    .Configure(options =>
    {
        options.Host = Require(builder.Configuration, "SMTP_HOST");
        options.Port = GetPositiveInt(builder.Configuration, "SMTP_PORT", 25);
        options.Username = builder.Configuration["SMTP_USERNAME"]?.Trim() ?? string.Empty;
        options.Password = builder.Configuration["SMTP_PASSWORD"] ?? string.Empty;
        options.UseSsl = GetBoolean(builder.Configuration, "SMTP_USE_SSL", false);
        options.UseStartTls = GetBoolean(builder.Configuration, "SMTP_USE_STARTTLS", false);
        options.FromAddress = Require(builder.Configuration, "SMTP_FROM_ADDRESS");
        options.FromName = builder.Configuration["SMTP_FROM_NAME"]?.Trim() is { Length: > 0 } name
            ? name
            : "Ladder Social";
    })
    .Validate(options => options.Port is > 0 and <= 65535,
        "SMTP_PORT must be between 1 and 65535.")
    .Validate(options => !(options.UseSsl && options.UseStartTls),
        "SMTP_USE_SSL and SMTP_USE_STARTTLS cannot both be true.")
    .ValidateOnStart();

builder.Services.AddSingleton<IEmailSender, SmtpEmailSender>();
builder.Services.AddHostedService<PasswordResetEmailConsumerService>();

var host = builder.Build();
await host.RunAsync();

static string Require(IConfiguration configuration, string key)
{
    var value = configuration[key];
    return string.IsNullOrWhiteSpace(value)
        ? throw new InvalidOperationException($"{key} is not configured.")
        : value.Trim();
}

static int GetPositiveInt(IConfiguration configuration, string key, int defaultValue)
{
    var raw = configuration[key];
    if (string.IsNullOrWhiteSpace(raw))
    {
        return defaultValue;
    }

    return int.TryParse(raw, out var value) && value > 0
        ? value
        : throw new InvalidOperationException($"{key} must be a positive integer.");
}

static bool GetBoolean(IConfiguration configuration, string key, bool defaultValue)
{
    var raw = configuration[key];
    if (string.IsNullOrWhiteSpace(raw))
    {
        return defaultValue;
    }

    return bool.TryParse(raw, out var value)
        ? value
        : throw new InvalidOperationException($"{key} must be true or false.");
}
