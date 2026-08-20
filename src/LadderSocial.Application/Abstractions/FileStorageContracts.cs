namespace LadderSocial.Application.Abstractions;

public sealed record UploadPayload(
    byte[] Content,
    string FileName,
    string ContentType)
{
    public long Length => Content.LongLength;
}

public sealed record StoredFileInfo(
    string StorageKey,
    string ContentType,
    long Length,
    string OriginalFileName);

public sealed record FileContentResult(
    byte[] Content,
    string ContentType,
    string DownloadName);

public interface IFileStorageService
{
    Task<StoredFileInfo> SaveImageAsync(
        string folder,
        UploadPayload upload,
        CancellationToken cancellationToken);

    Task<FileContentResult> ReadAsync(
        string storageKey,
        string downloadName,
        string contentType,
        CancellationToken cancellationToken);

    Task DeleteIfExistsAsync(
        string storageKey,
        CancellationToken cancellationToken);
}
