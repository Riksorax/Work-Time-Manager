using System.Net;
using Microsoft.AspNetCore.Mvc.Testing;

namespace WorkTimeManager.Api.Tests;

public class HealthAndAuthTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public HealthAndAuthTests(WebApplicationFactory<Program> factory) => _factory = factory;

    [Fact]
    public async Task Health_ReturnsOk()
    {
        var response = await _factory.CreateClient().GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Me_WithoutToken_ReturnsUnauthorized()
    {
        var response = await _factory.CreateClient().GetAsync("/api/me");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
