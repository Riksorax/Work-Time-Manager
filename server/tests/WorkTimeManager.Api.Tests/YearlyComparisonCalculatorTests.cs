using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Domain;
using WorkTimeManager.Api.Endpoints;

namespace WorkTimeManager.Api.Tests;

/// <summary>Jahresvergleich mit dem Vorjahr (#530). Alle Jahre und Stichtage fest.</summary>
public class YearlyComparisonCalculatorTests
{
    private static readonly SettingsDto Settings = new() { WeeklyTargetHours = 40, Workdays = new[] { 1, 2, 3, 4, 5 } };
    private static readonly SettingsDto OddSettings = new() { WeeklyTargetHours = 39, Workdays = new[] { 1, 2, 3, 4, 6 } };
    private const long H = 3_600_000L;
    private const long Min = 60_000L;

    private static WorkEntryDto Work(
        int y, int m, int d, int startHour, int endHour, int breakMinutes = 0, int? manualMinutes = null)
    {
        var start = new DateTimeOffset(y, m, d, startHour, 0, 0, TimeSpan.Zero);
        return new WorkEntryDto
        {
            Id = $"{y:D4}-{m:D2}-{d:D2}",
            Date = new DateTimeOffset(y, m, d, 0, 0, 0, TimeSpan.Zero),
            WorkStart = start,
            WorkEnd = new DateTimeOffset(y, m, d, endHour, 0, 0, TimeSpan.Zero),
            Type = "work",
            ManualOvertimeMinutes = manualMinutes,
            Breaks = breakMinutes > 0
                ? new[] { new BreakDto { Id = "b", Start = start.AddHours(3), End = start.AddHours(3).AddMinutes(breakMinutes) } }
                : Array.Empty<BreakDto>(),
        };
    }

    private static WorkEntryDto WorkMs(int y, int m, int d, long durationMs)
    {
        var start = new DateTimeOffset(y, m, d, 8, 0, 0, TimeSpan.Zero);
        return new WorkEntryDto
        {
            Id = $"{y:D4}-{m:D2}-{d:D2}",
            Date = new DateTimeOffset(y, m, d, 0, 0, 0, TimeSpan.Zero),
            WorkStart = start,
            WorkEnd = start.AddMilliseconds(durationMs),
        };
    }

    private static WorkEntryDto Leave(int y, int m, int d, string type, int? manualMinutes = null) => new()
    {
        Id = $"{y:D4}-{m:D2}-{d:D2}",
        Date = new DateTimeOffset(y, m, d, 0, 0, 0, TimeSpan.Zero),
        Type = type,
        ManualOvertimeMinutes = manualMinutes,
    };

    private static WorkEntryDto Open(int y, int m, int d, int startHour) => new()
    {
        Id = $"{y:D4}-{m:D2}-{d:D2}",
        Date = new DateTimeOffset(y, m, d, 0, 0, 0, TimeSpan.Zero),
        WorkStart = new DateTimeOffset(y, m, d, startHour, 0, 0, TimeSpan.Zero),
        Type = "work",
    };

    private static YearlySummaryDto Summary(
        IReadOnlyList<WorkEntryDto> entries, int year, MonthDay? until = null, SettingsDto? settings = null) =>
        ReportCalculator.CalculateYearlySummary(entries, year, settings ?? Settings, until);

    private static YearlyComparisonDto Compare(
        IReadOnlyList<WorkEntryDto> current, IReadOnlyList<WorkEntryDto> previous, int year,
        MonthDay? until = null, SettingsDto? settings = null) =>
        ReportCalculator.CalculateYearlyComparison(
            Summary(current, year, until, settings), Summary(previous, year - 1, until, settings), until);

    /// <summary>Gemischte Einträge über das Jahr: Arbeit mit Pausen, Wochenende, Abwesenheiten, manuelle Überstunden, offen.</summary>
    private static List<WorkEntryDto> MixedYear(int y)
    {
        var list = new List<WorkEntryDto>();
        var i = 0;
        for (var d = new DateOnly(y, 1, 1); d.Year == y; d = d.AddDays(3))
        {
            i++;
            list.Add((i % 9) switch
            {
                0 => Leave(d.Year, d.Month, d.Day, "vacation"),
                1 => Leave(d.Year, d.Month, d.Day, "sick", manualMinutes: 15),
                2 => Leave(d.Year, d.Month, d.Day, "holiday"),
                3 => Open(d.Year, d.Month, d.Day, 9),
                4 => Work(d.Year, d.Month, d.Day, 7, 18, breakMinutes: 45, manualMinutes: -20),
                _ => Work(d.Year, d.Month, d.Day, 8, 15 + i % 4, breakMinutes: 30 * (i % 3)),
            });
        }
        return list;
    }

    // ── Form ──────────────────────────────────────────────────────────────

    [Fact]
    public void Summary_Empty_Has12ZeroMonths_NoData()
    {
        var s = Summary(Array.Empty<WorkEntryDto>(), 2026);

        Assert.Equal(2026, s.Year);
        Assert.False(s.HasData);
        Assert.Equal(Enumerable.Range(1, 12), s.Months.Select(m => m.Month));
        Assert.All(s.Months, m => Assert.Equal((0L, 0L, 0), (m.WorkedMs, m.OvertimeMs, m.WorkDays)));
        Assert.Equal(0, s.TotalWorkedMs);
        Assert.Equal(0, s.TotalBreaksMs);
        Assert.Equal(0, s.OvertimeMs);
        Assert.Equal(0, s.WorkDays);
        Assert.Equal(0, s.VacationDays);
        Assert.Equal(0, s.SickDays);
        Assert.Equal(0, s.HolidayDays);
    }

    [Fact]
    public void Summary_IgnoresEntriesOfOtherYears()
    {
        var s = Summary(new[] { Work(2025, 12, 31, 8, 16), Work(2027, 1, 1, 8, 16) }, 2026);
        Assert.False(s.HasData);
        Assert.Equal(0, s.TotalWorkedMs);
    }

    // ── Summen und Parität mit dem Monatsbericht ──────────────────────────

    [Fact]
    public void Summary_MonthsSumToYear()
    {
        var s = Summary(MixedYear(2026), 2026, settings: OddSettings);

        Assert.True(s.HasData);
        Assert.Equal(s.Months.Sum(m => m.WorkedMs), s.TotalWorkedMs);
        Assert.Equal(s.Months.Sum(m => m.OvertimeMs), s.OvertimeMs);
        Assert.Equal(s.Months.Sum(m => m.WorkDays), s.WorkDays);
        Assert.NotEqual(0, s.OvertimeMs);
    }

    [Fact]
    public void Summary_Parity_EachMonthMatchesMonthlyReport()
    {
        var entries = MixedYear(2026);
        var s = Summary(entries, 2026, settings: OddSettings);

        long breaks = 0;
        for (var month = 1; month <= 12; month++)
        {
            var monthEntries = entries.Where(e => e.Date.Month == month).ToList();
            var monthly = ReportCalculator.CalculateMonthlyReport(
                monthEntries, new DateOnly(2026, month, 1), OddSettings, storedOvertimeMs: 77 * H);
            var m = s.Months[month - 1];
            Assert.Equal(month, m.Month);
            Assert.Equal(monthly.MonthlyOvertimeMs, m.OvertimeMs);
            Assert.Equal(monthly.TotalWorkedMs - monthly.TotalBreaksMs, m.WorkedMs);
            Assert.Equal(monthly.WorkDays, m.WorkDays);
            breaks += monthly.TotalBreaksMs;
        }
        Assert.Equal(breaks, s.TotalBreaksMs);
        Assert.True(s.TotalBreaksMs > 0);
    }

    [Fact]
    public void Summary_LeaveCounts_MatchYearlyLeave_PlusHoliday()
    {
        var entries = MixedYear(2026);
        var s = Summary(entries, 2026);
        var leave = ReportCalculator.CalculateYearlyLeave(entries, 2026, Settings);

        Assert.Equal(leave.VacationDaysTaken, s.VacationDays);
        Assert.Equal(leave.SickDays, s.SickDays);
        Assert.Equal(entries.Count(e => e.Type == "holiday"), s.HolidayDays);
        Assert.True(s.VacationDays > 0 && s.SickDays > 0 && s.HolidayDays > 0);
    }

    [Fact]
    public void Summary_AbsencesAndManualOvertime()
    {
        // 40 h an Mo–Fr: Tagessoll 8 h.
        var sat = new DateOnly(2026, 2, 7);
        Assert.Equal(DayOfWeek.Saturday, sat.DayOfWeek);
        var entries = new[]
        {
            Leave(2026, 2, 7, "holiday"),                       // freier Tag: 8 h geleistet, 8 h Soll (#535)
            Leave(2026, 2, 8, "vacation"),                      // Sonntag, ebenso
            Leave(2026, 2, 9, "sick", manualMinutes: 30),       // Mo, +30 min manuell
            Work(2026, 2, 10, 8, 17, breakMinutes: 60, manualMinutes: -15), // netto 8 h, −15 min
            Work(2026, 2, 14, 8, 12),                           // Samstag-Arbeit: alles Überstunden
        };
        var s = Summary(entries, 2026);
        var feb = s.Months[1];

        Assert.Equal(8 * H * 4 + 4 * H, feb.WorkedMs);
        Assert.Equal(30 * Min - 15 * Min + 4 * H, feb.OvertimeMs);
        Assert.Equal(5, feb.WorkDays);
        Assert.Equal(1 * H, s.TotalBreaksMs);
        Assert.Equal(1, s.VacationDays);
        Assert.Equal(1, s.SickDays);
        Assert.Equal(1, s.HolidayDays);
    }

    [Fact]
    public void Summary_StoredBalanceIsNotAnInput()
    {
        // Die Signatur kennt keinen Saldo; Überstunden = Summe der Monate (inkl. manueller), sonst nichts.
        var entries = new[] { Work(2026, 1, 5, 8, 17), Work(2026, 6, 1, 8, 15, manualMinutes: 10) };
        var s = Summary(entries, 2026);
        var jan = ReportCalculator.CalculateMonthlyReport(
            entries.Take(1).ToList(), new DateOnly(2026, 1, 1), Settings, storedOvertimeMs: 500 * H);

        Assert.Equal(1 * H, s.Months[0].OvertimeMs);
        Assert.Equal(jan.MonthlyOvertimeMs, s.Months[0].OvertimeMs);
        Assert.Equal(-1 * H + 10 * Min, s.Months[5].OvertimeMs);
        Assert.Equal(10 * Min, s.OvertimeMs);
    }

    // ── until ─────────────────────────────────────────────────────────────

    [Fact]
    public void Until_CutsBothYearsByMonthAndDay()
    {
        var until = new MonthDay(3, 15);
        var current = new[]
        {
            Work(2026, 1, 5, 8, 16),
            Work(2026, 3, 15, 8, 16), // Stichtag zählt (So, freier Tag)
            Work(2026, 3, 16, 8, 16), // Tag danach nicht
            Work(2026, 7, 1, 8, 16),
        };
        var previous = new[]
        {
            Work(2025, 3, 14, 8, 16),
            Work(2025, 3, 15, 8, 16), // Stichtag (Sa)
            Work(2025, 3, 16, 8, 16), // Tag danach
            Work(2025, 12, 1, 8, 16),
        };
        var c = Compare(current, previous, 2026, until);

        Assert.Equal("03-15", c.Until);
        Assert.Equal(16 * H, c.Current.TotalWorkedMs);
        Assert.Equal(8 * H, c.Current.Months[2].WorkedMs);
        Assert.Equal(16 * H, c.Previous.TotalWorkedMs);
        Assert.Equal(16 * H, c.Previous.Months[2].WorkedMs);
        foreach (var s in new[] { c.Current, c.Previous })
        {
            Assert.All(s.Months.Skip(3), m => Assert.Equal((0L, 0L, 0), (m.WorkedMs, m.OvertimeMs, m.WorkDays)));
            Assert.Equal(2, s.WorkDays);
        }
    }

    [Fact]
    public void Until_CutsLeaveCounts()
    {
        var until = new MonthDay(6, 30);
        var entries = new[]
        {
            Leave(2026, 6, 30, "vacation"), Leave(2026, 7, 1, "vacation"),
            Leave(2026, 6, 29, "sick"), Leave(2026, 8, 3, "sick"),
            Leave(2026, 1, 1, "holiday"), Leave(2026, 12, 25, "holiday"),
        };
        var s = Summary(entries, 2026, until);
        Assert.Equal((1, 1, 1), (s.VacationDays, s.SickDays, s.HolidayDays));
    }

    [Fact]
    public void Until_NoEntryUpToCutoff_HasDataFalse()
    {
        var s = Summary(new[] { Work(2026, 5, 4, 8, 16) }, 2026, new MonthDay(5, 3));
        Assert.False(s.HasData);
        Assert.Equal(0, s.TotalWorkedMs);
    }

    [Fact]
    public void Until_Null_CountsWholeYear_AndUntilIsNull()
    {
        var c = Compare(new[] { Work(2026, 12, 31, 8, 16) }, new[] { Work(2025, 12, 31, 8, 16) }, 2026);
        Assert.Null(c.Until);
        Assert.Equal(8 * H, c.Current.TotalWorkedMs);
        Assert.Equal(8 * H, c.Previous.TotalWorkedMs);
    }

    [Fact]
    public void Until_0229_CurrentLeapYear_PreviousNot()
    {
        var until = new MonthDay(2, 29);
        var current = new[] { Work(2028, 2, 29, 8, 16), Work(2028, 3, 1, 8, 16) };
        var previous = new[] { Work(2027, 2, 28, 8, 16), Work(2027, 3, 1, 8, 16) };
        var c = Compare(current, previous, 2028, until);

        Assert.Equal("02-29", c.Until);
        Assert.Equal(8 * H, c.Current.TotalWorkedMs);
        Assert.Equal(8 * H, c.Previous.TotalWorkedMs);
        Assert.Equal(0, c.Current.Months[2].WorkedMs);
        Assert.Equal(0, c.Previous.Months[2].WorkedMs);
    }

    [Fact]
    public void Until_0229_PreviousLeapYear_CurrentNot()
    {
        var until = new MonthDay(2, 29);
        var current = new[] { Work(2029, 2, 28, 8, 16), Work(2029, 3, 1, 8, 16) };
        var previous = new[] { Work(2028, 2, 28, 8, 16), Work(2028, 2, 29, 8, 16), Work(2028, 3, 1, 8, 16) };
        var c = Compare(current, previous, 2029, until);

        Assert.Equal(8 * H, c.Current.TotalWorkedMs);
        Assert.Equal(16 * H, c.Previous.TotalWorkedMs);
        Assert.Equal(-8 * H, c.Delta!.WorkedMs);
    }

    [Fact]
    public void Until_0228_InLeapYear_Excludes0229()
    {
        var s = Summary(new[] { Work(2028, 2, 28, 8, 16), Work(2028, 2, 29, 8, 16) }, 2028, new MonthDay(2, 28));
        Assert.Equal(8 * H, s.TotalWorkedMs);
    }

    [Theory]
    [InlineData(2026, null, 2026, 12, 31)]
    [InlineData(2026, "03-15", 2026, 3, 15)]
    [InlineData(2028, "02-29", 2028, 2, 29)]
    [InlineData(2027, "02-29", 2027, 2, 28)]
    public void YearlyCutoffDate(int year, string? until, int y, int m, int d)
    {
        Assert.True(ReportEndpoints.TryParseUntil(until, out var parsed));
        Assert.Equal(new DateOnly(y, m, d), ReportCalculator.YearlyCutoffDate(year, parsed));
    }

    // ── delta und workedPercent ───────────────────────────────────────────

    /// <summary>Von Hand nachgerechnetes Beispiel (siehe Bericht zu #530): 40 h an Mo–Fr, Stichtag 15.03.</summary>
    [Fact]
    public void HandCalculatedExample()
    {
        var until = new MonthDay(3, 15);
        var current = new[]
        {
            Work(2026, 1, 5, 8, 17, breakMinutes: 60),  // Mo: netto 8 h, ±0
            Work(2026, 2, 2, 8, 18, breakMinutes: 30),  // Mo: netto 9,5 h, +1,5 h
            Leave(2026, 2, 7, "vacation"),              // Sa: 8 h, ±0 (#535)
            Leave(2026, 3, 13, "sick"),                 // Fr: 8 h, ±0
            Work(2026, 3, 16, 8, 16),                   // nach dem Stichtag
        };
        var previous = new[]
        {
            Leave(2025, 1, 1, "holiday"),               // Mi: 8 h, ±0
            Work(2025, 1, 6, 8, 16),                    // Mo: 8 h, ±0
            Work(2025, 3, 14, 8, 15, manualMinutes: 30), // Fr: 7 h, −1 h + 0,5 h
            Work(2025, 3, 17, 8, 20),                   // nach dem Stichtag
        };
        var c = Compare(current, previous, 2026, until);

        Assert.True(c.Current.HasData);
        Assert.Equal((long)(33.5 * H), c.Current.TotalWorkedMs);
        Assert.Equal((long)(1.5 * H), c.Current.TotalBreaksMs);
        Assert.Equal((long)(1.5 * H), c.Current.OvertimeMs);
        Assert.Equal((4, 1, 1, 0), (c.Current.WorkDays, c.Current.VacationDays, c.Current.SickDays, c.Current.HolidayDays));
        Assert.Equal(new long[] { 8 * H, 17 * H + 30 * Min, 8 * H }, c.Current.Months.Take(3).Select(m => m.WorkedMs));

        Assert.Equal(23 * H, c.Previous.TotalWorkedMs);
        Assert.Equal(0, c.Previous.TotalBreaksMs);
        Assert.Equal(-30 * Min, c.Previous.OvertimeMs);
        Assert.Equal((3, 0, 0, 1), (c.Previous.WorkDays, c.Previous.VacationDays, c.Previous.SickDays, c.Previous.HolidayDays));

        var d = c.Delta!;
        Assert.Equal((long)(10.5 * H), d.WorkedMs);
        Assert.Equal(45.7, d.WorkedPercent); // 10,5 / 23 = 45,652 %
        Assert.Equal(2 * H, d.OvertimeMs);
        Assert.Equal((1, 1, 1, -1), (d.WorkDays, d.VacationDays, d.SickDays, d.HolidayDays));
    }

    [Fact]
    public void PreviousEmpty_DeltaNull()
    {
        var c = Compare(new[] { Work(2026, 1, 5, 8, 16) }, Array.Empty<WorkEntryDto>(), 2026);
        Assert.False(c.Previous.HasData);
        Assert.Equal(2025, c.Previous.Year);
        Assert.Null(c.Delta);
    }

    [Fact]
    public void CurrentEmpty_PreviousWithData_DeltaNegative()
    {
        var c = Compare(
            Array.Empty<WorkEntryDto>(),
            new[] { Work(2025, 1, 6, 8, 17), Leave(2025, 2, 3, "vacation"), Leave(2025, 2, 4, "sick") },
            2026);

        Assert.False(c.Current.HasData);
        var d = c.Delta!;
        Assert.Equal(-25 * H, d.WorkedMs);
        Assert.Equal(-100.0, d.WorkedPercent);
        Assert.Equal(-1 * H, d.OvertimeMs);
        Assert.Equal((-3, -1, -1, 0), (d.WorkDays, d.VacationDays, d.SickDays, d.HolidayDays));
    }

    [Fact]
    public void PreviousWorkedZeroButHasData_PercentNull_RestSet()
    {
        var c = Compare(
            new[] { Work(2026, 1, 5, 8, 16), Leave(2026, 1, 6, "holiday") },
            new[] { Open(2025, 1, 6, 8) },
            2026);

        Assert.True(c.Previous.HasData);
        Assert.Equal(0, c.Previous.TotalWorkedMs);
        var d = c.Delta!;
        Assert.Null(d.WorkedPercent);
        Assert.Equal(16 * H, d.WorkedMs);
        Assert.Equal(1, d.WorkDays);
        Assert.Equal(1, d.HolidayDays);
        Assert.Equal(c.Current.OvertimeMs - c.Previous.OvertimeMs, d.OvertimeMs);
    }

    [Theory]
    [InlineData(112_350, 100_000, 12.4)]   // +12,35 % → 12,4 (kaufmännisch)
    [InlineData(112_340, 100_000, 12.3)]
    [InlineData(87_650, 100_000, -12.4)]   // −12,35 % → −12,4 (von der Null weg)
    [InlineData(87_660, 100_000, -12.3)]
    [InlineData(100_000, 100_000, 0.0)]
    [InlineData(200_000, 100_000, 100.0)]
    [InlineData(100_000, 300_000, -66.7)]
    public void WorkedPercent_RoundsToOneDecimalAwayFromZero(long currentMs, long previousMs, double expected)
    {
        var c = Compare(new[] { WorkMs(2026, 1, 5, currentMs) }, new[] { WorkMs(2025, 1, 6, previousMs) }, 2026);
        Assert.Equal(expected, c.Delta!.WorkedPercent);
    }

    [Fact]
    public void Delta_IsCurrentMinusPrevious_ForEveryField()
    {
        var c = Compare(MixedYear(2026), MixedYear(2025).Where(e => e.Date.Month <= 9).ToList(), 2026, settings: OddSettings);
        var d = c.Delta!;
        Assert.Equal(c.Current.TotalWorkedMs - c.Previous.TotalWorkedMs, d.WorkedMs);
        Assert.Equal(c.Current.OvertimeMs - c.Previous.OvertimeMs, d.OvertimeMs);
        Assert.Equal(c.Current.WorkDays - c.Previous.WorkDays, d.WorkDays);
        Assert.Equal(c.Current.VacationDays - c.Previous.VacationDays, d.VacationDays);
        Assert.Equal(c.Current.SickDays - c.Previous.SickDays, d.SickDays);
        Assert.Equal(c.Current.HolidayDays - c.Previous.HolidayDays, d.HolidayDays);
        Assert.NotNull(d.WorkedPercent);
    }

    // ── until-Parser ──────────────────────────────────────────────────────

    [Theory]
    [InlineData("01-01", 1, 1)]
    [InlineData("11-14", 11, 14)]
    [InlineData("12-31", 12, 31)]
    [InlineData("02-29", 2, 29)]
    [InlineData("04-30", 4, 30)]
    public void TryParseUntil_Valid(string value, int month, int day)
    {
        Assert.True(ReportEndpoints.TryParseUntil(value, out var until));
        Assert.Equal(new MonthDay(month, day), until);
        Assert.Equal(value, until!.Value.ToString());
    }

    [Fact]
    public void TryParseUntil_Missing_IsValidAndNull()
    {
        Assert.True(ReportEndpoints.TryParseUntil(null, out var until));
        Assert.Null(until);
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData("02-30")]
    [InlineData("02-31")]
    [InlineData("04-31")]
    [InlineData("13-01")]
    [InlineData("00-10")]
    [InlineData("01-00")]
    [InlineData("1-5")]
    [InlineData("01-5")]
    [InlineData("1-05")]
    [InlineData("01/05")]
    [InlineData("0105")]
    [InlineData("01-05 ")]
    [InlineData(" 01-05")]
    [InlineData("2026-01-05")]
    [InlineData("+1-05")]
    [InlineData("٠١-٠٥")] // arabisch-indische Ziffern
    [InlineData("ab-cd")]
    public void TryParseUntil_Invalid(string value)
    {
        Assert.False(ReportEndpoints.TryParseUntil(value, out _));
    }
}
