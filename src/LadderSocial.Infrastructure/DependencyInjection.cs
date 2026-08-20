using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Features.Auth;
using LadderSocial.Application.Features.Profiles;
using LadderSocial.Infrastructure.Identity;
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

        services.AddSingleton<IDateTimeProvider, SystemDateTimeProvider>();
        services.TryAddScoped<ICurrentUserService, SystemCurrentUserService>();
        services.AddScoped<DatabaseInitializer>();

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
        services.AddScoped<IProfileService, ProfileService>();

        return services;
    }

    private static string Require(IConfiguration configuration, string key)
    {
        var value = configuration[key];
        return string.IsNullOrWhiteSpace(value)
            ? throw new InvalidOperationException($"{key} is not configured.")
            : value;
    }

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
