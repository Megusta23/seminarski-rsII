using LadderSocial.Application.Common.Exceptions;

namespace LadderSocial.Api.Services;

public static class Base64PayloadReader
{
    public static byte[]? DecodeOptional(
        string? encoded,
        string fieldName,
        int maximumBytes)
    {
        if (string.IsNullOrWhiteSpace(encoded))
        {
            return null;
        }

        if (maximumBytes < 1)
        {
            throw new ArgumentOutOfRangeException(
                nameof(maximumBytes),
                maximumBytes,
                "The maximum decoded payload length must be positive.");
        }

        var normalized = encoded.Trim();
        var maximumEncodedCharacters = checked(((maximumBytes + 2) / 3) * 4);
        if (normalized.Any(char.IsWhiteSpace) ||
            normalized.Length > maximumEncodedCharacters)
        {
            throw InvalidBase64(fieldName, maximumBytes);
        }

        byte[] decoded;
        try
        {
            decoded = Convert.FromBase64String(normalized);
        }
        catch (FormatException)
        {
            throw InvalidBase64(fieldName, maximumBytes);
        }

        if (decoded.Length > maximumBytes)
        {
            throw InvalidBase64(fieldName, maximumBytes);
        }

        return decoded;
    }

    private static ValidationException InvalidBase64(
        string fieldName,
        int maximumBytes) =>
        new(
            "Encrypted payload validation failed.",
            new Dictionary<string, string[]>
            {
                [fieldName] =
                [
                    "Enter a valid Base64 value containing at most " +
                    $"{maximumBytes} decoded bytes."
                ]
            });
}
