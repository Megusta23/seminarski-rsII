using LadderSocial.Domain.Constants;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class ProofLayoutCodesTests
{
    [Theory]
    [InlineData(ProofLayoutCodes.Single, 1)]
    [InlineData(ProofLayoutCodes.TwoVertical, 2)]
    [InlineData(ProofLayoutCodes.TwoHorizontal, 2)]
    [InlineData(ProofLayoutCodes.ThreeGrid, 3)]
    [InlineData(ProofLayoutCodes.FourGrid, 4)]
    public void RequiredPhotoCount_ReturnsExpectedValue(string code, int expected)
    {
        Assert.Equal(expected, ProofLayoutCodes.RequiredPhotoCount(code));
    }

    [Fact]
    public void Normalize_IsCaseInsensitiveAndTrimsInput()
    {
        Assert.Equal(ProofLayoutCodes.TwoVertical, ProofLayoutCodes.Normalize("  TWO-VERTICAL "));
    }

    [Fact]
    public void Normalize_RejectsUnsupportedLayout()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => ProofLayoutCodes.Normalize("unknown"));
    }
}
