using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;

namespace LadderSocial.Api.Services;

public static class FormFileReader
{
    private const long AbsoluteMaximumBytes = 10L * 1024 * 1024;

    public static async Task<UploadPayload> ReadAsync(
        IFormFile file,
        CancellationToken cancellationToken)
    {
        if (file.Length is <= 0 or > AbsoluteMaximumBytes)
        {
            throw new ValidationException(
                "File validation failed.",
                new Dictionary<string, string[]>
                {
                    ["file"] = ["Select a non-empty image no larger than 10 MB."]
                });
        }

        await using var stream = file.OpenReadStream();
        using var buffer = new MemoryStream((int)file.Length);
        await stream.CopyToAsync(buffer, cancellationToken);
        return new UploadPayload(
            buffer.ToArray(),
            Path.GetFileName(file.FileName),
            file.ContentType ?? string.Empty);
    }
}
