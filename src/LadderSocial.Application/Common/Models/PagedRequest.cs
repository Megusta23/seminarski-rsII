namespace LadderSocial.Application.Common.Models;

public class PagedRequest
{
    private const int MaximumPageSize = 100;
    private int _page = 1;
    private int _pageSize = 20;

    public int Page
    {
        get => _page;
        set => _page = value < 1 ? 1 : value;
    }

    public int PageSize
    {
        get => _pageSize;
        set => _pageSize = value switch
        {
            < 1 => 20,
            > MaximumPageSize => MaximumPageSize,
            _ => value
        };
    }

    public string? Search { get; set; }
}
