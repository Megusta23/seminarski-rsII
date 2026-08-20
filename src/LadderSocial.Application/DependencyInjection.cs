using Microsoft.Extensions.DependencyInjection;

namespace LadderSocial.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        // Feature services are registered here as they are implemented.
        return services;
    }
}
