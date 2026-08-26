using System.Security.Cryptography;
using System.Text;

namespace LadderSocial.Infrastructure.Persistence.Seed;

internal static class DemoSeedIds
{
    private const string Prefix = "ladder-social-demo:";

    public static Guid For(string key)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(Prefix + key));
        Span<byte> bytes = stackalloc byte[16];
        hash.AsSpan(0, 16).CopyTo(bytes);
        return new Guid(bytes);
    }
}
