using System.Text;
using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Application.Common.Options;
using LadderSocial.Application.Features.Chat;
using LadderSocial.Domain.Constants;
using LadderSocial.Domain.Enums;
using LadderSocial.Infrastructure.Services;
using Microsoft.Extensions.Options;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class E2EChatBackendContractTests
{
    private static readonly byte[] Nonce = Enumerable
        .Range(1, ChatCryptoConstants.AeadNonceBytes)
        .Select(value => (byte)value)
        .ToArray();

    [Fact]
    public void DeviceRegistration_OnlyAcceptsAnX25519PublicKey()
    {
        var valid = new RegisterDeviceKeyRequest(
            "ios-simulator-review-device",
            Enumerable.Repeat((byte)0x2A, ChatCryptoConstants.X25519PublicKeyBytes).ToArray());

        E2EChatRules.ValidateDeviceRegistration(valid);

        var invalidLength = valid with
        {
            PublicKey = new byte[ChatCryptoConstants.X25519PublicKeyBytes - 1]
        };
        var allZero = valid with
        {
            PublicKey = new byte[ChatCryptoConstants.X25519PublicKeyBytes]
        };
        Assert.Throws<ValidationException>(() =>
            E2EChatRules.ValidateDeviceRegistration(invalidLength));
        Assert.Throws<ValidationException>(() =>
            E2EChatRules.ValidateDeviceRegistration(allZero));
    }

    [Fact]
    public void ServerTransportContracts_NeverContainPrivateKeyOrPlaintextProperties()
    {
        var contractTypes = new[]
        {
            typeof(RegisterDeviceKeyRequest),
            typeof(UserDeviceKeyResponse),
            typeof(CreateConversationKeyEnvelopeRequest),
            typeof(ConversationKeyEnvelopeResponse),
            typeof(SendEncryptedMessageCommand)
        };

        var propertyNames = contractTypes
            .SelectMany(type => type.GetProperties())
            .Select(property => property.Name)
            .ToArray();

        Assert.DoesNotContain(
            propertyNames,
            name => name.Contains("PrivateKey", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(
            propertyNames,
            name => name.Equals("Plaintext", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(
            typeof(SendEncryptedMessageCommand).GetProperties(),
            property => property.Name.Equals("Content", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void ConversationEnvelope_RequiresWrappedKeyNonceAndPositiveVersion()
    {
        var valid = new CreateConversationKeyEnvelopeRequest(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Enumerable.Repeat(
                (byte)0x73,
                ChatCryptoConstants.WrappedConversationKeyBytes).ToArray(),
            Nonce,
            1);

        E2EChatRules.ValidateEnvelope(valid);

        Assert.Throws<ValidationException>(() =>
            E2EChatRules.ValidateEnvelope(valid with { KeyVersion = 0 }));
        Assert.Throws<ValidationException>(() =>
            E2EChatRules.ValidateEnvelope(valid with { Nonce = new byte[11] }));
    }

    [Fact]
    public void EncryptedTextFactory_LeavesThePlaintextColumnNull()
    {
        const string knownPlaintextMarker = "KNOWN-PLAINTEXT-MARKER-220087";
        var ciphertext = Encoding.UTF8.GetBytes("ciphertext-and-authentication-tag");
        var command = new SendEncryptedMessageCommand(
            MessageType.Text,
            Guid.NewGuid(),
            1,
            ciphertext,
            Nonce,
            null,
            null,
            null);

        var message = E2EChatRules.CreateEncryptedMessage(
            Guid.NewGuid(),
            Guid.NewGuid(),
            command,
            DateTime.UtcNow);

        Assert.Null(message.Content);
        Assert.Equal(ciphertext, message.EncryptedContent);
        Assert.Equal(ChatEncryptionVersions.ClientE2E, message.EncryptionVersion);
        Assert.Equal(1, message.KeyVersion.GetValueOrDefault());
        Assert.DoesNotContain(
            knownPlaintextMarker,
            Convert.ToBase64String(message.EncryptedContent!));
    }

    [Fact]
    public void EncryptedMediaFactory_StoresOnlyCiphertextMetadata()
    {
        var upload = new UploadPayload(
            Enumerable.Range(0, 32).Select(value => (byte)value).ToArray(),
            "encrypted-image.bin",
            ChatCryptoConstants.EncryptedMediaContentType);
        var command = new SendEncryptedMessageCommand(
            MessageType.Image,
            Guid.NewGuid(),
            2,
            null,
            null,
            upload,
            Nonce,
            null);

        E2EChatRules.ValidateEncryptedMessage(command);
        var attachment = E2EChatRules.CreateEncryptedAttachment(
            Guid.NewGuid(),
            Guid.NewGuid(),
            new StoredFileInfo(
                "message-ciphertext/2026/09/file.bin",
                ChatCryptoConstants.EncryptedMediaContentType,
                upload.Length,
                upload.FileName),
            command);

        Assert.Equal(ChatCryptoConstants.EncryptedMediaContentType, attachment.MimeType);
        Assert.Equal(ChatEncryptionVersions.ClientE2E, attachment.EncryptionVersion);
        Assert.Equal(2, attachment.KeyVersion.GetValueOrDefault());
        Assert.NotNull(attachment.ContentNonce);
        Assert.Equal(Nonce, attachment.ContentNonce);
        Assert.Null(attachment.DurationMilliseconds);
    }

    [Theory]
    [InlineData(MessageType.Text, "Hasan sent you a message.")]
    [InlineData(MessageType.Image, "Hasan sent you an image.")]
    [InlineData(MessageType.Voice, "Hasan sent you a voice message.")]
    [InlineData(MessageType.Video, "Hasan sent you a video.")]
    public void Notifications_AreGenericAndNeverContainMessagePlaintext(
        MessageType type,
        string expected)
    {
        const string marker = "KNOWN-PLAINTEXT-MARKER-220087";

        var body = E2EChatRules.GetNotificationBody("Hasan", type);

        Assert.Equal(expected, body);
        Assert.DoesNotContain(marker, body);
    }

    [Fact]
    public async Task EncryptedStorage_RoundTripsCiphertextBytesUnchanged()
    {
        var rootPath = Path.Combine(Path.GetTempPath(), $"ladder-e2e-{Guid.NewGuid():N}");
        try
        {
            var storage = new LocalFileStorageService(Options.Create(new FileStorageOptions
            {
                RootPath = rootPath,
                MaximumImageBytes = 5 * 1024 * 1024,
                MaximumEncryptedChatMediaBytes = ChatCryptoConstants.MaximumEncryptedMediaBytes
            }));
            var ciphertext = Enumerable.Range(0, 32).Select(value => (byte)value).ToArray();
            var stored = await storage.SaveEncryptedAsync(
                "message-ciphertext/2026/09",
                new UploadPayload(
                    ciphertext,
                    "voice-message.bin",
                    ChatCryptoConstants.EncryptedMediaContentType),
                CancellationToken.None);

            var downloaded = await storage.ReadAsync(
                stored.StorageKey,
                "download.bin",
                stored.ContentType,
                CancellationToken.None);

            Assert.Equal(ciphertext, downloaded.Content);
            Assert.Equal(ChatCryptoConstants.EncryptedMediaContentType, downloaded.ContentType);
            Assert.EndsWith(".bin", stored.StorageKey);
        }
        finally
        {
            if (Directory.Exists(rootPath))
            {
                Directory.Delete(rootPath, recursive: true);
            }
        }
    }

    [Fact]
    public void EncryptedEndpoint_RejectsSystemMessages()
    {
        var command = new SendEncryptedMessageCommand(
            MessageType.System,
            Guid.NewGuid(),
            1,
            Encoding.UTF8.GetBytes("ciphertext-plus-authentication-tag"),
            Nonce,
            null,
            null,
            null);

        var exception = Assert.Throws<ValidationException>(() =>
            E2EChatRules.ValidateEncryptedMessage(command));
        Assert.Contains(
            exception.Errors.Keys,
            key => string.Equals(key, "type", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void EncryptedVoice_RequiresDurationAndOctetStreamCiphertext()
    {
        var valid = new SendEncryptedMessageCommand(
            MessageType.Voice,
            Guid.NewGuid(),
            1,
            null,
            null,
            new UploadPayload(
                Enumerable.Range(0, 32).Select(value => (byte)value).ToArray(),
                "voice.bin",
                ChatCryptoConstants.EncryptedMediaContentType),
            Nonce,
            1250);

        E2EChatRules.ValidateEncryptedMessage(valid);

        var missingDuration = valid with { DurationMilliseconds = null };
        var invalidMime = valid with
        {
            Attachment = valid.Attachment! with { ContentType = "audio/m4a" }
        };
        Assert.Throws<ValidationException>(() =>
            E2EChatRules.ValidateEncryptedMessage(missingDuration));
        Assert.Throws<ValidationException>(() =>
            E2EChatRules.ValidateEncryptedMessage(invalidMime));
    }

    [Fact]
    public void E2EConversationPreview_IsGeneric()
    {
        const string marker = "KNOWN-PLAINTEXT-MARKER-220087";

        var preview = E2EChatRules.GetServerPreview(
            MessageType.Text,
            marker,
            ChatEncryptionVersions.ClientE2E);

        Assert.Equal("Encrypted message", preview);
        Assert.NotNull(preview);
        Assert.DoesNotContain(marker, preview);
    }
}
