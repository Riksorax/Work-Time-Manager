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
    public void MonthlyReport_TotalOvertimeIsStoredBalance_535()
    {
        // Vor #535: Total = Monat + Saldo (−0,5 h + 1 h). Der Saldo enthält den laufenden Monat schon,
        // deshalb ist das Gesamt jetzt nur der gespeicherte Saldo.
        var entries = new[] { WorkDay(5, 8, 16, breakMinutes: 30) };
        const long stored = 3_600_000L; // +1h Saldo
        var report = ReportCalculator.CalculateMonthlyReport(entries, new DateOnly(2026, 6, 1), Settings, stored);

        Assert.Equal((long)(-0.5 * 3_600_000), report.MonthlyOvertimeMs);
        Assert.Equal(stored, report.TotalOvertimeMs);
        Assert.Equal(1, report.WorkDays);
    }

    [Theory]
    [InlineData(-5_400_000L)]
    [InlineData(0L)]
    [InlineData(7_200_000L)]
    public void MonthlyReport_TotalOvertime_EqualsStoredBalance_IndependentOfMonth_535(long stored)
    {
        var entries = new[] { WorkDay(1, 8, 18), WorkDay(2, 8, 12) }; // +2 h, −4 h
        var report = ReportCalculator.CalculateMonthlyReport(entries, new DateOnly(2026, 6, 1), Settings, stored);

        Assert.Equal(-2 * 3_600_000L, report.MonthlyOvertimeMs);
        Assert.Equal(stored, report.TotalOvertimeMs);
    }

    [Fact]
    public void MonthlyReport_NoEntries_TotalOvertimeIsStoredBalance_535()
    {
        var report = ReportCalculator.CalculateMonthlyReport(
            Array.Empty<WorkEntryDto>(), new DateOnly(2026, 6, 1), Settings, -3_600_000L);

        Assert.Equal(0, report.MonthlyOvertimeMs);
        Assert.Equal(-3_600_000L, report.TotalOvertimeMs);
    }

    // ── Abwesenheit an einem freien Tag (#535) ──────────────────────────────

    private static WorkEntryDto Absence(int day, string type, int? manualMinutes = null) => new()
    {
        Id = $"2026-06-{day:D2}",
        Date = new DateTimeOffset(2026, 6, day, 0, 0, 0, TimeSpan.Zero),
        Type = type,
        ManualOvertimeMinutes = manualMinutes,
    };

    // 2026-06-06 = Samstag, 2026-06-07 = Sonntag (Mo–Fr-Vertrag: freie Tage).
    [Theory]
    [InlineData("vacation")]
    [InlineData("sick")]
    [InlineData("holiday")]
    public void DailyStat_AbsenceOnFreeDay_TargetAndWorkedAreDailyTarget_NoOvertime_535(string type)
    {
        var stat = ReportCalculator.CalculateDailyStat(new[] { Absence(6, type) }, new DateOnly(2026, 6, 6), Settings);

        Assert.Equal(EightHoursMs, stat.TargetMs);
        Assert.Equal(EightHoursMs, stat.WorkedMs);
        Assert.Equal(0, stat.OvertimeMs);
    }

    [Fact]
    public void DailyStat_AbsenceOnFreeDay_ManualOvertimeStillCounts_535()
    {
        var stat = ReportCalculator.CalculateDailyStat(
            new[] { Absence(6, "vacation", manualMinutes: 30) }, new DateOnly(2026, 6, 6), Settings);

        Assert.Equal(EightHoursMs, stat.TargetMs);
        Assert.Equal(EightHoursMs, stat.WorkedMs);
        Assert.Equal(30 * 60_000L, stat.OvertimeMs);
    }

    [Fact]
    public void DailyStat_AbsenceOnContractDay_Unchanged_535()
    {
        var stat = ReportCalculator.CalculateDailyStat(new[] { Absence(5, "sick") }, new DateOnly(2026, 6, 5), Settings);

        Assert.Equal(EightHoursMs, stat.TargetMs);
        Assert.Equal(EightHoursMs, stat.WorkedMs);
        Assert.Equal(0, stat.OvertimeMs);
    }

    [Fact]
    public void DailyStat_WorkOnFreeDay_Unchanged_NoTarget_AllOvertime_535()
    {
        var saturday = WorkDay(6, 8, 12);
        var stat = ReportCalculator.CalculateDailyStat(new[] { saturday }, new DateOnly(2026, 6, 6), Settings);

        Assert.Equal(0, stat.TargetMs);
        Assert.Equal(4 * 3_600_000L, stat.WorkedMs);
        Assert.Equal(4 * 3_600_000L, stat.OvertimeMs);
    }

    [Fact]
    public void DailyStat_FreeDayWithoutEntry_NoTarget_535()
    {
        var stat = ReportCalculator.CalculateDailyStat(Array.Empty<WorkEntryDto>(), new DateOnly(2026, 6, 6), Settings);

        Assert.Equal(0, stat.TargetMs);
        Assert.Equal(0, stat.WorkedMs);
        Assert.Equal(0, stat.OvertimeMs);
    }

    [Fact]
    public void WeeklyReport_AbsenceOnFreeDay_NoOvertime_535()
    {
        // Mo 1.6. Arbeit 8 h, Sa 6.6. Urlaub, So 7.6. Krank.
        var entries = new[] { WorkDay(1, 8, 16), Absence(6, "vacation"), Absence(7, "sick") };
        var report = ReportCalculator.CalculateWeeklyReport(entries, new DateOnly(2026, 6, 3), Settings);

        Assert.Equal(3 * EightHoursMs, report.TotalWorkedMs);
        Assert.Equal(3, report.WorkDays);
        Assert.Equal(0, report.OvertimeMs); // vor #535: 16 h
    }

    [Fact]
    public void WeeklyReport_WorkOnFreeDay_StillOvertime_535()
    {
        // Sa 6.6. Arbeit 4 h: kein Soll, die 4 h sind Überstunden (unverändert).
        var entries = new[] { WorkDay(1, 8, 16), WorkDay(6, 8, 12) };
        var report = ReportCalculator.CalculateWeeklyReport(entries, new DateOnly(2026, 6, 3), Settings);

        Assert.Equal(2, report.WorkDays);
        Assert.Equal(4 * 3_600_000L, report.OvertimeMs);
    }

    [Fact]
    public void WeeklyReport_AbsenceAndWorkOnSameFreeDay_TargetCountsOnce_535()
    {
        // Sa 6.6. Feiertag + 2 h Arbeit: Soll 8 h einmal, geleistet 8 h + 2 h → 2 h Überstunden.
        var entries = new[] { Absence(6, "holiday"), WorkDay(6, 8, 10) };
        var report = ReportCalculator.CalculateWeeklyReport(entries, new DateOnly(2026, 6, 6), Settings);
        var stat = ReportCalculator.CalculateDailyStat(entries, new DateOnly(2026, 6, 6), Settings);

        Assert.Equal(1, report.WorkDays);
        Assert.Equal(2 * 3_600_000L, report.OvertimeMs);
        Assert.Equal(EightHoursMs, stat.TargetMs);
        Assert.Equal(2 * 3_600_000L, stat.OvertimeMs);
    }

    [Fact]
    public void MonthlyReport_AbsenceOnFreeDay_NoOvertime_ManualStillCounts_535()
    {
        var entries = new[] { Absence(6, "vacation", manualMinutes: 15), Absence(5, "vacation") };
        var report = ReportCalculator.CalculateMonthlyReport(entries, new DateOnly(2026, 6, 1), Settings, 0);

        Assert.Equal(2, report.WorkDays);
        Assert.Equal(2 * EightHoursMs, report.TotalWorkedMs);
        Assert.Equal(15 * 60_000L, report.MonthlyOvertimeMs); // vor #535: 8 h 15 min
    }

    [Fact]
    public void Reports_AbsenceWithoutWorkdays_TargetAndWorkedZero_535()
    {
        var none = new SettingsDto { WeeklyTargetHours = 40, Workdays = Array.Empty<int>() };
        var entries = new[] { Absence(6, "vacation") };

        var stat = ReportCalculator.CalculateDailyStat(entries, new DateOnly(2026, 6, 6), none);
        var week = ReportCalculator.CalculateWeeklyReport(entries, new DateOnly(2026, 6, 6), none);
        var month = ReportCalculator.CalculateMonthlyReport(entries, new DateOnly(2026, 6, 1), none, 0);

        Assert.Equal(0, stat.TargetMs);
        Assert.Equal(0, stat.WorkedMs);
        Assert.Equal(0, stat.OvertimeMs);
        Assert.Equal(0, week.OvertimeMs);
        Assert.Equal(0, month.MonthlyOvertimeMs);
        Assert.Equal(1, month.WorkDays);
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

    // ── Tagessoll auf die Minute gerundet (#535) ────────────────────────────

    [Fact]
    public void DailyTarget_NotDivisible_RoundsToFullMinute_535()
    {
        // 39 h / 7 Tage = 334,2857… min → 334 min (vorher abgeschnitten: 20 057 142 ms).
        var settings = new SettingsDto { WeeklyTargetHours = 39, Workdays = new[] { 1, 2, 3, 4, 5, 6, 7 } };
        var stat = ReportCalculator.CalculateDailyStat(Array.Empty<WorkEntryDto>(), new DateOnly(2026, 6, 1), settings);

        Assert.Equal(334 * 60_000L, stat.TargetMs);
    }

    [Fact]
    public void DailyTarget_HalfMinute_RoundsUp_LikeWebRoundMsToMinute_535()
    {
        // 37,5 h / 4 Tage = 562,5 min → 563 min (kaufmännisch, wie roundMsToMinute im Web).
        var settings = new SettingsDto { WeeklyTargetHours = 37.5, Workdays = new[] { 1, 2, 3, 4 } };
        var stat = ReportCalculator.CalculateDailyStat(Array.Empty<WorkEntryDto>(), new DateOnly(2026, 6, 1), settings);

        Assert.Equal(563 * 60_000L, stat.TargetMs);
    }

    [Fact]
    public void DailyTarget_NoWorkdays_IsZero_NoDivisionByZero_535()
    {
        var settings = new SettingsDto { WeeklyTargetHours = 40, Workdays = Array.Empty<int>() };
        var stat = ReportCalculator.CalculateDailyStat(Array.Empty<WorkEntryDto>(), new DateOnly(2026, 6, 1), settings);
        var week = ReportCalculator.CalculateWeeklyReport(new[] { WorkDay(1, 8, 16) }, new DateOnly(2026, 6, 1), settings);

        Assert.Equal(0, stat.TargetMs);
        Assert.Equal(EightHoursMs, week.OvertimeMs);
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
