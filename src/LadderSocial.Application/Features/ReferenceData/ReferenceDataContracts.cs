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
