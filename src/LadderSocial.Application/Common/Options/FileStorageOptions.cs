namespace LadderSocial.Application.Common.Options;

public sealed class FileStorageOptions
{
    public string RootPath { get; set; } = string.Empty;
    public int MaximumImageBytes { get; set; } = 5 * 1024 * 1024;
}
