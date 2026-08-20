using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Security;
using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace LadderSocial.Infrastructure.Persistence;

public sealed class DatabaseInitializer(
    ApplicationDbContext dbContext,
    RoleManager<IdentityRole<Guid>> roleManager,
    UserManager<AppUser> userManager,
    IDateTimeProvider dateTimeProvider,
    IConfiguration configuration,
    ILogger<DatabaseInitializer> logger)
{
    public async Task InitializeAsync(CancellationToken cancellationToken = default)
    {
        var bootstrapMode = configuration["DATABASE_BOOTSTRAP_MODE"]?.Trim().ToLowerInvariant() ?? "migrate";

        if (bootstrapMode == "ensure-created")
        {
            logger.LogWarning(
                "DATABASE_BOOTSTRAP_MODE is ensure-created. Use this only until InitialCreate migration exists.");
            await dbContext.Database.EnsureCreatedAsync(cancellationToken);
        }
        else
        {
            await dbContext.Database.MigrateAsync(cancellationToken);
        }

        await SeedRolesAsync();
        await SeedUsersAsync(cancellationToken);
        await SeedReferenceDataAsync(cancellationToken);
    }

    private async Task SeedRolesAsync()
    {
        foreach (var roleName in RoleNames.All)
        {
            if (!await roleManager.RoleExistsAsync(roleName))
            {
                var result = await roleManager.CreateAsync(new IdentityRole<Guid>(roleName));
                EnsureSucceeded(result, $"creating role {roleName}");
            }
        }
    }

    private async Task SeedUsersAsync(CancellationToken cancellationToken)
    {
        await SeedUserAsync(
            configuration["SEED_ADMIN_EMAIL"],
            configuration["SEED_ADMIN_PASSWORD"],
            "Ladder",
            "Admin",
            RoleNames.Admin,
            cancellationToken);

        await SeedUserAsync(
            configuration["SEED_MOBILE_EMAIL"],
            configuration["SEED_MOBILE_PASSWORD"],
            "Mobile",
            "User",
            RoleNames.User,
            cancellationToken);
    }

    private async Task SeedUserAsync(
        string? email,
        string? password,
        string firstName,
        string lastName,
        string role,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            logger.LogWarning("Skipping seed user for role {Role}; credentials are not configured.", role);
            return;
        }

        var displayName = $"{firstName} {lastName}".Trim();
        var user = await userManager.FindByEmailAsync(email);
        if (user is null)
        {
            user = new AppUser
            {
                Id = Guid.NewGuid(),
                Email = email,
                UserName = email,
                EmailConfirmed = true,
                DisplayName = displayName,
                CreatedAtUtc = dateTimeProvider.UtcNow,
                IsActive = true,
                LockoutEnabled = true
            };

            var createResult = await userManager.CreateAsync(user, password);
            EnsureSucceeded(createResult, $"creating seed user {email}");
        }
        else
        {
            var requiresUpdate = false;

            if (!user.LockoutEnabled)
            {
                user.LockoutEnabled = true;
                requiresUpdate = true;
            }

            if (!user.EmailConfirmed)
            {
                user.EmailConfirmed = true;
                requiresUpdate = true;
            }

            if (!user.IsActive)
            {
                user.IsActive = true;
                requiresUpdate = true;
            }

            if (!string.Equals(user.DisplayName, displayName, StringComparison.Ordinal))
            {
                user.DisplayName = displayName;
                requiresUpdate = true;
            }

            if (requiresUpdate)
            {
                var updateResult = await userManager.UpdateAsync(user);
                EnsureSucceeded(updateResult, $"updating seed user {email}");
            }
        }

        if (!await userManager.IsInRoleAsync(user, role))
        {
            var roleResult = await userManager.AddToRoleAsync(user, role);
            EnsureSucceeded(roleResult, $"assigning role {role} to {email}");
        }

        var profile = await dbContext.UserProfiles
            .IgnoreQueryFilters()
            .SingleOrDefaultAsync(item => item.UserId == user.Id, cancellationToken);

        if (profile is null)
        {
            dbContext.UserProfiles.Add(new UserProfile
            {
                UserId = user.Id,
                FirstName = firstName,
                LastName = lastName
            });
        }
        else if (profile.IsDeleted)
        {
            profile.IsDeleted = false;
            profile.DeletedAtUtc = null;
            profile.DeletedByUserId = null;
        }

        if (dbContext.ChangeTracker.HasChanges())
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }

    private async Task SeedReferenceDataAsync(CancellationToken cancellationToken)
    {
        if (!await dbContext.TaskCategories.AnyAsync(cancellationToken))
        {
            dbContext.TaskCategories.AddRange(
                NewTaskCategory("creative", "Creative", 10),
                NewTaskCategory("social", "Social", 20),
                NewTaskCategory("self-care", "Self-care", 30),
                NewTaskCategory("work", "Work", 40));
        }

        if (!await dbContext.RecurrenceTypes.AnyAsync(cancellationToken))
        {
            dbContext.RecurrenceTypes.AddRange(
                NewRecurrenceType("none", "Does not repeat", 10),
                NewRecurrenceType("daily", "Daily", 20),
                NewRecurrenceType("weekly", "Weekly", 30),
                NewRecurrenceType("monthly", "Monthly", 40));
        }

        if (!await dbContext.Countries.AnyAsync(cancellationToken))
        {
            var country = new Country
            {
                Id = Guid.NewGuid(),
                Name = "Bosnia and Herzegovina",
                IsoCode = "BIH",
                SortOrder = 10,
                IsActive = true
            };

            var sarajevo = new City
            {
                Id = Guid.NewGuid(),
                CountryId = country.Id,
                Name = "Sarajevo",
                SortOrder = 10,
                IsActive = true
            };

            var mostar = new City
            {
                Id = Guid.NewGuid(),
                CountryId = country.Id,
                Name = "Mostar",
                SortOrder = 20,
                IsActive = true
            };

            dbContext.Countries.Add(country);
            dbContext.Cities.AddRange(sarajevo, mostar);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static TaskCategory NewTaskCategory(string code, string name, int sortOrder) => new()
    {
        Id = Guid.NewGuid(),
        Code = code,
        Name = name,
        SortOrder = sortOrder,
        IsActive = true
    };

    private static RecurrenceType NewRecurrenceType(string code, string name, int sortOrder) => new()
    {
        Id = Guid.NewGuid(),
        Code = code,
        Name = name,
        SortOrder = sortOrder,
        IsActive = true
    };

    private static void EnsureSucceeded(IdentityResult result, string operation)
    {
        if (result.Succeeded)
        {
            return;
        }

        var errorText = string.Join("; ", result.Errors.Select(error => error.Description));
        throw new InvalidOperationException($"Identity operation failed while {operation}: {errorText}");
    }
}
