using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Domain;

namespace WorkTimeManager.Api.Tests;

public class BreakCalculatorTests
{
    private static DateTimeOffset At(int hour, int minute = 0) =>
        new(2026, 6, 5, hour, minute, 0, TimeSpan.Zero);

    private static WorkEntryDto Entry(DateTimeOffset start, DateTimeOffset end, params BreakDto[] breaks) => new()
    {
        Id = "2026-06-05",
        Date = new DateTimeOffset(2026, 6, 5, 0, 0, 0, TimeSpan.Zero),
        WorkStart = start,
        WorkEnd = end,
        Breaks = breaks,
    };

    [Fact]
    public void Validate_LongDay_RequiresFortyFiveMinutes()
    {
        // 10h netto, keine Pausen
        var result = BreakCalculator.ValidateCompliance(Entry(At(7), At(17)));
        Assert.False(result.IsCompliant);
        Assert.Equal(45 * 60_000, result.RequiredBreakMs);
        Assert.Equal(45 * 60_000, result.MissingBreakMs);
    }

    [Fact]
    public void Validate_MediumDay_RequiresThirtyMinutes()
    {
        // 7h netto
        var result = BreakCalculator.ValidateCompliance(Entry(At(8), At(15)));
        Assert.Equal(30 * 60_000, result.RequiredBreakMs);
    }

    [Fact]
    public void Validate_ShortDay_RequiresNoBreak()
    {
        // 5h netto
        var result = BreakCalculator.ValidateCompliance(Entry(At(8), At(13)));
        Assert.True(result.IsCompliant);
        Assert.Equal(0, result.RequiredBreakMs);
    }

    [Fact]
    public void Apply_LongDay_AddsLunchAndShortBreak()
    {
        var result = BreakCalculator.CalculateAndApply(Entry(At(7), At(18))); // 11h
        Assert.Equal(2, result.Breaks.Count);
        Assert.Contains(result.Breaks, b => b.Name == "Mittagspause");
        Assert.Contains(result.Breaks, b => b.Name == "Kurzpause");
        Assert.All(result.Breaks, b => Assert.True(b.IsAutomatic));
    }

    [Fact]
    public void Apply_MediumDay_AddsOnlyLunch()
    {
        var result = BreakCalculator.CalculateAndApply(Entry(At(8), At(15))); // 7h
        var b = Assert.Single(result.Breaks);
        Assert.Equal("Mittagspause", b.Name);
        Assert.Equal(30 * 60_000, (long)(b.End!.Value - b.Start).TotalMilliseconds);
    }

    [Fact]
    public void Apply_WithoutTimes_ReturnsUnchanged()
    {
        var entry = new WorkEntryDto { Id = "x", Date = At(0) };
        Assert.Same(entry, BreakCalculator.CalculateAndApply(entry));
    }
}
