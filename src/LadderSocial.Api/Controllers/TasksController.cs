using LadderSocial.Api.Models;
using LadderSocial.Api.Services;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Models;
using LadderSocial.Application.Features.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LadderSocial.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/tasks")]
public sealed class TasksController(ITaskService taskService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<PagedResult<TaskListItemResponse>>> Get(
        [FromQuery] TaskListRequest request,
        CancellationToken cancellationToken) =>
        Ok(await taskService.GetMyTasksAsync(request, cancellationToken));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<TaskDetailResponse>> GetById(
        Guid id,
        CancellationToken cancellationToken) =>
        Ok(await taskService.GetMyTaskAsync(id, cancellationToken));

    [HttpPost]
    public async Task<ActionResult<TaskDetailResponse>> Create(
        [FromBody] CreateTaskRequest request,
        CancellationToken cancellationToken)
    {
        var created = await taskService.CreateAsync(request, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<TaskDetailResponse>> Update(
        Guid id,
        [FromBody] UpdateTaskRequest request,
        CancellationToken cancellationToken) =>
        Ok(await taskService.UpdateAsync(id, request, cancellationToken));

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await taskService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/complete")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<TaskCompletionResponse>> Complete(
        Guid id,
        [FromForm] TaskCompleteForm form,
        CancellationToken cancellationToken)
    {
        if (!form.OccurrenceDate.HasValue)
        {
            throw new ValidationException(
                "Task completion validation failed.",
                new Dictionary<string, string[]>
                {
                    ["occurrenceDate"] = ["Select the task occurrence date."]
                });
        }

        var upload = form.ProofImage is null
            ? null
            : await FormFileReader.ReadAsync(form.ProofImage, cancellationToken);
        var result = await taskService.CompleteAsync(
            id,
            new CompleteTaskCommand(
                form.OccurrenceDate.Value,
                form.Note,
                form.Caption,
                upload),
            cancellationToken);
        return CreatedAtAction(nameof(GetCompletions), new { id }, result);
    }

    [HttpGet("{id:guid}/completions")]
    public async Task<ActionResult<PagedResult<TaskCompletionResponse>>> GetCompletions(
        Guid id,
        [FromQuery] PagedRequest request,
        CancellationToken cancellationToken) =>
        Ok(await taskService.GetCompletionsAsync(id, request, cancellationToken));
}
