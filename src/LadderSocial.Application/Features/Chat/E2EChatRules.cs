using LadderSocial.Application.Abstractions;
using LadderSocial.Application.Common.Exceptions;
using LadderSocial.Domain.Constants;
using LadderSocial.Domain.Entities;
using LadderSocial.Domain.Enums;

namespace LadderSocial.Application.Features.Chat;

public static class E2EChatRules
{
    public static void ValidateDeviceRegistration(RegisterDeviceKeyRequest request)
    {
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
        var deviceId = request.DeviceId?.Trim() ?? string.Empty;

        if (deviceId.Length is < 1 or > 128)
        {
            errors["deviceId"] = ["DeviceId must contain between 1 and 128 characters."];
        }
        else if (deviceId.Any(char.IsControl))
        {
            errors["deviceId"] = ["DeviceId may not contain control characters."];
        }

        if (request.PublicKey is null ||
            request.PublicKey.Length != ChatCryptoConstants.X25519PublicKeyBytes)
        {
            errors["publicKey"] =
            [
                $"PublicKey must be a {ChatCryptoConstants.X25519PublicKeyBytes}-byte X25519 public key."
            ];
        }
        else if (request.PublicKey.All(value => value == 0))
        {
            errors["publicKey"] = ["PublicKey may not be the all-zero X25519 value."];
        }

        ThrowIfInvalid("Device key validation failed.", errors);
    }

    public static void ValidateEnvelope(CreateConversationKeyEnvelopeRequest request)
    {
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);

        if (request.SenderDeviceKeyId == Guid.Empty)
        {
            errors["senderDeviceKeyId"] = ["Select the sending device key."];
        }

        if (request.RecipientDeviceKeyId == Guid.Empty)
        {
            errors["recipientDeviceKeyId"] = ["Select the recipient device key."];
        }

        if (request.KeyVersion < 1)
        {
            errors["keyVersion"] = ["KeyVersion must be greater than zero."];
        }

        if (request.EncryptedConversationKey is null ||
            request.EncryptedConversationKey.Length != ChatCryptoConstants.WrappedConversationKeyBytes)
        {
            errors["encryptedConversationKey"] =
            [
                "EncryptedConversationKey must contain the 32-byte conversation key " +
                $"and {ChatCryptoConstants.AeadTagBytes}-byte authentication tag."
            ];
        }

        if (request.Nonce is null || request.Nonce.Length != ChatCryptoConstants.AeadNonceBytes)
        {
            errors["nonce"] =
            [
                $"Nonce must contain exactly {ChatCryptoConstants.AeadNonceBytes} bytes."
            ];
        }

        ThrowIfInvalid("Conversation key envelope validation failed.", errors);
    }

    public static void ValidateEncryptedMessage(SendEncryptedMessageCommand command)
    {
        var errors = new Dictionary<string, string[]>(StringComparer.OrdinalIgnoreCase);
        var isPrivateType = command.Type is MessageType.Text or MessageType.Image or
            MessageType.Voice or MessageType.Video;

        if (!Enum.IsDefined(typeof(MessageType), command.Type) || !isPrivateType)
        {
            errors["type"] = ["Select Text, Image, Voice, or Video for a private E2E message."];
        }

        if (command.SenderDeviceKeyId == Guid.Empty)
        {
            errors["senderDeviceKeyId"] = ["Select the sending device key."];
        }

        if (command.KeyVersion < 1)
        {
            errors["keyVersion"] = ["KeyVersion must be greater than zero."];
        }

        var hasEncryptedContent = command.EncryptedContent is { Length: > 0 };
        var hasContentNonce = command.ContentNonce is { Length: > 0 };
        var hasAttachment = command.Attachment is not null;
        var hasAttachmentNonce = command.AttachmentNonce is { Length: > 0 };

        if (hasEncryptedContent != hasContentNonce)
        {
            errors["encryptedContent"] =
            ["EncryptedContent and ContentNonce must either both be supplied or both be omitted."];
        }

        if (hasEncryptedContent &&
            command.EncryptedContent!.Length <= ChatCryptoConstants.AeadTagBytes)
        {
            errors["encryptedContent"] =
            ["EncryptedContent must contain ciphertext plus an authentication tag."];
        }
        else if (hasEncryptedContent &&
                 command.EncryptedContent!.Length > ChatCryptoConstants.MaximumEncryptedMessageBytes)
        {
            errors["encryptedContent"] =
            [
                $"EncryptedContent may contain at most {ChatCryptoConstants.MaximumEncryptedMessageBytes} bytes."
            ];
        }

        if (hasContentNonce && command.ContentNonce!.Length != ChatCryptoConstants.AeadNonceBytes)
        {
            errors["contentNonce"] =
            [
                $"ContentNonce must contain exactly {ChatCryptoConstants.AeadNonceBytes} bytes."
            ];
        }

        if (command.Type == MessageType.Text)
        {
            if (!hasEncryptedContent)
            {
                errors["encryptedContent"] = ["An encrypted text payload is required."];
            }

            if (hasAttachment)
            {
                errors["attachment"] = ["Text messages may not contain a media attachment."];
            }

            if (hasAttachmentNonce)
            {
                errors["attachmentNonce"] = ["Text messages may not contain an attachment nonce."];
            }

            if (command.DurationMilliseconds.HasValue)
            {
                errors["durationMilliseconds"] = ["Text messages may not contain media duration."];
            }
        }
        else if (isPrivateType)
        {
            if (!hasAttachment)
            {
                errors["attachment"] = ["An encrypted media attachment is required."];
            }
            else if (!string.Equals(
                         command.Attachment!.ContentType,
                         ChatCryptoConstants.EncryptedMediaContentType,
                         StringComparison.OrdinalIgnoreCase))
            {
                errors["attachment"] =
                ["Encrypted media must be uploaded as application/octet-stream."];
            }

            if (!hasAttachmentNonce)
            {
                errors["attachmentNonce"] = ["AttachmentNonce is required for encrypted media."];
            }
            else if (command.AttachmentNonce!.Length != ChatCryptoConstants.AeadNonceBytes)
            {
                errors["attachmentNonce"] =
                [
                    $"AttachmentNonce must contain exactly {ChatCryptoConstants.AeadNonceBytes} bytes."
                ];
            }

            if (command.Type == MessageType.Image)
            {
                if (command.DurationMilliseconds.HasValue)
                {
                    errors["durationMilliseconds"] = ["Image messages may not contain media duration."];
                }
            }
            else if (!command.DurationMilliseconds.HasValue)
            {
                errors["durationMilliseconds"] =
                ["Voice and video messages require authenticated duration metadata."];
            }
            else if (command.Type == MessageType.Voice &&
                     command.DurationMilliseconds.Value is
                         < ChatCryptoConstants.MinimumMediaDurationMilliseconds or
                         > ChatCryptoConstants.MaximumVoiceDurationMilliseconds)
            {
                errors["durationMilliseconds"] =
                ["Voice duration must be between 0.3 seconds and 5 minutes."];
            }
            else if (command.Type == MessageType.Video &&
                     command.DurationMilliseconds.Value is
                         < ChatCryptoConstants.MinimumMediaDurationMilliseconds or
                         > ChatCryptoConstants.MaximumVideoDurationMilliseconds)
            {
                errors["durationMilliseconds"] =
                ["Video duration must be between 0.3 seconds and 2 minutes."];
            }
        }

        ThrowIfInvalid("Encrypted message validation failed.", errors);
    }

    public static Message CreateEncryptedMessage(
        Guid conversationId,
        Guid senderUserId,
        SendEncryptedMessageCommand command,
        DateTime sentAtUtc)
    {
        ValidateEncryptedMessage(command);

        return new Message
        {
            ConversationId = conversationId,
            SenderUserId = senderUserId,
            Type = command.Type,
            Content = null,
            EncryptedContent = command.EncryptedContent?.ToArray(),
            ContentNonce = command.ContentNonce?.ToArray(),
            EncryptionVersion = ChatEncryptionVersions.ClientE2E,
            KeyVersion = command.KeyVersion,
            SentAtUtc = sentAtUtc
        };
    }

    public static MessageAttachment CreateEncryptedAttachment(
        Guid messageId,
        Guid ownerUserId,
        StoredFileInfo storedFile,
        SendEncryptedMessageCommand command)
    {
        return new MessageAttachment
        {
            MessageId = messageId,
            OwnerUserId = ownerUserId,
            StorageKey = storedFile.StorageKey,
            MimeType = ChatCryptoConstants.EncryptedMediaContentType,
            SizeBytes = storedFile.Length,
            ContentNonce = command.AttachmentNonce?.ToArray(),
            EncryptionVersion = ChatEncryptionVersions.ClientE2E,
            KeyVersion = command.KeyVersion,
            DurationMilliseconds = command.DurationMilliseconds
        };
    }

    public static string GetNotificationBody(string senderName, MessageType type) =>
        type switch
        {
            MessageType.Image => $"{senderName} sent you an image.",
            MessageType.Voice => $"{senderName} sent you a voice message.",
            MessageType.Video => $"{senderName} sent you a video.",
            _ => $"{senderName} sent you a message."
        };

    public static string? GetServerPreview(
        MessageType type,
        string? legacyContent,
        int encryptionVersion)
    {
        if (encryptionVersion == ChatEncryptionVersions.LegacyPlaintext &&
            !string.IsNullOrWhiteSpace(legacyContent))
        {
            return legacyContent;
        }

        return type switch
        {
            MessageType.Text => encryptionVersion == ChatEncryptionVersions.ClientE2E
                ? "Encrypted message"
                : "Message",
            MessageType.Image => "Image",
            MessageType.Voice => "Voice message",
            MessageType.Video => "Video",
            MessageType.System => legacyContent,
            _ => null
        };
    }

    private static void ThrowIfInvalid(
        string message,
        Dictionary<string, string[]> errors)
    {
        if (errors.Count > 0)
        {
            throw new ValidationException(message, errors);
        }
    }
}
