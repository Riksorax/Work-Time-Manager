using System.Globalization;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Domain;

namespace WorkTimeManager.Api.Tests;

public class ReportCalculatorTests
{
    private static readonly SettingsDto Settings = new() { WeeklyTargetHours = 40, Workdays = new[] { 1, 2, 3, 4, 5 } };
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

    [Fact]
    public void DailyStat_TueSatContract_MondayHasNoTarget_SaturdayHasFullTarget_BugFix217()
    {
        // 2026-06-01 = Montag, 2026-06-06 = Samstag
        var tueSat = new SettingsDto { WeeklyTargetHours = 40, Workdays = new[] { 2, 3, 4, 5, 6 } };

        var mondayStat = ReportCalculator.CalculateDailyStat(Array.Empty<WorkEntryDto>(), new DateOnly(2026, 6, 1), tueSat);
        Assert.Equal(0, mondayStat.TargetMs);

        var saturdayStat = ReportCalculator.CalculateDailyStat(Array.Empty<WorkEntryDto>(), new DateOnly(2026, 6, 6), tueSat);
        Assert.Equal(EightHoursMs, saturdayStat.TargetMs);
    }

    // ── Jahresauswertung Urlaub/Krank (#278) ────────────────────────────────

    private static WorkEntryDto Leave(int year, int month, int day, string type) => new()
    {
        Id = $"{year:D4}-{month:D2}-{day:D2}",
        Date = new DateTimeOffset(year, month, day, 0, 0, 0, TimeSpan.Zero),
        Type = type,
    };

    [Fact]
    public void YearlyLeave_CountsVacationAndSick_HolidayNotCounted()
    {
        var entries = new[]
        {
            Leave(2026, 1, 5, "vacation"), Leave(2026, 7, 6, "vacation"),
            Leave(2026, 3, 2, "sick"), Leave(2026, 12, 24, "holiday"),
            Leave(2026, 6, 1, "work"),
        };
        var r = ReportCalculator.CalculateYearlyLeave(entries, 2026, new SettingsDto { VacationDaysPerYear = 30 });

        Assert.Equal(2026, r.Year);
        Assert.Equal(30, r.VacationDaysPerYear);
        Assert.Equal(2, r.VacationDaysTaken);
        Assert.Equal(28, r.VacationDaysRemaining);
        Assert.Equal(1, r.SickDays);
    }

    [Fact]
    public void YearlyLeave_YearBoundary_OnlyCountsRequestedYear()
    {
        var entries = new[]
        {
            Leave(2025, 12, 31, "vacation"), Leave(2026, 1, 1, "vacation"),
            Leave(2026, 12, 31, "sick"), Leave(2027, 1, 1, "sick"),
        };
        var r = ReportCalculator.CalculateYearlyLeave(entries, 2026, new SettingsDto { VacationDaysPerYear = 30 });

        Assert.Equal(1, r.VacationDaysTaken);
        Assert.Equal(1, r.SickDays);
    }

    [Fact]
    public void YearlyLeave_Weekend_StillCounts()
    {
        // 2026-06-06 ist ein Samstag.
        var r = ReportCalculator.CalculateYearlyLeave(
            new[] { Leave(2026, 6, 6, "vacation") }, 2026, new SettingsDto { VacationDaysPerYear = 30 });
        Assert.Equal(1, r.VacationDaysTaken);
    }

    [Fact]
    public void YearlyLeave_Remaining_CanBeNegative()
    {
        var entries = Enumerable.Range(1, 5).Select(d => Leave(2026, 2, d, "vacation")).ToArray();
        var r = ReportCalculator.CalculateYearlyLeave(entries, 2026, new SettingsDto { VacationDaysPerYear = 3 });
        Assert.Equal(-2, r.VacationDaysRemaining);
    }

    [Fact]
    public void YearlyLeave_MissingEntitlement_DefaultsTo30()
    {
        var r = ReportCalculator.CalculateYearlyLeave(
            new[] { Leave(2026, 2, 2, "vacation") }, 2026, new SettingsDto());
        Assert.Equal(30, r.VacationDaysPerYear);
        Assert.Equal(29, r.VacationDaysRemaining);
    }

    [Fact]
    public void YearlyLeave_NoEntries_AllZero()
    {
        var r = ReportCalculator.CalculateYearlyLeave(
            Array.Empty<WorkEntryDto>(), 2026, new SettingsDto { VacationDaysPerYear = 0 });
        Assert.Equal(0, r.VacationDaysTaken);
        Assert.Equal(0, r.VacationDaysRemaining);
        Assert.Equal(0, r.SickDays);
    }
}
