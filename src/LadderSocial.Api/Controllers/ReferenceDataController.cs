using LadderSocial.Application.Common.Models;
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
        [FromQuery] ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        ToCompatibilityResponse(
            await referenceDataService.GetCountriesAsync(request, cancellationToken));

    [HttpGet("cities")]
    [ProducesResponseType<IReadOnlyCollection<CityResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<CityResponse>>> GetCities(
        [FromQuery] ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        ToCompatibilityResponse(
            await referenceDataService.GetCitiesAsync(request, cancellationToken));

    [HttpGet("task-categories")]
    [ProducesResponseType<IReadOnlyCollection<ReferenceItemResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<ReferenceItemResponse>>> GetTaskCategories(
        [FromQuery] ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        ToCompatibilityResponse(
            await referenceDataService.GetTaskCategoriesAsync(request, cancellationToken));

    [HttpGet("recurrence-types")]
    [ProducesResponseType<IReadOnlyCollection<ReferenceItemResponse>>(StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyCollection<ReferenceItemResponse>>> GetRecurrenceTypes(
        [FromQuery] ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        ToCompatibilityResponse(
            await referenceDataService.GetRecurrenceTypesAsync(request, cancellationToken));

    private ActionResult<IReadOnlyCollection<T>> ToCompatibilityResponse<T>(
        PagedResult<T> result)
    {
        Response.Headers["X-Total-Count"] = result.TotalCount.ToString();
        Response.Headers["X-Page"] = result.Page.ToString();
        Response.Headers["X-Page-Size"] = result.PageSize.ToString();
        Response.Headers["X-Total-Pages"] = result.TotalPages.ToString();
        return Ok(result.Items);
    }
}
