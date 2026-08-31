namespace LadderSocial.Domain.Constants;

public static class RecurrenceCodes
{
    public const string None = "none";
    public const string Daily = "daily";
    public const string Weekly = "weekly";
    public const string Monthly = "monthly";

    private static readonly HashSet<string> SupportedValues = new(
        [None, Daily, Weekly, Monthly],
        StringComparer.OrdinalIgnoreCase);

    public static IReadOnlyCollection<string> Supported =>
        [None, Daily, Weekly, Monthly];

    public static bool IsSupported(string? code) =>
        !string.IsNullOrWhiteSpace(code) && SupportedValues.Contains(code.Trim());

    public static string Normalize(string code) => code.Trim().ToLowerInvariant();
}
