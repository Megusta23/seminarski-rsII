namespace LadderSocial.Domain.Constants;

public static class ChatCryptoConstants
{
    public const string EncryptedMediaContentType = "application/octet-stream";
    public const int X25519PublicKeyBytes = 32;
    public const int AeadNonceBytes = 12;
    public const int ConversationKeyBytes = 32;
    public const int AeadTagBytes = 16;
    public const int WrappedConversationKeyBytes = ConversationKeyBytes + AeadTagBytes;
    public const int MaximumEncryptedMessageBytes = 20 * 1024;
    public const int MaximumEncryptedMediaBytes = 25 * 1024 * 1024;
    public const int MaximumMediaDurationMilliseconds = 60 * 60 * 1000;
}
