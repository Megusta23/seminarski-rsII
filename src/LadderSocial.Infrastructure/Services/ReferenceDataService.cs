using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.ReferenceData;
using LadderSocial.Domain.Constants;
using LadderSocial.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace LadderSocial.Infrastructure.Services;

public sealed class ReferenceDataService(ApplicationDbContext dbContext) : IReferenceDataService
{
    public async Task<PagedResult<CountryResponse>> GetCountriesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken)
    {
        var query = dbContext.Countries
            .AsNoTracking()
            .Where(country => country.IsActive);

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(country =>
                EF.Functions.Like(country.Name, $"%{search}%") ||
                EF.Functions.Like(country.IsoCode, $"%{search}%"));
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(country => country.SortOrder)
            .ThenBy(country => country.Name)
            .ThenBy(country => country.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(country => new CountryResponse(
                country.Id,
                country.IsoCode,
                country.Name))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<CountryResponse>(
            items,
            request.Page,
            request.PageSize,
            totalCount);
    }

    public async Task<PagedResult<CityResponse>> GetCitiesAsync(
        ReferenceDataListRequest request,
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

        if (request.CountryId.HasValue)
        {
            query = query.Where(item => item.City.CountryId == request.CountryId.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(item =>
                EF.Functions.Like(item.City.Name, $"%{search}%") ||
                EF.Functions.Like(item.CountryName, $"%{search}%"));
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(item => item.City.SortOrder)
            .ThenBy(item => item.City.Name)
            .ThenBy(item => item.City.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(item => new CityResponse(
                item.City.Id,
                item.City.Name,
                item.City.CountryId,
                item.CountryName))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<CityResponse>(
            items,
            request.Page,
            request.PageSize,
            totalCount);
    }

    public async Task<PagedResult<ReferenceItemResponse>> GetTaskCategoriesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken)
    {
        var query = dbContext.TaskCategories
            .AsNoTracking()
            .Where(category => category.IsActive);

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(category =>
                EF.Functions.Like(category.Name, $"%{search}%") ||
                EF.Functions.Like(category.Code, $"%{search}%"));
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(category => category.SortOrder)
            .ThenBy(category => category.Name)
            .ThenBy(category => category.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(category => new ReferenceItemResponse(
                category.Id,
                category.Code,
                category.Name))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<ReferenceItemResponse>(
            items,
            request.Page,
            request.PageSize,
            totalCount);
    }

    public async Task<PagedResult<ReferenceItemResponse>> GetRecurrenceTypesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken)
    {
        var query = dbContext.RecurrenceTypes
            .AsNoTracking()
            .Where(type =>
                type.IsActive &&
                (type.Code == RecurrenceCodes.None ||
                 type.Code == RecurrenceCodes.Daily ||
                 type.Code == RecurrenceCodes.Weekly ||
                 type.Code == RecurrenceCodes.Monthly));

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var search = request.Search.Trim();
            query = query.Where(type =>
                EF.Functions.Like(type.Name, $"%{search}%") ||
                EF.Functions.Like(type.Code, $"%{search}%"));
        }

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .OrderBy(type => type.SortOrder)
            .ThenBy(type => type.Name)
            .ThenBy(type => type.Id)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(type => new ReferenceItemResponse(
                type.Id,
                type.Code,
                type.Name))
            .ToArrayAsync(cancellationToken);

        return new PagedResult<ReferenceItemResponse>(
            items,
            request.Page,
            request.PageSize,
            totalCount);
    }
}
