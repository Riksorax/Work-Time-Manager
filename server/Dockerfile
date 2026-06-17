FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore (cached layer)
COPY WorkTimeManager.slnx .
COPY src/WorkTimeManager.Api/WorkTimeManager.Api.csproj src/WorkTimeManager.Api/
COPY tests/WorkTimeManager.Api.Tests/WorkTimeManager.Api.Tests.csproj tests/WorkTimeManager.Api.Tests/
RUN dotnet restore WorkTimeManager.slnx

# Build & publish
COPY . .
RUN dotnet publish src/WorkTimeManager.Api/WorkTimeManager.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
USER app

COPY --from=build /app/publish .

EXPOSE 8080
ENV ASPNETCORE_HTTP_PORTS=8080
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "WorkTimeManager.Api.dll"]
