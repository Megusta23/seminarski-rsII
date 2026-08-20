using System.ComponentModel.DataAnnotations;
using LadderSocial.Application.Common.Models;

namespace LadderSocial.Application.Features.ReferenceData;

public sealed record ReferenceItemResponse(
    Guid Id,
    string Code,
    string Name);

public sealed record CountryResponse(
    Guid Id,
    string IsoCode,
    string Name);

public sealed record CityResponse(
    Guid Id,
    string Name,
    Guid CountryId,
    string CountryName);

public sealed class ReferenceDataListRequest : PagedRequest
{
    public bool? IsActive { get; set; }
    public Guid? CountryId { get; set; }
}

public sealed record AdminCountryResponse(
    Guid Id,
    string IsoCode,
    string Name,
    bool IsActive,
    int SortOrder);

public sealed record AdminCityResponse(
    Guid Id,
    string Name,
    Guid CountryId,
    string CountryName,
    bool IsActive,
    int SortOrder);

public sealed record AdminReferenceItemResponse(
    Guid Id,
    string Code,
    string Name,
    bool IsActive,
    int SortOrder);

public sealed record CreateCountryRequest(
    [Required, StringLength(100)] string Name,
    [Required, StringLength(3, MinimumLength = 2)] string IsoCode,
    int SortOrder = 0);

public sealed record UpdateCountryRequest(
    [Required, StringLength(100)] string Name,
    [Required, StringLength(3, MinimumLength = 2)] string IsoCode,
    bool IsActive,
    int SortOrder = 0);

public sealed record CreateCityRequest(
    [Required, StringLength(150)] string Name,
    Guid CountryId,
    int SortOrder = 0);

public sealed record UpdateCityRequest(
    [Required, StringLength(150)] string Name,
    Guid CountryId,
    bool IsActive,
    int SortOrder = 0);

public sealed record CreateReferenceItemRequest(
    [Required, StringLength(100)] string Name,
    [Required, StringLength(50)] string Code,
    int SortOrder = 0);

public sealed record UpdateReferenceItemRequest(
    [Required, StringLength(100)] string Name,
    [Required, StringLength(50)] string Code,
    bool IsActive,
    int SortOrder = 0);

public interface IReferenceDataService
{
    Task<IReadOnlyCollection<CountryResponse>> GetCountriesAsync(
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<CityResponse>> GetCitiesAsync(
        Guid? countryId,
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<ReferenceItemResponse>> GetTaskCategoriesAsync(
        CancellationToken cancellationToken);

    Task<IReadOnlyCollection<ReferenceItemResponse>> GetRecurrenceTypesAsync(
        CancellationToken cancellationToken);
}

public interface IAdminReferenceDataService
{
    Task<PagedResult<AdminCountryResponse>> GetCountriesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken);

    Task<AdminCountryResponse> GetCountryAsync(Guid id, CancellationToken cancellationToken);
    Task<AdminCountryResponse> CreateCountryAsync(CreateCountryRequest request, CancellationToken cancellationToken);
    Task<AdminCountryResponse> UpdateCountryAsync(Guid id, UpdateCountryRequest request, CancellationToken cancellationToken);
    Task DeactivateCountryAsync(Guid id, CancellationToken cancellationToken);

    Task<PagedResult<AdminCityResponse>> GetCitiesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken);

    Task<AdminCityResponse> GetCityAsync(Guid id, CancellationToken cancellationToken);
    Task<AdminCityResponse> CreateCityAsync(CreateCityRequest request, CancellationToken cancellationToken);
    Task<AdminCityResponse> UpdateCityAsync(Guid id, UpdateCityRequest request, CancellationToken cancellationToken);
    Task DeactivateCityAsync(Guid id, CancellationToken cancellationToken);

    Task<PagedResult<AdminReferenceItemResponse>> GetTaskCategoriesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken);

    Task<AdminReferenceItemResponse> GetTaskCategoryAsync(Guid id, CancellationToken cancellationToken);
    Task<AdminReferenceItemResponse> CreateTaskCategoryAsync(CreateReferenceItemRequest request, CancellationToken cancellationToken);
    Task<AdminReferenceItemResponse> UpdateTaskCategoryAsync(Guid id, UpdateReferenceItemRequest request, CancellationToken cancellationToken);
    Task DeactivateTaskCategoryAsync(Guid id, CancellationToken cancellationToken);

    Task<PagedResult<AdminReferenceItemResponse>> GetRecurrenceTypesAsync(
        ReferenceDataListRequest request,
        CancellationToken cancellationToken);

    Task<AdminReferenceItemResponse> GetRecurrenceTypeAsync(Guid id, CancellationToken cancellationToken);
    Task<AdminReferenceItemResponse> CreateRecurrenceTypeAsync(CreateReferenceItemRequest request, CancellationToken cancellationToken);
    Task<AdminReferenceItemResponse> UpdateRecurrenceTypeAsync(Guid id, UpdateReferenceItemRequest request, CancellationToken cancellationToken);
    Task DeactivateRecurrenceTypeAsync(Guid id, CancellationToken cancellationToken);
}
