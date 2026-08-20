using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Features.Profiles;
using LadderSocial.Infrastructure.Identity;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class ProfileService(
    ApplicationDbContext dbContext,
    UserManager<AppUser> userManager,
    ICurrentUserService currentUserService,
    IDateTimeProvider dateTimeProvider,
    IFileStorageService fileStorageService) : IProfileService
{
    public async Task<CurrentProfileResponse> GetCurrentAsync(
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var user = await userManager.FindByIdAsync(userId.ToString())
            ?? throw new NotFoundException("The current user account was not found.");

        var profile = await (
                from userProfile in dbContext.UserProfiles.AsNoTracking()
                join city in dbContext.Cities.AsNoTracking()
                    on userProfile.CityId equals (Guid?)city.Id into cities
                from city in cities.DefaultIfEmpty()
                where userProfile.UserId == userId
                select new
                {
                    userProfile.FirstName,
                    userProfile.LastName,
                    userProfile.Bio,
                    userProfile.AvatarStorageKey,
                    userProfile.CityId,
                    CityName = city == null ? null : city.Name,
                    userProfile.DateOfBirth
                })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new NotFoundException("The current user profile was not found.");

        var roles = (await userManager.GetRolesAsync(user))
            .OrderBy(role => role, StringComparer.Ordinal)
            .ToArray();

        return new CurrentProfileResponse(
            user.Id,
            user.Email ?? string.Empty,
            user.DisplayName,
            profile.FirstName,
            profile.LastName,
            profile.Bio,
            profile.AvatarStorageKey is null ? null : $"/api/media/avatars/{user.Id}",
            profile.CityId,
            profile.CityName,
            profile.DateOfBirth,
            roles);
    }

    public async Task<CurrentProfileResponse> UpdateCurrentAsync(
        UpdateProfileRequest request,
        CancellationToken cancellationToken)
    {
        ValidateUpdateRequest(request);
        var userId = RequireCurrentUserId();
        var firstName = request.FirstName.Trim();
        var lastName = request.LastName.Trim();
        var bio = string.IsNullOrWhiteSpace(request.Bio) ? null : request.Bio.Trim();
        var strategy = dbContext.Database.CreateExecutionStrategy();

        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);

            var user = await userManager.FindByIdAsync(userId.ToString())
                ?? throw new NotFoundException("The current user account was not found.");
            var profile = await dbContext.UserProfiles
                .SingleOrDefaultAsync(item => item.UserId == userId, cancellationToken)
                ?? throw new NotFoundException("The current user profile was not found.");

            if (request.CityId.HasValue)
            {
                var cityExists = await dbContext.Cities
                    .AnyAsync(
                        city => city.Id == request.CityId.Value && city.IsActive,
                        cancellationToken);

                if (!cityExists)
                {
                    throw new ValidationException(
                        "Profile validation failed.",
                        new Dictionary<string, string[]>
                        {
                            ["cityId"] = ["Select an active city from the available list."]
                        });
                }
            }

            profile.FirstName = firstName;
            profile.LastName = lastName;
            profile.Bio = bio;
            profile.CityId = request.CityId;
            profile.DateOfBirth = request.DateOfBirth;
            user.DisplayName = $"{firstName} {lastName}".Trim();

            var updateResult = await userManager.UpdateAsync(user);
            if (!updateResult.Succeeded)
            {
                var errors = string.Join("; ", updateResult.Errors.Select(error => error.Description));
                throw new InvalidOperationException($"Could not update the current account: {errors}");
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });

        return await GetCurrentAsync(cancellationToken);
    }

    public async Task<CurrentProfileResponse> UpdateAvatarAsync(
        UploadPayload upload,
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var stored = await fileStorageService.SaveImageAsync(
            $"avatars/{userId:N}",
            upload,
            cancellationToken);
        var profile = await dbContext.UserProfiles
            .SingleOrDefaultAsync(item => item.UserId == userId, cancellationToken)
            ?? throw new NotFoundException("The current user profile was not found.");
        var previousStorageKey = profile.AvatarStorageKey;
        profile.AvatarStorageKey = stored.StorageKey;
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch
        {
            await fileStorageService.DeleteIfExistsAsync(stored.StorageKey, cancellationToken);
            throw;
        }

        if (!string.IsNullOrWhiteSpace(previousStorageKey))
        {
            await fileStorageService.DeleteIfExistsAsync(previousStorageKey, cancellationToken);
        }

        return await GetCurrentAsync(cancellationToken);
    }

    public async Task<CurrentProfileResponse> RemoveAvatarAsync(
        CancellationToken cancellationToken)
    {
        var userId = RequireCurrentUserId();
        var profile = await dbContext.UserProfiles
            .SingleOrDefaultAsync(item => item.UserId == userId, cancellationToken)
            ?? throw new NotFoundException("The current user profile was not found.");
        var storageKey = profile.AvatarStorageKey;
        profile.AvatarStorageKey = null;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (!string.IsNullOrWhiteSpace(storageKey))
        {
            await fileStorageService.DeleteIfExistsAsync(storageKey, cancellationToken);
        }

        return await GetCurrentAsync(cancellationToken);
    }

    private Guid RequireCurrentUserId() =>
        currentUserService.UserId
        ?? throw new UnauthorizedException("Authentication is required to access a profile.");

    private void ValidateUpdateRequest(UpdateProfileRequest request)
    {
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);

        if (string.IsNullOrWhiteSpace(request.FirstName) || request.FirstName.Trim().Length > 100)
        {
            errors["firstName"] = ["First name is required and may contain at most 100 characters."];
        }

        if (string.IsNullOrWhiteSpace(request.LastName) || request.LastName.Trim().Length > 100)
        {
            errors["lastName"] = ["Last name is required and may contain at most 100 characters."];
        }

        if (request.Bio?.Trim().Length > 500)
        {
            errors["bio"] = ["Biography may contain at most 500 characters."];
        }

        if (request.DateOfBirth.HasValue &&
            request.DateOfBirth.Value > DateOnly.FromDateTime(dateTimeProvider.UtcNow))
        {
            errors["dateOfBirth"] = ["Date of birth cannot be in the future."];
        }

        if (errors.Count > 0)
        {
            throw new ValidationException("Profile validation failed.", errors);
        }
    }
}
