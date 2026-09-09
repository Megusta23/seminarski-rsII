using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Domain.Constants;

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

    public static async Task<UploadPayload> ReadEncryptedAsync(
        IFormFile file,
        int maximumBytes,
        CancellationToken cancellationToken)
    {
        if (maximumBytes is < 1024 or > ChatCryptoConstants.MaximumEncryptedMediaBytes)
        {
            throw new InvalidOperationException(
                "The configured encrypted chat media limit must be between 1 KB and 25 MB.");
        }

        if (file.Length is <= 0 || file.Length > maximumBytes)
        {
            throw new ValidationException(
                "Encrypted media validation failed.",
                new Dictionary<string, string[]>
                {
                    ["attachment"] =
                    [
                        $"Select a non-empty encrypted media file no larger than " +
                        $"{maximumBytes / (1024 * 1024)} MB."
                    ]
                });
        }

        if (!string.Equals(
                file.ContentType,
                ChatCryptoConstants.EncryptedMediaContentType,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new ValidationException(
                "Encrypted media validation failed.",
                new Dictionary<string, string[]>
                {
                    ["attachment"] =
                    ["Encrypted media must be uploaded as application/octet-stream."]
                });
        }

        await using var stream = file.OpenReadStream();
        using var buffer = new MemoryStream((int)file.Length);
        await stream.CopyToAsync(buffer, cancellationToken);
        if (buffer.Length != file.Length)
        {
            throw new ValidationException(
                "Encrypted media validation failed.",
                new Dictionary<string, string[]>
                {
                    ["attachment"] = ["The encrypted media upload was incomplete."]
                });
        }

        return new UploadPayload(
            buffer.ToArray(),
            Path.GetFileName(file.FileName),
            ChatCryptoConstants.EncryptedMediaContentType);
    }

    public static async Task<IReadOnlyList<UploadPayload>> ReadManyAsync(
        IEnumerable<IFormFile> files,
        int maximumCount,
        long maximumTotalBytes,
        CancellationToken cancellationToken)
    {
        var materialized = files.ToArray();
        if (materialized.Length > maximumCount)
        {
            throw new ValidationException(
                "File validation failed.",
                new Dictionary<string, string[]>
                {
                    ["proofImages"] = [$"Select at most {maximumCount} proof images."]
                });
        }

        var totalBytes = materialized.Sum(file => file.Length);
        if (totalBytes > maximumTotalBytes)
        {
            throw new ValidationException(
                "File validation failed.",
                new Dictionary<string, string[]>
                {
                    ["proofImages"] =
                    [
                        $"The combined proof images may contain at most {maximumTotalBytes / (1024 * 1024)} MB."
                    ]
                });
        }

        var uploads = new List<UploadPayload>(materialized.Length);
        foreach (var file in materialized)
        {
            uploads.Add(await ReadAsync(file, cancellationToken));
        }

        return uploads;
    }
}
