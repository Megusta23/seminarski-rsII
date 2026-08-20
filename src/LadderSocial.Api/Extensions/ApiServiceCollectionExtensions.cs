using System.Security.Claims;
using System.Text;
using LadderSocial.Application.Common.Security;
using LadderSocial.Infrastructure.Identity;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

namespace LadderSocial.Api.Extensions;

public static class ApiServiceCollectionExtensions
{
    public const string CorsPolicyName = "ClientApps";

    public static IServiceCollection AddJwtAuthentication(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var key = Require(configuration, "JWT_KEY");
        var issuer = Require(configuration, "JWT_ISSUER");
        var audience = Require(configuration, "JWT_AUDIENCE");

        if (key.Length < 64)
        {
            throw new InvalidOperationException("JWT_KEY must contain at least 64 characters.");
        }

        services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.MapInboundClaims = false;
                options.RequireHttpsMetadata = false;
                options.SaveToken = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = issuer,
                    ValidateAudience = true,
                    ValidAudience = audience,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),
                    NameClaimType = ClaimTypes.Name,
                    RoleClaimType = ClaimTypes.Role,
                    ClockSkew = TimeSpan.FromSeconds(30)
                };

                options.Events = new JwtBearerEvents
                {
                    OnMessageReceived = context =>
                    {
                        var accessToken = context.Request.Query["access_token"].FirstOrDefault();
                        var path = context.HttpContext.Request.Path;

                        if (!string.IsNullOrWhiteSpace(accessToken) && path.StartsWithSegments("/hubs"))
                        {
                            context.Token = accessToken;
                        }

                        return Task.CompletedTask;
                    },
                    OnTokenValidated = async context =>
                    {
                        var principal = context.Principal;
                        var userIdValue = principal?.FindFirstValue(ClaimTypes.NameIdentifier)
                            ?? principal?.FindFirstValue("sub");
                        var tokenSecurityStamp = principal?.FindFirstValue(JwtClaimNames.SecurityStamp);

                        if (!Guid.TryParse(userIdValue, out var userId) || tokenSecurityStamp is null)
                        {
                            context.Fail("The access token does not contain the required identity claims.");
                            return;
                        }

                        var userManager = context.HttpContext.RequestServices
                            .GetRequiredService<UserManager<AppUser>>();
                        var user = await userManager.FindByIdAsync(userId.ToString());

                        if (user is null || !user.IsActive)
                        {
                            context.Fail("The account associated with the access token is unavailable.");
                            return;
                        }

                        if (!string.Equals(
                                user.SecurityStamp ?? string.Empty,
                                tokenSecurityStamp,
                                StringComparison.Ordinal))
                        {
                            context.Fail("The access token has been invalidated.");
                        }
                    },
                    OnChallenge = async context =>
                    {
                        context.HandleResponse();
                        await WriteAuthenticationProblemAsync(
                            context.HttpContext,
                            StatusCodes.Status401Unauthorized,
                            "Unauthorized",
                            "A valid access token is required to access this resource.");
                    },
                    OnForbidden = context => WriteAuthenticationProblemAsync(
                        context.HttpContext,
                        StatusCodes.Status403Forbidden,
                        "Forbidden",
                        "Your account does not have permission to access this resource.")
                };
            });

        return services;
    }

    public static IServiceCollection AddConfiguredCors(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var origins = (configuration["CORS_ORIGINS"] ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        services.AddCors(options =>
        {
            options.AddPolicy(CorsPolicyName, policy =>
            {
                if (origins.Length == 0)
                {
                    policy.WithOrigins("http://localhost");
                }
                else
                {
                    policy.WithOrigins(origins);
                }

                policy.AllowAnyHeader().AllowAnyMethod().AllowCredentials();
            });
        });

        return services;
    }

    private static async Task WriteAuthenticationProblemAsync(
        HttpContext httpContext,
        int statusCode,
        string title,
        string detail)
    {
        if (httpContext.Response.HasStarted)
        {
            return;
        }

        var problem = new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = detail,
            Instance = httpContext.Request.Path
        };
        problem.Extensions["traceId"] = httpContext.TraceIdentifier;

        httpContext.Response.StatusCode = statusCode;
        httpContext.Response.ContentType = "application/problem+json";
        httpContext.Response.Headers["Cache-Control"] = "no-store";
        httpContext.Response.Headers["Pragma"] = "no-cache";
        await httpContext.Response.WriteAsJsonAsync(problem);
    }

    private static string Require(IConfiguration configuration, string key)
    {
        var value = configuration[key];
        return string.IsNullOrWhiteSpace(value)
            ? throw new InvalidOperationException($"{key} is not configured.")
            : value;
    }
}
