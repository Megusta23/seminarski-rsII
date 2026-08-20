using LadderSocial.Application.Abstractions;

namespace LadderSocial.Application.Features.Reports;

public interface IReportService
{
    Task<FileContentResult> GenerateActivityReportAsync(
        DateOnly fromDate,
        DateOnly toDate,
        CancellationToken cancellationToken);

    Task<FileContentResult> GenerateUserReportAsync(
        Guid userId,
        CancellationToken cancellationToken);
}
