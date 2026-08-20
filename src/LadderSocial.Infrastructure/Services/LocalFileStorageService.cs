using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Options;
using Microsoft.Extensions.Options;

namespace LadderSocial.Infrastructure.Services;

public sealed class LocalFileStorageService(IOptions<FileStorageOptions> options) : IFileStorageService
{
    private static readonly IReadOnlyDictionary<string, string> ExtensionsByMimeType =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["image/jpeg"] = ".jpg",
            ["image/png"] = ".png",
            ["image/webp"] = ".webp"
        };

    private readonly FileStorageOptions _options = options.Value;

    public async Task<StoredFileInfo> SaveImageAsync(
        string folder,
        UploadPayload upload,
        CancellationToken cancellationToken)
    {
        ValidateImage(upload);

        var normalizedFolder = NormalizeRelativePath(folder);
        var extension = ExtensionsByMimeType[upload.ContentType.Trim()];
        var fileName = $"{Guid.NewGuid():N}{extension}";
        var storageKey = Path.Combine(normalizedFolder, fileName).Replace('\\', '/');
        var absolutePath = ResolveAbsolutePath(storageKey);
        var directory = Path.GetDirectoryName(absolutePath)
            ?? throw new InvalidOperationException("The upload destination directory could not be determined.");

        Directory.CreateDirectory(directory);
        await File.WriteAllBytesAsync(absolutePath, upload.Content, cancellationToken);

        return new StoredFileInfo(
            storageKey,
            upload.ContentType.Trim().ToLowerInvariant(),
            upload.Length,
            Path.GetFileName(upload.FileName));
    }

    public async Task<FileContentResult> ReadAsync(
        string storageKey,
        string downloadName,
        string contentType,
        CancellationToken cancellationToken)
    {
        var absolutePath = ResolveAbsolutePath(storageKey);
        if (!File.Exists(absolutePath))
        {
            throw new NotFoundException("The requested media file was not found.");
        }

        var bytes = await File.ReadAllBytesAsync(absolutePath, cancellationToken);
        return new FileContentResult(bytes, contentType, downloadName);
    }

    public Task DeleteIfExistsAsync(
        string storageKey,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var absolutePath = ResolveAbsolutePath(storageKey);
        if (File.Exists(absolutePath))
        {
            File.Delete(absolutePath);
        }

        return Task.CompletedTask;
    }

    private void ValidateImage(UploadPayload upload)
    {
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
        var contentType = upload.ContentType.Trim();

        if (upload.Content.Length == 0)
        {
            errors["file"] = ["Select a non-empty image file."];
        }
        else if (upload.Content.Length > _options.MaximumImageBytes)
        {
            errors["file"] = [$"The image may contain at most {_options.MaximumImageBytes / (1024 * 1024)} MB."];
        }

        if (!ExtensionsByMimeType.ContainsKey(contentType))
        {
            errors["file"] = ["Only JPEG, PNG, and WebP images are supported."];
        }
        else if (!MatchesMagicBytes(upload.Content, contentType))
        {
            errors["file"] = ["The file content does not match the declared image type."];
        }

        if (errors.Count > 0)
        {
            throw new ValidationException("Image validation failed.", errors);
        }
    }

    private string ResolveAbsolutePath(string storageKey)
    {
        if (string.IsNullOrWhiteSpace(_options.RootPath))
        {
            throw new InvalidOperationException("UPLOAD_ROOT is not configured.");
        }

        var root = Path.GetFullPath(_options.RootPath);
        var normalized = NormalizeRelativePath(storageKey);
        var candidate = Path.GetFullPath(Path.Combine(root, normalized));
        var prefix = root.EndsWith(Path.DirectorySeparatorChar)
            ? root
            : root + Path.DirectorySeparatorChar;

        if (!candidate.StartsWith(prefix, StringComparison.Ordinal) &&
            !string.Equals(candidate, root, StringComparison.Ordinal))
        {
            throw new ValidationException("The requested storage path is invalid.");
        }

        return candidate;
    }

    private static string NormalizeRelativePath(string value)
    {
        var normalized = value.Trim().Replace('\\', '/').Trim('/');
        if (string.IsNullOrWhiteSpace(normalized) ||
            normalized.Split('/').Any(part => part is ".." or "." || string.IsNullOrWhiteSpace(part)))
        {
            throw new ValidationException("The requested storage path is invalid.");
        }

        return normalized.Replace('/', Path.DirectorySeparatorChar);
    }

    private static bool MatchesMagicBytes(byte[] content, string contentType) =>
        contentType.ToLowerInvariant() switch
        {
            "image/jpeg" => content.Length >= 3 &&
                content[0] == 0xFF && content[1] == 0xD8 && content[2] == 0xFF,
            "image/png" => content.Length >= 8 &&
                content[0] == 0x89 && content[1] == 0x50 && content[2] == 0x4E && content[3] == 0x47 &&
                content[4] == 0x0D && content[5] == 0x0A && content[6] == 0x1A && content[7] == 0x0A,
            "image/webp" => content.Length >= 12 &&
                content[0] == 0x52 && content[1] == 0x49 && content[2] == 0x46 && content[3] == 0x46 &&
                content[8] == 0x57 && content[9] == 0x45 && content[10] == 0x42 && content[11] == 0x50,
            _ => false
        };
}
