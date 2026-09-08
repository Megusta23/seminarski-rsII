namespace LadderSocial.Domain.Constants;

public static class ProofLayoutCodes
{
    public const string Single = "single";
    public const string TwoVertical = "two-vertical";
    public const string TwoHorizontal = "two-horizontal";
    public const string ThreeGrid = "three-grid";
    public const string FourGrid = "four-grid";

    private static readonly HashSet<string> SupportedCodes = new(
        [Single, TwoVertical, TwoHorizontal, ThreeGrid, FourGrid],
        StringComparer.OrdinalIgnoreCase);

    public static bool IsSupported(string? code) =>
        !string.IsNullOrWhiteSpace(code) && SupportedCodes.Contains(code.Trim());

    public static string Normalize(string? code)
    {
        var normalized = code?.Trim().ToLowerInvariant();
        if (normalized is null || !SupportedCodes.Contains(normalized))
        {
            throw new ArgumentOutOfRangeException(
                nameof(code),
                code,
                "Select a supported proof layout.");
        }

        return normalized;
    }

    public static int RequiredPhotoCount(string code) =>
        Normalize(code) switch
        {
            Single => 1,
            TwoVertical or TwoHorizontal => 2,
            ThreeGrid => 3,
            FourGrid => 4,
            _ => throw new InvalidOperationException("The normalized proof layout is invalid.")
        };
}
