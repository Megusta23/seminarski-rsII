using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Features.Admin;
using LadderSocial.Application.Features.Auth;
using LadderSocial.Application.Features.Chat;
using LadderSocial.Application.Features.Feed;
using LadderSocial.Application.Features.Friends;
using LadderSocial.Application.Features.Leaderboard;
using LadderSocial.Application.Features.Media;
using LadderSocial.Application.Features.Notifications;
using LadderSocial.Application.Features.Reports;
using LadderSocial.Application.Features.Tasks;
using LadderSocial.Application.Features.Profiles;
using LadderSocial.Application.Features.ReferenceData;
using LadderSocial.Infrastructure.Identity;
using LadderSocial.Infrastructure.Messaging;
using LadderSocial.Infrastructure.Persistence;
using LadderSocial.Infrastructure.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace LadderSocial.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = Require(configuration, "DATABASE_CONNECTION_STRING");

        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseSqlServer(
                connectionString,
                sqlOptions => sqlOptions.EnableRetryOnFailure(5, TimeSpan.FromSeconds(5), null)));

        services
            .AddOptions<RabbitMqOptions>()
            .Configure(options =>
            {
                options.Host = Require(configuration, "RABBITMQ_HOST");
                options.Port = GetPositiveInt(configuration, "RABBITMQ_PORT", 5672);
                options.Username = Require(configuration, "RABBITMQ_USERNAME");
                options.Password = Require(configuration, "RABBITMQ_PASSWORD");
                options.VirtualHost = configuration["RABBITMQ_VHOST"]?.Trim() is { Length: > 0 } virtualHost
                    ? virtualHost
                    : "/";
                options.ExchangeName = GetValue(
                    configuration,
                    "RABBITMQ_EXCHANGE_NAME",
                    "ladder-social.events");
                options.PasswordResetQueueName = GetValue(
                    configuration,
                    "RABBITMQ_PASSWORD_RESET_QUEUE",
                    "ladder-social.password-reset-email");
                options.PasswordResetRoutingKey = GetValue(
                    configuration,
                    "RABBITMQ_PASSWORD_RESET_ROUTING_KEY",
                    "auth.password-reset.requested");
                options.DeadLetterExchangeName = GetValue(
                    configuration,
                    "RABBITMQ_DEAD_LETTER_EXCHANGE",
                    "ladder-social.dead-letter");
                options.PasswordResetDeadLetterQueueName = GetValue(
                    configuration,
                    "RABBITMQ_PASSWORD_RESET_DEAD_LETTER_QUEUE",
                    "ladder-social.password-reset-email.dead");
                options.PasswordResetDeadLetterRoutingKey = GetValue(
                    configuration,
                    "RABBITMQ_PASSWORD_RESET_DEAD_LETTER_ROUTING_KEY",
                    "auth.password-reset.dead");
            })
            .Validate(options => options.Port is > 0 and <= 65535,
                "RABBITMQ_PORT must be between 1 and 65535.")
            .ValidateOnStart();

        services
            .AddOptions<PasswordResetOptions>()
            .Configure(options =>
            {
                options.HashKey = Require(configuration, "PASSWORD_RESET_HASH_KEY");
                options.EventEncryptionKey = Require(configuration, "PASSWORD_RESET_EVENT_KEY");
                options.CodeLifetimeMinutes = GetPositiveInt(
                    configuration,
                    "PASSWORD_RESET_CODE_MINUTES",
                    15);
                options.MaxAttempts = GetPositiveInt(
                    configuration,
                    "PASSWORD_RESET_MAX_ATTEMPTS",
                    5);
                options.MinimumRequestIntervalSeconds = GetPositiveInt(
                    configuration,
                    "PASSWORD_RESET_MIN_REQUEST_INTERVAL_SECONDS",
                    60);
            })
            .Validate(options => options.HashKey.Length >= 64,
                "PASSWORD_RESET_HASH_KEY must contain at least 64 characters.")
            .Validate(options => options.EventEncryptionKey.Length >= 64,
                "PASSWORD_RESET_EVENT_KEY must contain at least 64 characters.")
            .Validate(options => options.CodeLifetimeMinutes is >= 5 and <= 60,
                "PASSWORD_RESET_CODE_MINUTES must be between 5 and 60.")
            .Validate(options => options.MaxAttempts is >= 3 and <= 10,
                "PASSWORD_RESET_MAX_ATTEMPTS must be between 3 and 10.")
            .Validate(options => options.MinimumRequestIntervalSeconds is >= 10 and <= 3600,
                "PASSWORD_RESET_MIN_REQUEST_INTERVAL_SECONDS must be between 10 and 3600.")
            .ValidateOnStart();

        services.AddSingleton<IDateTimeProvider, SystemDateTimeProvider>();
        services.TryAddScoped<ICurrentUserService, SystemCurrentUserService>();
        services.AddSingleton<IRabbitMqConnection, RabbitMqConnection>();
        services.AddSingleton<IPasswordResetCodeService, PasswordResetCodeService>();
        services.TryAddScoped<IRealtimeNotifier, NoOpRealtimeNotifier>();
        return services;
    }

    /// <summary>
    /// Registers services used only by the HTTP API. Keeping these registrations
    /// separate prevents the Worker container from requiring JWT secrets it does
    /// not use.
    /// </summary>
    public static IServiceCollection AddApiFeatureInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services
            .AddIdentityCore<AppUser>(options =>
            {
                options.User.RequireUniqueEmail = true;
                options.Password.RequiredLength = 10;
                options.Password.RequireDigit = true;
                options.Password.RequireLowercase = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireNonAlphanumeric = true;
                options.Lockout.AllowedForNewUsers = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddSignInManager()
            .AddEntityFrameworkStores<ApplicationDbContext>()
            .AddDefaultTokenProviders();

        services
            .AddOptions<FileStorageOptions>()
            .Configure(options =>
            {
                options.RootPath = Require(configuration, "UPLOAD_ROOT");
                options.MaximumImageBytes = GetPositiveInt(
                    configuration,
                    "UPLOAD_MAX_IMAGE_BYTES",
                    5 * 1024 * 1024);
            })
            .Validate(options => options.MaximumImageBytes is >= 1024 and <= 20 * 1024 * 1024,
                "UPLOAD_MAX_IMAGE_BYTES must be between 1 KB and 20 MB.")
            .ValidateOnStart();

        services.AddSingleton<IFileStorageService, LocalFileStorageService>();

        services
            .AddOptions<JwtOptions>()
            .Configure(options =>
            {
                options.Key = Require(configuration, "JWT_KEY");
                options.Issuer = Require(configuration, "JWT_ISSUER");
                options.Audience = Require(configuration, "JWT_AUDIENCE");
                options.AccessTokenMinutes = GetPositiveInt(
                    configuration,
                    "JWT_ACCESS_TOKEN_MINUTES",
                    30);
                options.RefreshTokenDays = GetPositiveInt(
                    configuration,
                    "JWT_REFRESH_TOKEN_DAYS",
                    14);
            })
            .Validate(options => options.Key.Length >= 64, "JWT_KEY must contain at least 64 characters.")
            .Validate(options => options.AccessTokenMinutes is > 0 and <= 1440,
                "JWT_ACCESS_TOKEN_MINUTES must be between 1 and 1440.")
            .Validate(options => options.RefreshTokenDays is > 0 and <= 90,
                "JWT_REFRESH_TOKEN_DAYS must be between 1 and 90.")
            .ValidateOnStart();

        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IPasswordResetEventPublisher, PasswordResetEventPublisher>();
        services.AddScoped<IPasswordRecoveryService, PasswordRecoveryService>();
        services.AddScoped<IProfileService, ProfileService>();
        services.AddScoped<IReferenceDataService, ReferenceDataService>();
        services.AddScoped<IAdminReferenceDataService, AdminReferenceDataService>();
        services.AddScoped<ITaskService, TaskService>();
        services.AddScoped<IMediaService, MediaService>();
        services.AddScoped<IFeedService, FeedService>();
        services.AddScoped<IFriendService, FriendService>();
        services.AddScoped<ILeaderboardService, LeaderboardService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IChatService, ChatService>();
        services.AddScoped<IAdminService, AdminService>();
        services.AddScoped<IReportService, ReportService>();
        services.AddScoped<DatabaseInitializer>();

        return services;
    }

    private static string Require(IConfiguration configuration, string key)
    {
        var value = configuration[key];
        return string.IsNullOrWhiteSpace(value)
            ? throw new InvalidOperationException($"{key} is not configured.")
            : value.Trim();
    }

    private static string GetValue(
        IConfiguration configuration,
        string key,
        string defaultValue) =>
        string.IsNullOrWhiteSpace(configuration[key])
            ? defaultValue
            : configuration[key]!.Trim();

    private static int GetPositiveInt(
        IConfiguration configuration,
        string key,
        int defaultValue)
    {
        var rawValue = configuration[key];
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return defaultValue;
        }

        return int.TryParse(rawValue, out var parsed) && parsed > 0
            ? parsed
            : throw new InvalidOperationException($"{key} must be a positive integer.");
    }
}
