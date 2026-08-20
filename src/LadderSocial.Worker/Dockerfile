FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

COPY Directory.Build.props Directory.Packages.props global.json ./
COPY src/LadderSocial.Domain/LadderSocial.Domain.csproj src/LadderSocial.Domain/
COPY src/LadderSocial.Application/LadderSocial.Application.csproj src/LadderSocial.Application/
COPY src/LadderSocial.Infrastructure/LadderSocial.Infrastructure.csproj src/LadderSocial.Infrastructure/
COPY src/LadderSocial.Worker/LadderSocial.Worker.csproj src/LadderSocial.Worker/
RUN dotnet restore src/LadderSocial.Worker/LadderSocial.Worker.csproj

COPY src/ src/
RUN dotnet publish src/LadderSocial.Worker/LadderSocial.Worker.csproj \
    --configuration Release \
    --output /app/publish \
    --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "LadderSocial.Worker.dll"]
