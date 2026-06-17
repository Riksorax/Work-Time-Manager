using System.Globalization;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Domain;

namespace WorkTimeManager.Api.Tests;

public class ReportCalculatorTests
{
    private static readonly SettingsDto Settings = new() { WeeklyTargetHours = 40, WorkdaysPerWeek = 5 };
    private const long EightHoursMs = 8 * 3_600_000L;

    private static WorkEntryDto WorkDay(int day, int startHour, int endHour, int breakMinutes = 0)
    {
        var date = new DateTimeOffset(2026, 6, day, 0, 0, 0, TimeSpan.Zero);
        var start = new DateTimeOffset(2026, 6, day, startHour, 0, 0, TimeSpan.Zero);
        var end = new DateTimeOffset(2026, 6, day, endHour, 0, 0, TimeSpan.Zero);
        var breaks = breakMinutes > 0
            ? new[] { new BreakDto { Id = "b", Start = start.AddHours(3), End = start.AddHours(3).AddMinutes(breakMinutes) } }
            : Array.Empty<BreakDto>();
        return new WorkEntryDto
        {
            Id = $"2026-06-{day:D2}",
            Date = date,
            WorkStart = start,
            WorkEnd = end,
            Type = "work",
            Breaks = breaks,
        };
    }

    [Fact]
    public void IsoWeekNumber_MatchesFrameworkAcrossYear()
    {
        // Gegen die ISO-8601-Referenzimplementierung des .NET-Frameworks validieren.
        for (var d = new DateOnly(2024, 1, 1); d < new DateOnly(2027, 1, 1); d = d.AddDays(1))
        {
            var expected = ISOWeek.GetWeekOfYear(d.ToDateTime(TimeOnly.MinValue));
            Assert.Equal(expected, ReportCalculator.GetIsoWeekNumber(d));
        }
    }

    [Fact]
    public void DailyStat_UsesNetWork_AgainstDailyTarget()
    {
        // 8h brutto − 30min Pause = 7,5h netto; Soll = 8h
        var entries = new[] { WorkDay(5, 8, 16, breakMinutes: 30) };
        var stat = ReportCalculator.CalculateDailyStat(entries, new DateOnly(2026, 6, 5), Settings);

        Assert.Equal(EightHoursMs, stat.TargetMs);
        Assert.Equal((long)(7.5 * 3_600_000), stat.WorkedMs);
        Assert.Equal((long)(-0.5 * 3_600_000), stat.OvertimeMs);
    }

    [Fact]
    public void DailyStat_NonWorkType_CountsAsTargetMet()
    {
        var vacation = new WorkEntryDto
        {
            Id = "2026-06-05",
            Date = new DateTimeOffset(2026, 6, 5, 0, 0, 0, TimeSpan.Zero),
            Type = "vacation",
        };
        var stat = ReportCalculator.CalculateDailyStat(new[] { vacation }, new DateOnly(2026, 6, 5), Settings);

        Assert.Equal(EightHoursMs, stat.WorkedMs);
        Assert.Equal(0, stat.OvertimeMs);
    }

    [Fact]
    public void WeeklyReport_TracksGrossWorkBreaksAndOvertime()
    {
        var entries = new[] { WorkDay(5, 8, 16, breakMinutes: 30) }; // Fr, 5. Juni 2026
        var report = ReportCalculator.CalculateWeeklyReport(entries, new DateOnly(2026, 6, 5), Settings);

        Assert.Equal(1, report.WorkDays);
        Assert.Equal(EightHoursMs, report.TotalWorkedMs);
        Assert.Equal(30 * 60_000L, report.TotalBreaksMs);
        Assert.Equal((long)(-0.5 * 3_600_000), report.OvertimeMs); // 7,5h netto − 8h Soll
        Assert.Equal(ISOWeek.GetWeekOfYear(new DateTime(2026, 6, 5)), report.WeekNumber);
    }

    [Fact]
    public void MonthlyReport_AddsStoredOvertimeToTotal()
    {
        var entries = new[] { WorkDay(5, 8, 16, breakMinutes: 30) };
        const long stored = 3_600_000L; // +1h Altsaldo
        var report = ReportCalculator.CalculateMonthlyReport(entries, new DateOnly(2026, 6, 1), Settings, stored);

        Assert.Equal((long)(-0.5 * 3_600_000), report.MonthlyOvertimeMs);
        Assert.Equal((long)(-0.5 * 3_600_000) + stored, report.TotalOvertimeMs);
        Assert.Equal(1, report.WorkDays);
    }
}
