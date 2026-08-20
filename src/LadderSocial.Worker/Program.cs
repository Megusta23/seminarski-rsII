using LadderSocial.Infrastructure;
using LadderSocial.Worker;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddHostedService<WorkerBootstrapService>();

var host = builder.Build();
await host.RunAsync();
