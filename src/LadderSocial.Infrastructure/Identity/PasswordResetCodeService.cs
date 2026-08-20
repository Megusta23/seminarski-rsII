using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Features.Auth;
using Microsoft.Extensions.Options;

namespace LadderSocial.Infrastructure.Identity;

public sealed class PasswordResetCodeService : IPasswordResetCodeService
{
    private const int NonceSize = 12;
    private const int TagSize = 16;
    private static readonly byte[] AssociatedData =
        Encoding.UTF8.GetBytes("LadderSocial.PasswordReset.v1");

    private readonly byte[] _hashKey;
    private readonly byte[] _encryptionKey;

    public PasswordResetCodeService(IOptions<PasswordResetOptions> options)
    {
        ArgumentNullException.ThrowIfNull(options);
        _hashKey = SHA256.HashData(Encoding.UTF8.GetBytes(options.Value.HashKey));
        _encryptionKey = SHA256.HashData(
            Encoding.UTF8.GetBytes(options.Value.EventEncryptionKey));
    }

    public GeneratedPasswordResetCode CreateCode()
    {
        var code = RandomNumberGenerator
            .GetInt32(0, 1_000_000)
            .ToString("D6", CultureInfo.InvariantCulture);

        return new GeneratedPasswordResetCode(code, HashCode(code));
    }

    public string HashCode(string code)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(code);

        using var hmac = new HMACSHA256(_hashKey);
        return Convert.ToHexString(hmac.ComputeHash(Encoding.UTF8.GetBytes(code.Trim())));
    }

    public bool VerifyCode(string code, string expectedHash)
    {
        if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(expectedHash))
        {
            return false;
        }

        try
        {
            var actual = Convert.FromHexString(HashCode(code));
            var expected = Convert.FromHexString(expectedHash);
            return actual.Length == expected.Length &&
                   CryptographicOperations.FixedTimeEquals(actual, expected);
        }
        catch (FormatException)
        {
            return false;
        }
    }

    public string ProtectForTransport(string code)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(code);

        var plaintext = Encoding.UTF8.GetBytes(code.Trim());
        var nonce = RandomNumberGenerator.GetBytes(NonceSize);
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[TagSize];

        using (var aes = new AesGcm(_encryptionKey, TagSize))
        {
            aes.Encrypt(nonce, plaintext, ciphertext, tag, AssociatedData);
        }

        var payload = new byte[1 + NonceSize + TagSize + ciphertext.Length];
        payload[0] = 1;
        nonce.CopyTo(payload.AsSpan(1, NonceSize));
        tag.CopyTo(payload.AsSpan(1 + NonceSize, TagSize));
        ciphertext.CopyTo(payload.AsSpan(1 + NonceSize + TagSize));
        return Convert.ToBase64String(payload);
    }

    public string UnprotectFromTransport(string protectedCode)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(protectedCode);

        byte[] payload;
        try
        {
            payload = Convert.FromBase64String(protectedCode);
        }
        catch (FormatException exception)
        {
            throw new CryptographicException("The protected reset code has an invalid format.", exception);
        }

        if (payload.Length <= 1 + NonceSize + TagSize || payload[0] != 1)
        {
            throw new CryptographicException("The protected reset code has an unsupported format.");
        }

        var nonce = payload.AsSpan(1, NonceSize);
        var tag = payload.AsSpan(1 + NonceSize, TagSize);
        var ciphertext = payload.AsSpan(1 + NonceSize + TagSize);
        var plaintext = new byte[ciphertext.Length];

        using (var aes = new AesGcm(_encryptionKey, TagSize))
        {
            aes.Decrypt(nonce, ciphertext, tag, plaintext, AssociatedData);
        }

        return Encoding.UTF8.GetString(plaintext);
    }
}
