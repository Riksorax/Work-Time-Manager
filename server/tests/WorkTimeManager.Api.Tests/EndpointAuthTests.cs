using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using WorkTimeManager.Api.Contracts;

namespace WorkTimeManager.Api.Tests;

/// <summary>
/// Alle Geschäftslogik-Endpunkte müssen ohne gültiges Firebase-Token mit 401 antworten —
/// die Autorisierung greift vor dem Handler, daher ohne echte Firestore-Credentials testbar.
/// </summary>
public class EndpointAuthTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public EndpointAuthTests(WebApplicationFactory<Program> factory) => _client = factory.CreateClient();

    [Theory]
    [InlineData("/api/work-entries/2026/6")]
    [InlineData("/api/work-entries/2026/6/5")]
    [InlineData("/api/overtime")]
    [InlineData("/api/settings")]
    [InlineData("/api/profile")]
    public async Task Get_WithoutToken_ReturnsUnauthorized(string url)
    {
        var response = await _client.GetAsync(url);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task PutWorkEntry_WithoutToken_ReturnsUnauthorized()
    {
        var entry = new WorkEntryDto { Id = "2026-06-05", Date = DateTimeOffset.UtcNow };
        var response = await _client.PutAsJsonAsync("/api/work-entries", entry);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task DeleteWorkEntry_WithoutToken_ReturnsUnauthorized()
    {
        var response = await _client.DeleteAsync("/api/work-entries/2026/6/5");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
