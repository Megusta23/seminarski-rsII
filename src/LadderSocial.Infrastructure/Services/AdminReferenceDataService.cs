using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.ReferenceData;
using LadderSocial.Domain.Common;
using LadderSocial.Domain.Entities;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class AdminReferenceDataService(ApplicationDbContext dbContext) : IAdminReferenceDataService
{
    public async Task<PagedResult<AdminCountryResponse>> GetCountriesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken)
    {
        var query = dbContext.Countries.AsNoTracking().AsQueryable();
        query = ApplyReferenceFilters(query, request);

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(item => item.SortOrder)
            .ThenBy(item => item.Name)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new AdminCountryResponse(
                item.Id,
                item.IsoCode,
                item.Name,
                item.IsActive,
                item.SortOrder))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<AdminCountryResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<AdminCountryResponse> GetCountryAsync(Guid id, CancellationToken cancellationToken) =>
        await dbContext.Countries
            .AsNoTracking()
            .Where(item => item.Id == id)
            .Select(item => new AdminCountryResponse(
                item.Id,
                item.IsoCode,
                item.Name,
                item.IsActive,
                item.SortOrder))
            .SingleOrDefaultAsync(cancellationToken)
        ?? throw new NotFoundException("The requested country was not found.");

    public async Task<AdminCountryResponse> CreateCountryAsync(
        CreateCountryRequest request,
        CancellationToken cancellationToken)
    {
        var name = NormalizeName(request.Name, "name", 100);
        var isoCode = NormalizeIsoCode(request.IsoCode);
        await EnsureCountryUniqueAsync(null, name, isoCode, cancellationToken);

        var entity = new Country
        {
            Name = name,
            IsoCode = isoCode,
            SortOrder = request.SortOrder,
            IsActive = true
        };

        dbContext.Countries.Add(entity);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetCountryAsync(entity.Id, cancellationToken);
    }

    public async Task<AdminCountryResponse> UpdateCountryAsync(
        Guid id,
        UpdateCountryRequest request,
        CancellationToken cancellationToken)
    {
        var entity = await dbContext.Countries
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested country was not found.");
        var name = NormalizeName(request.Name, "name", 100);
        var isoCode = NormalizeIsoCode(request.IsoCode);
        await EnsureCountryUniqueAsync(id, name, isoCode, cancellationToken);

        entity.Name = name;
        entity.IsoCode = isoCode;
        entity.IsActive = request.IsActive;
        entity.SortOrder = request.SortOrder;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetCountryAsync(entity.Id, cancellationToken);
    }

    public async Task DeactivateCountryAsync(Guid id, CancellationToken cancellationToken)
    {
        var entity = await dbContext.Countries
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested country was not found.");

        var strategy = dbContext.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
            entity.IsActive = false;
            var cities = await dbContext.Cities
                .Where(item => item.CountryId == id && item.IsActive)
                .ToListAsync(cancellationToken);
            foreach (var city in cities)
            {
                city.IsActive = false;
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        });
    }

    public async Task<PagedResult<AdminCityResponse>> GetCitiesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken)
    {
        var query =
            from city in dbContext.Cities.AsNoTracking()
            join country in dbContext.Countries.AsNoTracking() on city.CountryId equals country.Id
            select new { City = city, CountryName = country.Name };

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.City.Name, $"%{search}%") ||
                EF.Functions.Like(item.CountryName, $"%{search}%"));
        }

        if (request.IsActive.HasValue)
        {
            query = query.Where(item => item.City.IsActive == request.IsActive.Value);
        }

        if (request.CountryId.HasValue)
        {
            query = query.Where(item => item.City.CountryId == request.CountryId.Value);
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(item => item.City.SortOrder)
            .ThenBy(item => item.City.Name)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new AdminCityResponse(
                item.City.Id,
                item.City.Name,
                item.City.CountryId,
                item.CountryName,
                item.City.IsActive,
                item.City.SortOrder))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<AdminCityResponse>(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<AdminCityResponse> GetCityAsync(Guid id, CancellationToken cancellationToken) =>
        await (
                from city in dbContext.Cities.AsNoTracking()
                join country in dbContext.Countries.AsNoTracking() on city.CountryId equals country.Id
                where city.Id == id
                select new AdminCityResponse(
                    city.Id,
                    city.Name,
                    city.CountryId,
                    country.Name,
                    city.IsActive,
                    city.SortOrder))
            .SingleOrDefaultAsync(cancellationToken)
        ?? throw new NotFoundException("The requested city was not found.");

    public async Task<AdminCityResponse> CreateCityAsync(
        CreateCityRequest request,
        CancellationToken cancellationToken)
    {
        var name = NormalizeName(request.Name, "name", 150);
        await EnsureActiveCountryAsync(request.CountryId, cancellationToken);
        await EnsureCityUniqueAsync(null, request.CountryId, name, cancellationToken);

        var entity = new City
        {
            Name = name,
            CountryId = request.CountryId,
            SortOrder = request.SortOrder,
            IsActive = true
        };

        dbContext.Cities.Add(entity);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetCityAsync(entity.Id, cancellationToken);
    }

    public async Task<AdminCityResponse> UpdateCityAsync(
        Guid id,
        UpdateCityRequest request,
        CancellationToken cancellationToken)
    {
        var entity = await dbContext.Cities
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested city was not found.");
        var name = NormalizeName(request.Name, "name", 150);
        await EnsureCountryExistsAsync(request.CountryId, cancellationToken);
        if (request.IsActive)
        {
            await EnsureActiveCountryAsync(request.CountryId, cancellationToken);
        }

        await EnsureCityUniqueAsync(id, request.CountryId, name, cancellationToken);
        entity.Name = name;
        entity.CountryId = request.CountryId;
        entity.IsActive = request.IsActive;
        entity.SortOrder = request.SortOrder;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetCityAsync(entity.Id, cancellationToken);
    }

    public async Task DeactivateCityAsync(Guid id, CancellationToken cancellationToken)
    {
        var entity = await dbContext.Cities
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested city was not found.");
        entity.IsActive = false;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public Task<PagedResult<AdminReferenceItemResponse>> GetTaskCategoriesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        GetReferenceItemsAsync(dbContext.TaskCategories.AsNoTracking(), request, cancellationToken);

    public Task<AdminReferenceItemResponse> GetTaskCategoryAsync(Guid id, CancellationToken cancellationToken) =>
        GetReferenceItemAsync(dbContext.TaskCategories.AsNoTracking(), id, "task category", cancellationToken);

    public async Task<AdminReferenceItemResponse> CreateTaskCategoryAsync(
        CreateReferenceItemRequest request,
        CancellationToken cancellationToken)
    {
        var (name, code) = NormalizeReferenceRequest(request.Name, request.Code);
        await EnsureReferenceUniqueAsync(dbContext.TaskCategories, null, name, code, "task category", cancellationToken);
        var entity = new TaskCategory
        {
            Name = name,
            Code = code,
            SortOrder = request.SortOrder,
            IsActive = true
        };
        dbContext.TaskCategories.Add(entity);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetTaskCategoryAsync(entity.Id, cancellationToken);
    }

    public async Task<AdminReferenceItemResponse> UpdateTaskCategoryAsync(
        Guid id,
        UpdateReferenceItemRequest request,
        CancellationToken cancellationToken)
    {
        var entity = await dbContext.TaskCategories
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested task category was not found.");
        var (name, code) = NormalizeReferenceRequest(request.Name, request.Code);
        await EnsureReferenceUniqueAsync(dbContext.TaskCategories, id, name, code, "task category", cancellationToken);
        entity.Name = name;
        entity.Code = code;
        entity.IsActive = request.IsActive;
        entity.SortOrder = request.SortOrder;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetTaskCategoryAsync(id, cancellationToken);
    }

    public async Task DeactivateTaskCategoryAsync(Guid id, CancellationToken cancellationToken)
    {
        var entity = await dbContext.TaskCategories
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested task category was not found.");
        entity.IsActive = false;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public Task<PagedResult<AdminReferenceItemResponse>> GetRecurrenceTypesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        GetReferenceItemsAsync(dbContext.RecurrenceTypes.AsNoTracking(), request, cancellationToken);

    public Task<AdminReferenceItemResponse> GetRecurrenceTypeAsync(Guid id, CancellationToken cancellationToken) =>
        GetReferenceItemAsync(dbContext.RecurrenceTypes.AsNoTracking(), id, "recurrence type", cancellationToken);

    public async Task<AdminReferenceItemResponse> CreateRecurrenceTypeAsync(
        CreateReferenceItemRequest request,
        CancellationToken cancellationToken)
    {
        var (name, code) = NormalizeReferenceRequest(request.Name, request.Code);
        await EnsureReferenceUniqueAsync(dbContext.RecurrenceTypes, null, name, code, "recurrence type", cancellationToken);
        var entity = new RecurrenceType
        {
            Name = name,
            Code = code,
            SortOrder = request.SortOrder,
            IsActive = true
        };
        dbContext.RecurrenceTypes.Add(entity);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetRecurrenceTypeAsync(entity.Id, cancellationToken);
    }

    public async Task<AdminReferenceItemResponse> UpdateRecurrenceTypeAsync(
        Guid id,
        UpdateReferenceItemRequest request,
        CancellationToken cancellationToken)
    {
        var entity = await dbContext.RecurrenceTypes
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested recurrence type was not found.");
        var (name, code) = NormalizeReferenceRequest(request.Name, request.Code);
        await EnsureReferenceUniqueAsync(dbContext.RecurrenceTypes, id, name, code, "recurrence type", cancellationToken);
        entity.Name = name;
        entity.Code = code;
        entity.IsActive = request.IsActive;
        entity.SortOrder = request.SortOrder;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetRecurrenceTypeAsync(id, cancellationToken);
    }

    public async Task DeactivateRecurrenceTypeAsync(Guid id, CancellationToken cancellationToken)
    {
        var entity = await dbContext.RecurrenceTypes
            .SingleOrDefaultAsync(item => item.Id == id, cancellationToken)
            ?? throw new NotFoundException("The requested recurrence type was not found.");
        entity.IsActive = false;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static IQueryable<T> ApplyReferenceFilters<T>(
        IQueryable<T> query,
        ReferenceDataListRequest request)
        where T : ReferenceEntity
    {
        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item => EF.Functions.Like(item.Name, $"%{search}%"));
        }

        if (request.IsActive.HasValue)
        {
            query = query.Where(item => item.IsActive == request.IsActive.Value);
        }

        return query;
    }

    private static async Task<PagedResult<AdminReferenceItemResponse>> GetReferenceItemsAsync<T>(
        IQueryable<T> source,
        ReferenceDataListRequest request,
        CancellationToken cancellationToken)
        where T : ReferenceEntity
    {
        var query = ApplyReferenceFilters(source, request);
        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(item => item.SortOrder)
            .ThenBy(item => item.Name)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new AdminReferenceItemResponse(
                item.Id,
                EF.Property<string>(item, "Code"),
                item.Name,
                item.IsActive,
                item.SortOrder))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<AdminReferenceItemResponse>(items, request.Page, request.PageSize, totalCount);
    }

    private static async Task<AdminReferenceItemResponse> GetReferenceItemAsync<T>(
        IQueryable<T> source,
        Guid id,
        string entityName,
        CancellationToken cancellationToken)
        where T : ReferenceEntity =>
        await source
            .Where(item => item.Id == id)
            .Select(item => new AdminReferenceItemResponse(
                item.Id,
                EF.Property<string>(item, "Code"),
                item.Name,
                item.IsActive,
                item.SortOrder))
            .SingleOrDefaultAsync(cancellationToken)
        ?? throw new NotFoundException($"The requested {entityName} was not found.");

    private static string NormalizeName(string value, string field, int maximumLength)
    {
        var normalized = value?.Trim() ?? string.Empty;
        if (normalized.Length is 0 || normalized.Length > maximumLength)
        {
            throw new ValidationException(
                "Reference-data validation failed.",
                new Dictionary<string, string[]>
                {
                    [field] = [$"A value between 1 and {maximumLength} characters is required."]
                });
        }

        return normalized;
    }

    private static string NormalizeIsoCode(string value)
    {
        var normalized = value?.Trim().ToUpperInvariant() ?? string.Empty;
        if (normalized.Length is < 2 or > 3 || normalized.Any(character => !char.IsLetter(character)))
        {
            throw new ValidationException(
                "Reference-data validation failed.",
                new Dictionary<string, string[]>
                {
                    ["isoCode"] = ["Enter a two- or three-letter country ISO code."]
                });
        }

        return normalized;
    }

    private static (string Name, string Code) NormalizeReferenceRequest(string name, string code)
    {
        var normalizedName = NormalizeName(name, "name", 100);
        var normalizedCode = code?.Trim().ToLowerInvariant() ?? string.Empty;
        if (normalizedCode.Length is 0 or > 50 ||
            normalizedCode.Any(character => !char.IsLetterOrDigit(character) && character is not '-' and not '_'))
        {
            throw new ValidationException(
                "Reference-data validation failed.",
                new Dictionary<string, string[]>
                {
                    ["code"] = ["Code is required and may contain letters, numbers, hyphens, and underscores only."]
                });
        }

        return (normalizedName, normalizedCode);
    }

    private async Task EnsureCountryUniqueAsync(
        Guid? currentId,
        string name,
        string isoCode,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.Countries.AnyAsync(
            item => (!currentId.HasValue || item.Id != currentId.Value) &&
                (item.Name == name || item.IsoCode == isoCode),
            cancellationToken);
        if (exists)
        {
            throw new ConflictException("A country with the same name or ISO code already exists.");
        }
    }

    private async Task EnsureCityUniqueAsync(
        Guid? currentId,
        Guid countryId,
        string name,
        CancellationToken cancellationToken)
    {
        var exists = await dbContext.Cities.AnyAsync(
            item => (!currentId.HasValue || item.Id != currentId.Value) &&
                item.CountryId == countryId && item.Name == name,
            cancellationToken);
        if (exists)
        {
            throw new ConflictException("A city with the same name already exists in the selected country.");
        }
    }

    private async Task EnsureCountryExistsAsync(Guid id, CancellationToken cancellationToken)
    {
        if (!await dbContext.Countries.AnyAsync(item => item.Id == id, cancellationToken))
        {
            throw new ValidationException(
                "Reference-data validation failed.",
                new Dictionary<string, string[]>
                {
                    ["countryId"] = ["Select an existing country."]
                });
        }
    }

    private async Task EnsureActiveCountryAsync(Guid id, CancellationToken cancellationToken)
    {
        if (!await dbContext.Countries.AnyAsync(item => item.Id == id && item.IsActive, cancellationToken))
        {
            throw new ValidationException(
                "Reference-data validation failed.",
                new Dictionary<string, string[]>
                {
                    ["countryId"] = ["Select an active country."]
                });
        }
    }

    private static async Task EnsureReferenceUniqueAsync<T>(
        DbSet<T> source,
        Guid? currentId,
        string name,
        string code,
        string entityName,
        CancellationToken cancellationToken)
        where T : ReferenceEntity
    {
        var exists = await source.AnyAsync(
            item => (!currentId.HasValue || item.Id != currentId.Value) &&
                (item.Name == name || EF.Property<string>(item, "Code") == code),
            cancellationToken);
        if (exists)
        {
            throw new ConflictException($"A {entityName} with the same name or code already exists.");
        }
    }
}
