using System.Text.Json;
using Google.Cloud.Firestore;
using WorkTimeManager.Api.Endpoints;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Tests;

/// <summary>#406: <c>PUT /api/overtime</c> kann <c>lastUpdated</c> unangetastet lassen (ohne Firestore).</summary>
public class OvertimeSaveTests
{
    private static readonly DateTimeOffset Now = new(2026, 6, 6, 9, 0, 0, TimeSpan.Zero);

    [Fact]
    public void BuildUpdate_Default_WritesMinutesAndLastUpdated()
    {
        var update = OvertimeRepository.BuildUpdate(-125, keepLastUpdated: false, Now);

        Assert.Equal(-125, update["minutes"]);
        Assert.Equal(Timestamp.FromDateTimeOffset(Now), update["lastUpdated"]);
    }

    [Fact]
    public void BuildUpdate_KeepLastUpdated_WritesOnlyMinutes()
    {
        var update = OvertimeRepository.BuildUpdate(45, keepLastUpdated: true, Now);

        Assert.Equal(45, update["minutes"]);
        Assert.False(update.ContainsKey("lastUpdated"));
        Assert.Single(update);
    }

    [Theory]
    [InlineData("""{"minutes":30}""", null)]
    [InlineData("""{"minutes":30,"keepLastUpdated":null}""", null)]
    [InlineData("""{"minutes":30,"keepLastUpdated":false}""", false)]
    [InlineData("""{"minutes":30,"keepLastUpdated":true}""", true)]
    public void Request_KeepLastUpdated_IsOptionalInBody(string json, bool? expected)
    {
        var request = JsonSerializer.Deserialize<OvertimeEndpoints.SaveOvertimeRequest>(
            json, new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.NotNull(request);
        Assert.Equal(30, request.Minutes);
        Assert.Equal(expected, request.KeepLastUpdated);
    }
}
