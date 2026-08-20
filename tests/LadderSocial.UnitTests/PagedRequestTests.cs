using LadderSocial.Application.Common.Models;
using Xunit;

namespace LadderSocial.UnitTests;

public sealed class PagedRequestTests
{
    [Fact]
    public void PageSize_IsCappedAtOneHundred()
    {
        var request = new PagedRequest { PageSize = 500 };

        Assert.Equal(100, request.PageSize);
    }

    [Fact]
    public void Page_IsNeverLessThanOne()
    {
        var request = new PagedRequest { Page = 0 };

        Assert.Equal(1, request.Page);
    }
}
