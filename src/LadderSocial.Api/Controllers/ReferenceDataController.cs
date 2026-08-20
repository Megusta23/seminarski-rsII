using LadderSocial.Application.Features.ReferenceData;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/reference-data")]
public sealed class ReferenceDataController(IReferenceDataService referenceDataService) : ControllerBase
{
    [HttpGet("countries")]
    [ProducesResponseType<IReadOnlyCollection<CountryResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<CountryResponse>>> GetCountries(
        CancellationToken cancellationToken) =>
        Ok(await referenceDataService.GetCountriesAsync(cancellationToken));

    [HttpGet("cities")]
    [ProducesResponseType<IReadOnlyCollection<CityResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<CityResponse>>> GetCities(
        [FromQuery] Guid? countryId,
        CancellationToken cancellationToken) =>
        Ok(await referenceDataService.GetCitiesAsync(countryId, cancellationToken));

    [HttpGet("task-categories")]
    [ProducesResponseType<IReadOnlyCollection<ReferenceItemResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<ReferenceItemResponse>>> GetTaskCategories(
        CancellationToken cancellationToken) =>
        Ok(await referenceDataService.GetTaskCategoriesAsync(cancellationToken));

    [HttpGet("recurrence-types")]
    [ProducesResponseType<IReadOnlyCollection<ReferenceItemResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<ReferenceItemResponse>>> GetRecurrenceTypes(
        CancellationToken cancellationToken) =>
        Ok(await referenceDataService.GetRecurrenceTypesAsync(cancellationToken));
}
