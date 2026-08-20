using System.Security.Cryptography;
using LadderSocial.Application.Common.Options;
using LadderSocial.Infrastructure.Identity;
using Microsoft.Extensions.Options;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class PasswordResetCodeServiceTests
{
    [Fact]
    public void CreateCode_ReturnsSixDigitsAndVerifiableHash()
    {
        var service = CreateService();

        var generated = service.CreateCode();

        Assert.Equal(6, generated.PlainTextCode.Length);
        Assert.All(generated.PlainTextCode, character => Assert.InRange(character, '0', '9'));
        Assert.Equal(64, generated.CodeHash.Length);
        Assert.NotEqual(generated.PlainTextCode, generated.CodeHash);
        Assert.True(service.VerifyCode(generated.PlainTextCode, generated.CodeHash));

        var incorrectCode = generated.PlainTextCode == "000000" ? "000001" : "000000";
        Assert.False(service.VerifyCode(incorrectCode, generated.CodeHash));
    }

    [Fact]
    public void ProtectedCode_RoundTripsWithoutExposingPlainText()
    {
        var service = CreateService();
        const string code = "482913";

        var protectedCode = service.ProtectForTransport(code);
        var unprotectedCode = service.UnprotectFromTransport(protectedCode);

        Assert.NotEqual(code, protectedCode);
        Assert.DoesNotContain(code, protectedCode);
        Assert.Equal(code, unprotectedCode);
    }

    [Fact]
    public void ProtectedCode_RejectsTampering()
    {
        var service = CreateService();
        var payload = Convert.FromBase64String(service.ProtectForTransport("123456"));
        payload[^1] ^= 0x01;

        Assert.ThrowsAny<CryptographicException>(() =>
            service.UnprotectFromTransport(Convert.ToBase64String(payload)));
    }

    private static PasswordResetCodeService CreateService() => new(
        Options.Create(new PasswordResetOptions
        {
            HashKey = new string('h', 64),
            EventEncryptionKey = new string('e', 64),
            CodeLifetimeMinutes = 15,
            MaxAttempts = 5,
            MinimumRequestIntervalSeconds = 60
        }));
}
