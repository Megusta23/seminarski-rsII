using LadderSocial.Domain.Constants;
using LadderSocial.Domain.Entities;
using LadderSocial.Domain.Enums;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class E2EChatFoundationTests
{
    [Fact]
    public void MessageType_PreservesExistingValuesAndAddsVoiceAndVideo()
    {
        Assert.Equal(1, (int)MessageType.Text);
        Assert.Equal(2, (int)MessageType.Image);
        Assert.Equal(3, (int)MessageType.System);
        Assert.Equal(4, (int)MessageType.Voice);
        Assert.Equal(5, (int)MessageType.Video);
    }

    [Fact]
    public void MessageAndAttachment_DefaultToLegacyEncryptionVersion()
    {
        var message = new Message();
        var attachment = new MessageAttachment();

        Assert.Equal(ChatEncryptionVersions.LegacyPlaintext, message.EncryptionVersion);
        Assert.Null(message.KeyVersion);
        Assert.Null(message.EncryptedContent);
        Assert.Null(message.ContentNonce);

        Assert.Equal(ChatEncryptionVersions.LegacyPlaintext, attachment.EncryptionVersion);
        Assert.Null(attachment.KeyVersion);
        Assert.Null(attachment.ContentNonce);
    }

    [Fact]
    public void ServerDeviceKeyEntityContainsOnlyPublicKeyMaterial()
    {
        var propertyNames = typeof(UserDeviceKey)
            .GetProperties()
            .Select(property => property.Name)
            .ToArray();

        Assert.Contains(nameof(UserDeviceKey.PublicKey), propertyNames);
        Assert.DoesNotContain(
            propertyNames,
            propertyName => propertyName.Contains("PrivateKey", StringComparison.OrdinalIgnoreCase));
    }
}
