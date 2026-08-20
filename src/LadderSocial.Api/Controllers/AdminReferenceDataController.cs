using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Common.Security;
using LadderSocial.Application.Features.ReferenceData;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize(Roles = RoleNames.Admin)]
[Route("api/admin/reference-data")]
public sealed class AdminReferenceDataController(IAdminReferenceDataService service) : ControllerBase
{
    [HttpGet("countries")]
    public async Task<ActionResult<PagedResult<AdminCountryResponse>>> GetCountries(
        [FromQuery] ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.GetCountriesAsync(request, cancellationToken));

    [HttpGet("countries/{id:guid}")]
    public async Task<ActionResult<AdminCountryResponse>> GetCountry(
        Guid id,
        CancellationToken cancellationToken) =>
        Ok(await service.GetCountryAsync(id, cancellationToken));

    [HttpPost("countries")]
    public async Task<ActionResult<AdminCountryResponse>> CreateCountry(
        [FromBody] CreateCountryRequest request,
        CancellationToken cancellationToken)
    {
        var created = await service.CreateCountryAsync(request, cancellationToken);
        return CreatedAtAction(nameof(GetCountry), new { id = created.Id }, created);
    }

    [HttpPut("countries/{id:guid}")]
    public async Task<ActionResult<AdminCountryResponse>> UpdateCountry(
        Guid id,
        [FromBody] UpdateCountryRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateCountryAsync(id, request, cancellationToken));

    [HttpDelete("countries/{id:guid}")]
    public async Task<IActionResult> DeactivateCountry(Guid id, CancellationToken cancellationToken)
    {
        await service.DeactivateCountryAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpGet("cities")]
    public async Task<ActionResult<PagedResult<AdminCityResponse>>> GetCities(
        [FromQuery] ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.GetCitiesAsync(request, cancellationToken));

    [HttpGet("cities/{id:guid}")]
    public async Task<ActionResult<AdminCityResponse>> GetCity(
        Guid id,
        CancellationToken cancellationToken) =>
        Ok(await service.GetCityAsync(id, cancellationToken));

    [HttpPost("cities")]
    public async Task<ActionResult<AdminCityResponse>> CreateCity(
        [FromBody] CreateCityRequest request,
        CancellationToken cancellationToken)
    {
        var created = await service.CreateCityAsync(request, cancellationToken);
        return CreatedAtAction(nameof(GetCity), new { id = created.Id }, created);
    }

    [HttpPut("cities/{id:guid}")]
    public async Task<ActionResult<AdminCityResponse>> UpdateCity(
        Guid id,
        [FromBody] UpdateCityRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateCityAsync(id, request, cancellationToken));

    [HttpDelete("cities/{id:guid}")]
    public async Task<IActionResult> DeactivateCity(Guid id, CancellationToken cancellationToken)
    {
        await service.DeactivateCityAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpGet("task-categories")]
    public async Task<ActionResult<PagedResult<AdminReferenceItemResponse>>> GetTaskCategories(
        [FromQuery] ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.GetTaskCategoriesAsync(request, cancellationToken));

    [HttpGet("task-categories/{id:guid}")]
    public async Task<ActionResult<AdminReferenceItemResponse>> GetTaskCategory(
        Guid id,
        CancellationToken cancellationToken) =>
        Ok(await service.GetTaskCategoryAsync(id, cancellationToken));

    [HttpPost("task-categories")]
    public async Task<ActionResult<AdminReferenceItemResponse>> CreateTaskCategory(
        [FromBody] CreateReferenceItemRequest request,
        CancellationToken cancellationToken)
    {
        var created = await service.CreateTaskCategoryAsync(request, cancellationToken);
        return CreatedAtAction(nameof(GetTaskCategory), new { id = created.Id }, created);
    }

    [HttpPut("task-categories/{id:guid}")]
    public async Task<ActionResult<AdminReferenceItemResponse>> UpdateTaskCategory(
        Guid id,
        [FromBody] UpdateReferenceItemRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateTaskCategoryAsync(id, request, cancellationToken));

    [HttpDelete("task-categories/{id:guid}")]
    public async Task<IActionResult> DeactivateTaskCategory(Guid id, CancellationToken cancellationToken)
    {
        await service.DeactivateTaskCategoryAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpGet("recurrence-types")]
    public async Task<ActionResult<PagedResult<AdminReferenceItemResponse>>> GetRecurrenceTypes(
        [FromQuery] ReferenceDataListRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.GetRecurrenceTypesAsync(request, cancellationToken));

    [HttpGet("recurrence-types/{id:guid}")]
    public async Task<ActionResult<AdminReferenceItemResponse>> GetRecurrenceType(
        Guid id,
        CancellationToken cancellationToken) =>
        Ok(await service.GetRecurrenceTypeAsync(id, cancellationToken));

    [HttpPost("recurrence-types")]
    public async Task<ActionResult<AdminReferenceItemResponse>> CreateRecurrenceType(
        [FromBody] CreateReferenceItemRequest request,
        CancellationToken cancellationToken)
    {
        var created = await service.CreateRecurrenceTypeAsync(request, cancellationToken);
        return CreatedAtAction(nameof(GetRecurrenceType), new { id = created.Id }, created);
    }

    [HttpPut("recurrence-types/{id:guid}")]
    public async Task<ActionResult<AdminReferenceItemResponse>> UpdateRecurrenceType(
        Guid id,
        [FromBody] UpdateReferenceItemRequest request,
        CancellationToken cancellationToken) =>
        Ok(await service.UpdateRecurrenceTypeAsync(id, request, cancellationToken));

    [HttpDelete("recurrence-types/{id:guid}")]
    public async Task<IActionResult> DeactivateRecurrenceType(Guid id, CancellationToken cancellationToken)
    {
        await service.DeactivateRecurrenceTypeAsync(id, cancellationToken);
        return NoContent();
    }
}
