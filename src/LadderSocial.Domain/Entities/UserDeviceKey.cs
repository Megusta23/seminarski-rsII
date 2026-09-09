using LadderSocial.Domain.Common;

namespace LadderSocial.Domain.Entities;

public sealed class UserDeviceKey : Entity
{
    public Guid UserId { get; set; }
    public string DeviceId { get; set; } = string.Empty;
    public byte[] PublicKey { get; set; } = Array.Empty<byte>();
    public DateTime CreatedAtUtc { get; set; }
    public DateTime LastSeenAtUtc { get; set; }
    public DateTime? RevokedAtUtc { get; set; }
}
