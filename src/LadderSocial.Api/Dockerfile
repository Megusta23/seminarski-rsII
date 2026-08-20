FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source

COPY Directory.Build.props Directory.Packages.props global.json ./
COPY src/LadderSocial.Domain/LadderSocial.Domain.csproj src/LadderSocial.Domain/
COPY src/LadderSocial.Application/LadderSocial.Application.csproj src/LadderSocial.Application/
COPY src/LadderSocial.Infrastructure/LadderSocial.Infrastructure.csproj src/LadderSocial.Infrastructure/
COPY src/LadderSocial.Api/LadderSocial.Api.csproj src/LadderSocial.Api/
RUN dotnet restore src/LadderSocial.Api/LadderSocial.Api.csproj

COPY src/ src/
RUN dotnet publish src/LadderSocial.Api/LadderSocial.Api.csproj \
    --configuration Release \
    --output /app/publish \
    --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENTRYPOINT ["dotnet", "LadderSocial.Api.dll"]
