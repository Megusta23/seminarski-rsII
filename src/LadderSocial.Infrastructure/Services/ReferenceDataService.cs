using LadderSocial.Application.Features.ReferenceData;
using LadderSocial.Domain.Constants;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class ReferenceDataService(ApplicationDbContext dbContext) : IReferenceDataService
{
    public async Task<IReadOnlyCollection<CountryResponse>> GetCountriesAsync(
        CancellationToken cancellationToken) =>
        await dbContext.Countries
            .AsNoTracking()
            .Where(country => country.IsActive)
            .OrderBy(country => country.SortOrder)
            .ThenBy(country => country.Name)
            .Select(country => new CountryResponse(
                country.Id,
                country.IsoCode,
                country.Name))
            .ToArrayAsync(cancellationToken);

    public async Task<IReadOnlyCollection<CityResponse>> GetCitiesAsync(
        Guid? countryId,
        CancellationToken cancellationToken)
    {
        var query =
            from city in dbContext.Cities.AsNoTracking()
            join country in dbContext.Countries.AsNoTracking()
                on city.CountryId equals country.Id
            where city.IsActive && country.IsActive
            select new
            {
                City = city,
                CountryName = country.Name
            };

        if (countryId.HasValue)
        {
            query = query.Where(item => item.City.CountryId == countryId.Value);
        }

        return await query
            .OrderBy(item => item.City.SortOrder)
            .ThenBy(item => item.City.Name)
            .Select(item => new CityResponse(
                item.City.Id,
                item.City.Name,
                item.City.CountryId,
                item.CountryName))
            .ToArrayAsync(cancellationToken);
    }

    public async Task<IReadOnlyCollection<ReferenceItemResponse>> GetTaskCategoriesAsync(
        CancellationToken cancellationToken) =>
        await dbContext.TaskCategories
            .AsNoTracking()
            .Where(category => category.IsActive)
            .OrderBy(category => category.SortOrder)
            .ThenBy(category => category.Name)
            .Select(category => new ReferenceItemResponse(
                category.Id,
                category.Code,
                category.Name))
            .ToArrayAsync(cancellationToken);

    public async Task<IReadOnlyCollection<ReferenceItemResponse>> GetRecurrenceTypesAsync(
        CancellationToken cancellationToken) =>
        await dbContext.RecurrenceTypes
            .AsNoTracking()
            .Where(type =>
                type.IsActive &&
                (type.Code == RecurrenceCodes.None ||
                 type.Code == RecurrenceCodes.Daily ||
                 type.Code == RecurrenceCodes.Weekly ||
                 type.Code == RecurrenceCodes.Monthly))
            .OrderBy(type => type.SortOrder)
            .ThenBy(type => type.Name)
            .Select(type => new ReferenceItemResponse(
                type.Id,
                type.Code,
                type.Name))
            .ToArrayAsync(cancellationToken);
}
