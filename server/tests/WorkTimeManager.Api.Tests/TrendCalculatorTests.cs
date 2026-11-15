using System.Globalization;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Domain;
using WorkTimeManager.Api.Endpoints;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Tests;

/// <summary>Trend über 12 Wochen/Monate und Kennzahl „Wochen-Trend“ (#531). Alle Bezugstage fest.</summary>
public class TrendCalculatorTests
{
    private static readonly SettingsDto Settings = new() { WeeklyTargetHours = 40, Workdays = new[] { 1, 2, 3, 4, 5 } };
    private const long H = 3_600_000L;

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

    private static WorkEntryDto Leave(int y, int m, int d, string type) => new()
    {
        Id = $"{y:D4}-{m:D2}-{d:D2}",
        Date = new DateTimeOffset(y, m, d, 0, 0, 0, TimeSpan.Zero),
        Type = type,
    };

    private static WorkEntryDto Open(int y, int m, int d, int startHour) => new()
    {
        Id = $"{y:D4}-{m:D2}-{d:D2}",
        Date = new DateTimeOffset(y, m, d, 0, 0, 0, TimeSpan.Zero),
        WorkStart = new DateTimeOffset(y, m, d, startHour, 0, 0, TimeSpan.Zero),
        Type = "work",
    };

    private static DateTimeOffset Utc(int y, int m, int d) => new(y, m, d, 0, 0, 0, TimeSpan.Zero);

    private static DateOnly Day(DateTimeOffset d) => new(d.Year, d.Month, d.Day);

    // ── Buckets: Anzahl, Reihenfolge, Schlüssel ────────────────────────────

    [Fact]
    public void Week_Always12Buckets_OldestFirst_LastContainsReference()
    {
        var trend = ReportCalculator.CalculateTrend(
            Array.Empty<WorkEntryDto>(), new DateOnly(2026, 11, 14), TrendGranularity.Week, Settings, storedOvertimeMs: 0);

        Assert.Equal("week", trend.Granularity);
        Assert.Equal(12, trend.Buckets.Count);
        Assert.Equal("2026-W35", trend.Buckets[0].Key);
        Assert.Equal(Utc(2026, 8, 24), trend.Buckets[0].Start);
        Assert.Equal("2026-W46", trend.Buckets[11].Key);
        Assert.Equal(Utc(2026, 11, 9), trend.Buckets[11].Start);
        Assert.Equal(Utc(2026, 11, 15), trend.Buckets[11].End);
        for (var i = 0; i < 12; i++)
        {
            var b = trend.Buckets[i];
            Assert.Equal(DayOfWeek.Monday, b.Start.DayOfWeek);
            Assert.Equal(b.Start.AddDays(6), b.End);
            Assert.Equal(TimeSpan.Zero, b.Start.Offset);
            Assert.False(b.HasData);
            if (i > 0) Assert.Equal(trend.Buckets[i - 1].Start.AddDays(7), b.Start);
            var monday = b.Start.UtcDateTime;
            Assert.Equal($"{ISOWeek.GetYear(monday):D4}-W{ISOWeek.GetWeekOfYear(monday):D2}", b.Key);
        }
    }

    [Fact]
    public void Month_Always12Buckets_OldestFirst_LastContainsReference()
    {
        var trend = ReportCalculator.CalculateTrend(
            Array.Empty<WorkEntryDto>(), new DateOnly(2026, 11, 14), TrendGranularity.Month, Settings, storedOvertimeMs: 0);

        Assert.Equal("month", trend.Granularity);
        Assert.Equal(12, trend.Buckets.Count);
        Assert.Equal(
            new[] { "2025-12", "2026-01", "2026-02", "2026-03", "2026-04", "2026-05",
                    "2026-06", "2026-07", "2026-08", "2026-09", "2026-10", "2026-11" },
            trend.Buckets.Select(b => b.Key));
        Assert.Equal(Utc(2025, 12, 1), trend.Buckets[0].Start);
        Assert.Equal(Utc(2025, 12, 31), trend.Buckets[0].End);
        Assert.Equal(Utc(2026, 2, 28), trend.Buckets[2].End);
        Assert.Equal(Utc(2026, 11, 1), trend.Buckets[11].Start);
        Assert.Equal(Utc(2026, 11, 30), trend.Buckets[11].End);
    }

    [Fact]
    public void Week_YearBoundary_2026Has53Weeks()
    {
        // Mi 06.01.2027 liegt in 2027-W01 (Mo 04.01.2027); 2026 hat eine KW 53 (Mo 28.12.2026 – So 03.01.2027).
        var trend = ReportCalculator.CalculateTrend(
            Array.Empty<WorkEntryDto>(), new DateOnly(2027, 1, 6), TrendGranularity.Week, Settings, storedOvertimeMs: 0);

        Assert.Equal(
            new[] { "2026-W51", "2026-W52", "2026-W53", "2027-W01" },
            trend.Buckets.Skip(8).Select(b => b.Key));
        Assert.Equal(Utc(2026, 12, 28), trend.Buckets[10].Start);
        Assert.Equal(Utc(2027, 1, 3), trend.Buckets[10].End);
    }

    [Fact]
    public void Week_YearBoundary_ReferenceMonday_2025To2026()
    {
        // Mo 29.12.2025 gehört zu 2026-W01; die Woche davor ist 2025-W52.
        var trend = ReportCalculator.CalculateTrend(
            Array.Empty<WorkEntryDto>(), new DateOnly(2025, 12, 29), TrendGranularity.Week, Settings, storedOvertimeMs: 0);

        Assert.Equal("2026-W01", trend.Buckets[11].Key);
        Assert.Equal(Utc(2025, 12, 29), trend.Buckets[11].Start);
        Assert.Equal(Utc(2026, 1, 4), trend.Buckets[11].End);
        Assert.Equal("2025-W52", trend.Buckets[10].Key);
    }

    [Fact]
    public void Month_YearBoundary()
    {
        var trend = ReportCalculator.CalculateTrend(
            Array.Empty<WorkEntryDto>(), new DateOnly(2027, 2, 10), TrendGranularity.Month, Settings, storedOvertimeMs: 0);

        Assert.Equal("2026-03", trend.Buckets[0].Key);
        Assert.Equal("2026-12", trend.Buckets[9].Key);
        Assert.Equal("2027-01", trend.Buckets[10].Key);
        Assert.Equal("2027-02", trend.Buckets[11].Key);
        Assert.Equal(Utc(2027, 2, 28), trend.Buckets[11].End);
    }

    [Fact]
    public void Week_SpanningMonthBoundary_SumsBothMonths()
    {
        // Woche Mo 30.03.2026 – So 05.04.2026.
        var entries = new[] { Work(2026, 3, 31, 8, 16), Work(2026, 4, 1, 8, 18) };
        var trend = ReportCalculator.CalculateTrend(entries, new DateOnly(2026, 4, 1), TrendGranularity.Week, Settings, storedOvertimeMs: 0);

        var last = trend.Buckets[11];
        Assert.Equal("2026-W14", last.Key);
        Assert.True(last.HasData);
        Assert.Equal(18 * H, last.WorkedMs);
        Assert.Equal(16 * H, last.TargetMs);
        Assert.Equal(2 * H, last.OvertimeMs);
    }

    [Fact]
    public void Week_ReferenceSunday_IncludesSundayEntry()
    {
        // So 15.11.2026 ist der letzte Tag von 2026-W46; Sonntag ist kein Vertrags-Wochentag (Soll 0).
        var trend = ReportCalculator.CalculateTrend(
            new[] { Work(2026, 11, 15, 10, 12) }, new DateOnly(2026, 11, 15), TrendGranularity.Week, Settings, storedOvertimeMs: 0);

        var last = trend.Buckets[11];
        Assert.Equal("2026-W46", last.Key);
        Assert.Equal(2 * H, last.WorkedMs);
        Assert.Equal(0, last.TargetMs);
        Assert.Equal(2 * H, last.OvertimeMs);
    }

    // ── Lücken, kumulierte und negative Überstunden ─────────────────────────

    [Fact]
    public void Week_Gaps_CumulativeRunsAcross_NegativeOvertime()
    {
        var entries = new[]
        {
            Work(2026, 10, 26, 8, 18), // W44: 10 h → +2 h
            Work(2026, 11, 9, 8, 14),  // W46: 6 h → −2 h
            Work(2026, 11, 10, 8, 15), // W46: 7 h → −1 h
        };
        var trend = ReportCalculator.CalculateTrend(entries, new DateOnly(2026, 11, 13), TrendGranularity.Week, Settings, storedOvertimeMs: 0);

        for (var i = 0; i < 9; i++)
        {
            Assert.False(trend.Buckets[i].HasData);
            Assert.Equal(0, trend.Buckets[i].WorkedMs);
            Assert.Equal(0, trend.Buckets[i].TargetMs);
            Assert.Equal(0, trend.Buckets[i].OvertimeMs);
            Assert.Equal(0, trend.Buckets[i].CumulativeOvertimeMs);
        }

        Assert.Equal("2026-W44", trend.Buckets[9].Key);
        Assert.True(trend.Buckets[9].HasData);
        Assert.Equal(2 * H, trend.Buckets[9].OvertimeMs);
        Assert.Equal(2 * H, trend.Buckets[9].CumulativeOvertimeMs);

        Assert.False(trend.Buckets[10].HasData);
        Assert.Equal(0, trend.Buckets[10].OvertimeMs);
        Assert.Equal(2 * H, trend.Buckets[10].CumulativeOvertimeMs);

        Assert.Equal(13 * H, trend.Buckets[11].WorkedMs);
        Assert.Equal(16 * H, trend.Buckets[11].TargetMs);
        Assert.Equal(-3 * H, trend.Buckets[11].OvertimeMs);
        Assert.Equal(-1 * H, trend.Buckets[11].CumulativeOvertimeMs);
    }

    [Fact]
    public void Month_NetWork_Target_Overtime_Cumulative()
    {
        var entries = new[]
        {
            Work(2026, 10, 30, 8, 12),                   // Okt: 4 h → −4 h
            Work(2026, 11, 2, 8, 17, breakMinutes: 30),  // Nov: 8,5 h netto
            Leave(2026, 11, 3, "vacation"),              // Nov: 8 h (Tagessoll)
        };
        var trend = ReportCalculator.CalculateTrend(entries, new DateOnly(2026, 11, 14), TrendGranularity.Month, Settings, storedOvertimeMs: 0);

        var oct = trend.Buckets[10];
        Assert.Equal("2026-10", oct.Key);
        Assert.Equal(4 * H, oct.WorkedMs);
        Assert.Equal(8 * H, oct.TargetMs);
        Assert.Equal(-4 * H, oct.OvertimeMs);
        Assert.Equal(-4 * H, oct.CumulativeOvertimeMs);

        var nov = trend.Buckets[11];
        Assert.Equal((long)(16.5 * H), nov.WorkedMs);
        Assert.Equal(16 * H, nov.TargetMs);
        Assert.Equal(H / 2, nov.OvertimeMs);
        Assert.Equal((long)(-3.5 * H), nov.CumulativeOvertimeMs);
        Assert.False(trend.Buckets[9].HasData);
    }

    [Fact]
    public void Week_LeaveTypes_ManualOvertime_OpenEntry()
    {
        var entries = new[]
        {
            Leave(2026, 11, 9, "vacation"),
            Leave(2026, 11, 10, "sick"),
            Leave(2026, 11, 11, "holiday"),
            Work(2026, 11, 12, 8, 16, manualMinutes: 30),
            Open(2026, 11, 13, 8), // ohne Ende: 0 h, Soll zählt
        };
        var reference = new DateOnly(2026, 11, 13);
        var trend = ReportCalculator.CalculateTrend(entries, reference, TrendGranularity.Week, Settings, storedOvertimeMs: 0);
        var weekly = ReportCalculator.CalculateWeeklyReport(entries, reference, Settings);

        var last = trend.Buckets[11];
        Assert.Equal(32 * H, last.WorkedMs);
        Assert.Equal(40 * H, last.TargetMs);
        Assert.Equal((long)(-7.5 * H), last.OvertimeMs);
        Assert.Equal(weekly.OvertimeMs, last.OvertimeMs);
        Assert.Equal(weekly.TotalWorkedMs - weekly.TotalBreaksMs, last.WorkedMs);
    }

    // ── Parität mit Wochen- und Monatsbericht ──────────────────────────────

    /// <summary>
    /// Gemischte, deterministische Einträge Jun 2026 – Jan 2027 mit Lücken (u. a. ganze KW 50), Pausen, Urlaub,
    /// Krank, Feiertag, offenen Einträgen, Wochenenden und manuellen Überstunden.
    /// </summary>
    private static List<WorkEntryDto> MixedEntries()
    {
        var list = new List<WorkEntryDto>();
        var i = 0;
        for (var d = new DateOnly(2026, 6, 1); d <= new DateOnly(2027, 1, 31); d = d.AddDays(1), i++)
        {
            if (i % 6 == 0 || (d >= new DateOnly(2026, 12, 7) && d <= new DateOnly(2026, 12, 13))) continue;
            if (i % 11 == 0) list.Add(Leave(d.Year, d.Month, d.Day, "vacation"));
            else if (i % 13 == 0) list.Add(Leave(d.Year, d.Month, d.Day, "sick"));
            else if (i % 17 == 0) list.Add(Leave(d.Year, d.Month, d.Day, "holiday"));
            else if (i % 19 == 0) list.Add(Open(d.Year, d.Month, d.Day, 9));
            else list.Add(Work(d.Year, d.Month, d.Day, 7 + i % 3, 14 + i % 5,
                breakMinutes: i % 2 == 0 ? 45 : 0, manualMinutes: i % 9 == 0 ? -20 : null));
        }
        return list;
    }

    private static readonly SettingsDto OddSettings = new() { WeeklyTargetHours = 39, Workdays = new[] { 1, 2, 3, 4, 6 } };

    [Fact]
    public void Parity_WeekBuckets_MatchWeeklyReport()
    {
        var entries = MixedEntries();
        var trend = ReportCalculator.CalculateTrend(entries, new DateOnly(2027, 1, 20), TrendGranularity.Week, OddSettings, storedOvertimeMs: 0);

        Assert.Contains(trend.Buckets, b => !b.HasData); // KW 50 (07.–13.12.2026) ist leer
        foreach (var b in trend.Buckets)
        {
            var weekly = ReportCalculator.CalculateWeeklyReport(entries, Day(b.Start), OddSettings);
            Assert.Equal(weekly.OvertimeMs, b.OvertimeMs);
            Assert.Equal(weekly.TotalWorkedMs - weekly.TotalBreaksMs, b.WorkedMs);
            Assert.Equal(weekly.Start, b.Start);
            Assert.Equal(weekly.End, b.End);
            Assert.Equal(weekly.Days.Count > 0, b.HasData);
        }
    }

    [Fact]
    public void Parity_MonthBuckets_MatchMonthlyReport_WithoutStoredBalance()
    {
        var entries = MixedEntries();
        var trend = ReportCalculator.CalculateTrend(entries, new DateOnly(2027, 1, 20), TrendGranularity.Month, OddSettings, storedOvertimeMs: 0);

        long cumulative = 0;
        foreach (var b in trend.Buckets)
        {
            var first = Day(b.Start);
            var monthEntries = entries.Where(e => e.Date.Year == first.Year && e.Date.Month == first.Month).ToList();
            var monthly = ReportCalculator.CalculateMonthlyReport(monthEntries, first, OddSettings, storedOvertimeMs: 99 * H);
            Assert.Equal(monthly.MonthlyOvertimeMs, b.OvertimeMs);
            Assert.Equal(monthly.TotalWorkedMs - monthly.TotalBreaksMs, b.WorkedMs);
            Assert.Equal(monthEntries.Count > 0, b.HasData);
            cumulative += b.OvertimeMs;
            Assert.Equal(cumulative, b.CumulativeOvertimeMs);
        }
    }

    // ── Wochen-Trend ───────────────────────────────────────────────────────

    /// <summary>Bezugstag Mi 11.11.2026 (W46): letzte Woche W45 (02.11.), Vergleich W44, W43, W42, W41.</summary>
    private static readonly DateOnly TrendRef = new(2026, 11, 11);

    [Fact]
    public void WeeklyTrend_Normal()
    {
        var entries = new[]
        {
            Work(2026, 9, 28, 6, 18),                   // W40: außerhalb der Vergleichswochen
            Work(2026, 10, 5, 8, 15),                   // W41: 7 h
            Work(2026, 10, 12, 8, 14),                  // W42: 6 h
            Work(2026, 10, 19, 8, 18),                  // W43: 10 h
            Work(2026, 10, 26, 8, 16),                  // W44: 8 h
            Work(2026, 11, 2, 8, 17, breakMinutes: 30), // W45: 8,5 h netto
            Work(2026, 11, 3, 8, 16),                   // W45: 8 h
            Work(2026, 11, 9, 6, 20),                   // W46: laufende Woche, zählt nicht
        };
        var t = ReportCalculator.CalculateTrend(entries, TrendRef, TrendGranularity.Week, Settings, storedOvertimeMs: 0).WeeklyTrend;

        Assert.NotNull(t);
        Assert.Equal("2026-W45", t.LastWeekKey);
        Assert.Equal((long)(16.5 * H), t.LastWeekWorkedMs);
        Assert.Equal((long)(7.75 * H), t.AverageWorkedMs);
        Assert.Equal((long)(8.75 * H), t.DeltaMs);
        Assert.Equal(4, t.ComparedWeeks);
    }

    [Fact]
    public void WeeklyTrend_ComparisonGaps_AreNotCounted()
    {
        var entries = new[]
        {
            Work(2026, 10, 5, 8, 15),  // W41: 7 h
            Work(2026, 10, 12, 8, 14), // W42: 6 h
            Work(2026, 10, 26, 8, 16), // W44: 8 h  (W43 leer)
            Work(2026, 11, 2, 8, 16),  // W45: 8 h
        };
        var t = ReportCalculator.CalculateTrend(entries, TrendRef, TrendGranularity.Week, Settings, storedOvertimeMs: 0).WeeklyTrend;

        Assert.NotNull(t);
        Assert.Equal(3, t.ComparedWeeks);
        Assert.Equal(7 * H, t.AverageWorkedMs);
        Assert.Equal(1 * H, t.DeltaMs);
    }

    [Fact]
    public void WeeklyTrend_ExactlyTwoComparisonWeeks_RoundsHalfAwayFromZero()
    {
        var entries = new[]
        {
            WorkMs(2026, 10, 12, 8 * H),     // W42
            WorkMs(2026, 10, 26, 8 * H + 1), // W44
            WorkMs(2026, 11, 2, 9 * H),      // W45
        };
        var t = ReportCalculator.CalculateTrend(entries, TrendRef, TrendGranularity.Week, Settings, storedOvertimeMs: 0).WeeklyTrend;

        Assert.NotNull(t);
        Assert.Equal(2, t.ComparedWeeks);
        Assert.Equal(8 * H + 1, t.AverageWorkedMs); // 8 h + 0,5 ms → aufgerundet
        Assert.Equal(H - 1, t.DeltaMs);
    }

    [Fact]
    public void WeeklyTrend_RoundsToNearestMillisecond()
    {
        var entries = new[]
        {
            WorkMs(2026, 10, 12, 8 * H),
            WorkMs(2026, 10, 19, 8 * H),
            WorkMs(2026, 10, 26, 8 * H + 1), // Mittel 8 h + 0,33 ms → 8 h
            WorkMs(2026, 11, 2, 8 * H),
        };
        var t = ReportCalculator.CalculateTrend(entries, TrendRef, TrendGranularity.Week, Settings, storedOvertimeMs: 0).WeeklyTrend;

        Assert.NotNull(t);
        Assert.Equal(8 * H, t.AverageWorkedMs);
        Assert.Equal(0, t.DeltaMs);
    }

    [Fact]
    public void WeeklyTrend_OnlyOneComparisonWeek_IsNull()
    {
        var entries = new[] { Work(2026, 10, 26, 8, 16), Work(2026, 11, 2, 8, 16) };
        Assert.Null(ReportCalculator.CalculateTrend(entries, TrendRef, TrendGranularity.Week, Settings, storedOvertimeMs: 0).WeeklyTrend);
    }

    [Fact]
    public void WeeklyTrend_LastWeekEmpty_IsNull()
    {
        var entries = new[]
        {
            Work(2026, 10, 5, 8, 15), Work(2026, 10, 12, 8, 14),
            Work(2026, 10, 19, 8, 18), Work(2026, 10, 26, 8, 16),
            Work(2026, 11, 9, 8, 16), // nur laufende Woche
        };
        Assert.Null(ReportCalculator.CalculateTrend(entries, TrendRef, TrendGranularity.Week, Settings, storedOvertimeMs: 0).WeeklyTrend);
    }

    [Fact]
    public void WeeklyTrend_IdenticalForWeekAndMonth()
    {
        var entries = MixedEntries();
        foreach (var reference in new[] { new DateOnly(2026, 11, 11), new DateOnly(2027, 1, 4), new DateOnly(2026, 9, 30) })
        {
            var week = ReportCalculator.CalculateTrend(entries, reference, TrendGranularity.Week, OddSettings, storedOvertimeMs: 0).WeeklyTrend;
            var month = ReportCalculator.CalculateTrend(entries, reference, TrendGranularity.Month, OddSettings, storedOvertimeMs: 0).WeeklyTrend;
            Assert.NotNull(week);
            Assert.Equal(week, month);
        }
    }

    [Fact]
    public void WeeklyTrend_LastWeekAcrossYearBoundary_UsesIsoWeekYear()
    {
        // Bezugstag Mo 04.01.2027 (2027-W01): letzte Woche 2026-W53.
        var entries = new[]
        {
            Work(2026, 12, 14, 8, 16), Work(2026, 12, 21, 8, 16), Work(2026, 12, 30, 8, 17),
        };
        var t = ReportCalculator.CalculateTrend(entries, new DateOnly(2027, 1, 4), TrendGranularity.Month, Settings, storedOvertimeMs: 0).WeeklyTrend;

        Assert.NotNull(t);
        Assert.Equal("2026-W53", t.LastWeekKey);
        Assert.Equal(9 * H, t.LastWeekWorkedMs);
        Assert.Equal(2, t.ComparedWeeks);
        Assert.Equal(8 * H, t.AverageWorkedMs);
    }

    // ── Überstunden-Prognose (#532) ────────────────────────────────────────

    /// <summary>Bezugstag Sa 14.11.2026 (W46, Mo 09.11.): Fenster W38–W45, 47 Tage bis 31.12.</summary>
    private static readonly DateOnly ForecastRef = new(2026, 11, 14);

    private static OvertimeForecastDto? Forecast(
        IReadOnlyList<WorkEntryDto> entries, DateOnly reference, long storedMs = 0, SettingsDto? settings = null) =>
        ReportCalculator.CalculateTrend(entries, reference, TrendGranularity.Week, settings ?? Settings, storedMs).Forecast;

    /// <summary>Je ein Montag mit 8 h + <paramref name="overtimeMs"/> (Tagessoll 8 h) in den angegebenen Wochen.</summary>
    private static List<WorkEntryDto> MondaysWithOvertime(DateOnly firstMonday, params long[] overtimeMs) =>
        overtimeMs.Select((o, i) =>
        {
            var d = firstMonday.AddDays(7 * i);
            return WorkMs(d.Year, d.Month, d.Day, 8 * H + o);
        }).ToList();

    [Fact]
    public void Forecast_Normal_EightWeeks_HandCalculated()
    {
        var entries = new List<WorkEntryDto>
        {
            Work(2026, 9, 7, 8, 20),    // W37: vor dem Fenster, zählt nicht
            Work(2026, 9, 14, 8, 17),   // W38: +1 h
            Work(2026, 9, 21, 8, 18),   // W39: +2 h
            Work(2026, 9, 28, 8, 16),   // W40:  0
            Work(2026, 10, 5, 8, 15),   // W41: −1 h
            Work(2026, 10, 12, 8, 19),  // W42: +3 h
            Work(2026, 10, 19, 8, 17),  // W43: +1 h
            Work(2026, 10, 26, 8, 18),  // W44: +2 h
            Work(2026, 11, 2, 8, 16),   // W45:  0
            Work(2026, 11, 9, 6, 20),   // W46: laufende Woche (+6 h), zählt nicht
        };

        var f = Forecast(entries, ForecastRef, storedMs: 600 * 60_000L);

        // Summe 8 h über 8 Wochen → Mittel 1 h. 15.11.–31.12. = 16 + 31 = 47 Tage → 47/7 Wochen.
        // 10 h + 1 h × 47/7 = 36 000 000 + 169 200 000/7 = 36 000 000 + 24 171 428,571… = 60 171 428,571… → 60 171 429.
        Assert.NotNull(f);
        Assert.Equal(new DateOnly(2026, 12, 31), f.TargetDate);
        Assert.Equal(10 * H, f.CurrentBalanceMs);
        Assert.Equal(1 * H, f.AverageWeeklyOvertimeMs);
        Assert.Equal(8, f.WeeksUsed);
        Assert.Equal(47 / 7.0, f.RemainingWeeks);
        Assert.Equal(60_171_429L, f.ProjectedBalanceMs);
    }

    [Fact]
    public void Forecast_ExactlyFourWeeks_GapsNotCounted()
    {
        // W38, W40, W43, W45 mit Einträgen; W39, W41, W42, W44 leer.
        var entries = new[]
        {
            Work(2026, 9, 14, 8, 18),  // +2 h
            Work(2026, 9, 28, 8, 16),  //  0
            Work(2026, 10, 19, 8, 17), // +1 h
            Work(2026, 11, 2, 8, 17),  // +1 h
        };

        var f = Forecast(entries, ForecastRef);

        Assert.NotNull(f);
        Assert.Equal(4, f.WeeksUsed);
        Assert.Equal(H, f.AverageWeeklyOvertimeMs); // 4 h ÷ 4, nicht ÷ 8
        Assert.Equal((long)Math.Round(H * 47m / 7m, MidpointRounding.AwayFromZero), f.ProjectedBalanceMs);
    }

    [Fact]
    public void Forecast_OnlyThreeWeeks_IsNull()
    {
        var entries = new[] { Work(2026, 9, 14, 8, 18), Work(2026, 10, 19, 8, 17), Work(2026, 11, 2, 8, 17) };
        Assert.Null(Forecast(entries, ForecastRef, storedMs: 5 * H));
    }

    [Fact]
    public void Forecast_NoEntries_IsNull()
    {
        Assert.Null(Forecast(Array.Empty<WorkEntryDto>(), ForecastRef));
    }

    [Fact]
    public void Forecast_CurrentWeekDoesNotCount()
    {
        // Drei Wochen im Fenster plus Einträge in der laufenden Woche (Mo 09.11. und der Bezugstag selbst).
        var entries = new List<WorkEntryDto>
        {
            Work(2026, 10, 5, 8, 16), Work(2026, 10, 19, 8, 16), Work(2026, 11, 2, 8, 16),
            Work(2026, 11, 9, 8, 20), Work(2026, 11, 14, 8, 20),
        };
        Assert.Null(Forecast(entries, ForecastRef));

        // Mit einer vierten Fensterwoche: Mittel nur aus dem Fenster (0), die laufende Woche (+16 h) zählt nicht.
        entries.Add(Work(2026, 10, 26, 8, 16));
        var f = Forecast(entries, ForecastRef, storedMs: 3 * H);
        Assert.NotNull(f);
        Assert.Equal(4, f.WeeksUsed);
        Assert.Equal(0, f.AverageWeeklyOvertimeMs);
        Assert.Equal(3 * H, f.ProjectedBalanceMs);
    }

    [Fact]
    public void Forecast_WindowIsEightWeeks_NinthWeekBackIgnored()
    {
        // W37 (Mo 07.09.) liegt neun Wochen vor W46 und zählt nicht; im Fenster nur drei Wochen.
        var entries = new[]
        {
            Work(2026, 9, 7, 8, 16), Work(2026, 9, 14, 8, 16), Work(2026, 10, 12, 8, 16), Work(2026, 11, 2, 8, 16),
        };
        Assert.Null(Forecast(entries, ForecastRef));
    }

    [Fact]
    public void Forecast_NegativeAverage_NegativeBalance()
    {
        // Vier Wochen mit je −30 min → Mittel −0,5 h; Saldo −2 h.
        var entries = MondaysWithOvertime(new DateOnly(2026, 10, 12), -H / 2, -H / 2, -H / 2, -H / 2);
        var f = Forecast(entries, ForecastRef, storedMs: -120 * 60_000L);

        // −7 200 000 + (−1 800 000 × 47/7 = −12 085 714,285…) = −19 285 714,285… → −19 285 714.
        Assert.NotNull(f);
        Assert.Equal(-2 * H, f.CurrentBalanceMs);
        Assert.Equal(-H / 2, f.AverageWeeklyOvertimeMs);
        Assert.Equal(-19_285_714L, f.ProjectedBalanceMs);
    }

    [Fact]
    public void Forecast_AverageZero_ProjectedEqualsBalance()
    {
        var entries = MondaysWithOvertime(new DateOnly(2026, 9, 14), H, -H, 2 * H, -2 * H, 0);
        var f = Forecast(entries, ForecastRef, storedMs: -45 * 60_000L);

        Assert.NotNull(f);
        Assert.Equal(5, f.WeeksUsed);
        Assert.Equal(0, f.AverageWeeklyOvertimeMs);
        Assert.Equal(-45 * 60_000L, f.ProjectedBalanceMs);
    }

    [Fact]
    public void Forecast_ReferenceDec31_NoRemainingWeeks()
    {
        // Do 31.12.2026 liegt in 2026-W53 (Mo 28.12.); Fenster W45–W52.
        var entries = MondaysWithOvertime(new DateOnly(2026, 11, 30), H, H, H, H);
        var f = Forecast(entries, new DateOnly(2026, 12, 31), storedMs: 7 * H);

        Assert.NotNull(f);
        Assert.Equal(new DateOnly(2026, 12, 31), f.TargetDate);
        Assert.Equal(0.0, f.RemainingWeeks);
        Assert.Equal(H, f.AverageWeeklyOvertimeMs);
        Assert.Equal(7 * H, f.ProjectedBalanceMs);
    }

    [Fact]
    public void Forecast_ReferenceDec30_OneDayLeft()
    {
        var entries = MondaysWithOvertime(new DateOnly(2026, 11, 30), 7 * H, 7 * H, 7 * H, 7 * H);
        var f = Forecast(entries, new DateOnly(2026, 12, 30), storedMs: H);

        Assert.NotNull(f);
        Assert.Equal(1 / 7.0, f.RemainingWeeks);
        Assert.Equal(2 * H, f.ProjectedBalanceMs); // 1 h + 7 h × 1/7
    }

    [Fact]
    public void Forecast_ReferenceJan1_WindowInPreviousYear_CurrentIsoWeekAcrossYearExcluded()
    {
        // Fr 01.01.2027 liegt in 2026-W53 (Mo 28.12.2026 – So 03.01.2027). Fenster W45–W52 von 2026.
        var entries = MondaysWithOvertime(new DateOnly(2026, 11, 30), H, H, H, H); // W49–W52
        entries.Add(Work(2026, 12, 29, 8, 20)); // Di 29.12.2026: Vorjahr, aber laufende ISO-Woche → zählt nicht
        var f = Forecast(entries, new DateOnly(2027, 1, 1), storedMs: 0);

        Assert.NotNull(f);
        Assert.Equal(4, f.WeeksUsed);
        Assert.Equal(H, f.AverageWeeklyOvertimeMs);
        Assert.Equal(new DateOnly(2027, 12, 31), f.TargetDate);
        Assert.Equal(364 / 7.0, f.RemainingWeeks); // 02.01.–31.12.2027 = 364 Tage = 52 Wochen
        Assert.Equal(52 * H, f.ProjectedBalanceMs);
    }

    [Fact]
    public void Forecast_ReferenceInIsoWeek01_Week53OfPreviousYearCounts()
    {
        // Mo 04.01.2027 (2027-W01): die Woche davor ist 2026-W53 (Mo 28.12.2026).
        var entries = MondaysWithOvertime(new DateOnly(2026, 12, 7), 0, 0, 0, 4 * H); // W50, W51, W52, W53
        var f = Forecast(entries, new DateOnly(2027, 1, 4));

        Assert.NotNull(f);
        Assert.Equal(4, f.WeeksUsed);
        Assert.Equal(H, f.AverageWeeklyOvertimeMs);
        Assert.Equal(361 / 7.0, f.RemainingWeeks); // 05.01.–31.12.2027
    }

    [Fact]
    public void Forecast_LeapYear_CountsFeb29()
    {
        var entries = MondaysWithOvertime(new DateOnly(2028, 1, 31), 0, 0, 0, 0);
        var leap = Forecast(entries, new DateOnly(2028, 2, 28));
        Assert.NotNull(leap);
        Assert.Equal(307 / 7.0, leap.RemainingWeeks); // 29.02. + März–Dezember (306)

        var plain = Forecast(MondaysWithOvertime(new DateOnly(2027, 1, 25), 0, 0, 0, 0), new DateOnly(2027, 2, 28));
        Assert.NotNull(plain);
        Assert.Equal(306 / 7.0, plain.RemainingWeeks);
    }

    [Fact]
    public void Forecast_ProjectionUsesUnroundedAverage()
    {
        // Do 03.12.2026: 28 Tage bis 31.12. = 4 Wochen. Wochen +1, 0, 0, 0 ms → Mittel 0,25 ms (angezeigt 0).
        // Ungerundet: 0 + 0,25 × 4 = 1 ms; mit dem gerundeten Mittel wären es 0 ms.
        var entries = MondaysWithOvertime(new DateOnly(2026, 11, 2), 1, 0, 0, 0);
        var f = Forecast(entries, new DateOnly(2026, 12, 3));

        Assert.NotNull(f);
        Assert.Equal(4.0, f.RemainingWeeks);
        Assert.Equal(0, f.AverageWeeklyOvertimeMs);
        Assert.Equal(1, f.ProjectedBalanceMs);
    }

    [Theory]
    [InlineData(1, 1, 1)]    // +0,5 ms → +1 (Mittel), Prognose +0,5 → +1
    [InlineData(-1, -1, -1)] // −0,5 ms → −1, Prognose −0,5 → −1 (von der Null weg)
    public void Forecast_RoundsHalfAwayFromZero(long weekMs, long expectedAverage, long expectedProjected)
    {
        // Do 24.12.2026: 7 Tage bis 31.12. = 1 Woche. Vier Wochen: weekMs, weekMs, 0, 0 → Mittel weekMs/2.
        var entries = MondaysWithOvertime(new DateOnly(2026, 11, 23), weekMs, weekMs, 0, 0);
        var f = Forecast(entries, new DateOnly(2026, 12, 24));

        Assert.NotNull(f);
        Assert.Equal(1.0, f.RemainingWeeks);
        Assert.Equal(expectedAverage, f.AverageWeeklyOvertimeMs);
        Assert.Equal(expectedProjected, f.ProjectedBalanceMs);
    }

    [Fact]
    public void Forecast_AbsencesAndManualOvertime_FollowWeeklyReport()
    {
        var entries = new List<WorkEntryDto>();
        for (var d = 12; d <= 16; d++) entries.Add(Leave(2026, 10, d, "vacation"));            // W42: 0
        entries.Add(Work(2026, 10, 19, 8, 16, manualMinutes: 30));                              // W43: +0,5 h
        entries.Add(Leave(2026, 10, 26, "holiday"));                                            // W44: Feiertag 0
        entries.Add(Work(2026, 10, 27, 8, 18));                                                 //      +2 h
        entries.Add(Leave(2026, 11, 7, "sick"));                                                // W45: Krank am Samstag 0

        var f = Forecast(entries, ForecastRef);

        Assert.NotNull(f);
        Assert.Equal(4, f.WeeksUsed);
        Assert.Equal(2_250_000L, f.AverageWeeklyOvertimeMs); // 2,5 h ÷ 4 = 0,625 h

        var weekly = new[] { new DateOnly(2026, 10, 12), new DateOnly(2026, 10, 19), new DateOnly(2026, 10, 26), new DateOnly(2026, 11, 2) }
            .Select(d => ReportCalculator.CalculateWeeklyReport(entries, d, Settings).OvertimeMs)
            .ToList();
        Assert.Equal(new[] { 0L, H / 2, 2 * H, 0L }, weekly);
        Assert.Equal((long)weekly.Average(), f.AverageWeeklyOvertimeMs);
    }

    [Fact]
    public void Forecast_IdenticalForWeekAndMonth()
    {
        var entries = MixedEntries();
        var references = new[]
        {
            new DateOnly(2026, 11, 11), new DateOnly(2026, 12, 31), new DateOnly(2027, 1, 1),
            new DateOnly(2027, 1, 20), new DateOnly(2026, 10, 1),
        };
        foreach (var reference in references)
        {
            var week = ReportCalculator.CalculateTrend(entries, reference, TrendGranularity.Week, OddSettings, 123 * 60_000L).Forecast;
            var month = ReportCalculator.CalculateTrend(entries, reference, TrendGranularity.Month, OddSettings, 123 * 60_000L).Forecast;
            Assert.NotNull(week);
            Assert.Equal(week, month);
            Assert.Equal(week, ReportCalculator.CalculateOvertimeForecast(entries, reference, OddSettings, 123 * 60_000L));
        }
    }

    [Fact]
    public void TrendRange_CoversForecastWindow()
    {
        for (var reference = new DateOnly(2026, 1, 1); reference <= new DateOnly(2028, 12, 31); reference = reference.AddDays(1))
        {
            var windowStart = ReportCalculator.WeekBounds(reference).Start.AddDays(-7 * 8);
            foreach (var g in new[] { TrendGranularity.Week, TrendGranularity.Month })
            {
                var (from, to) = ReportCalculator.TrendRange(reference, g);
                Assert.True(from <= windowStart, $"{reference} {g}: {from} > {windowStart}");
                Assert.True(to >= reference);
            }
        }
    }

    [Fact]
    public void Forecast_WithEntriesLimitedToTrendRange_MatchesFullData()
    {
        var entries = MixedEntries();
        var reference = new DateOnly(2027, 1, 20);
        foreach (var g in new[] { TrendGranularity.Week, TrendGranularity.Month })
        {
            var (from, to) = ReportCalculator.TrendRange(reference, g);
            var limited = entries.Where(e => Day(e.Date) >= from && Day(e.Date) <= to).ToList();
            Assert.Equal(
                ReportCalculator.CalculateOvertimeForecast(entries, reference, OddSettings, 0),
                ReportCalculator.CalculateTrend(limited, reference, g, OddSettings, 0).Forecast);
        }
    }

    [Fact]
    public void Forecast_Serialization_IsoDayCamelCaseAndNull()
    {
        var options = new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web);
        var entries = MondaysWithOvertime(new DateOnly(2026, 9, 14), H, 2 * H, 0, -H, 3 * H, H, 2 * H, 0);
        var trend = ReportCalculator.CalculateTrend(entries, ForecastRef, TrendGranularity.Week, Settings, 10 * H);
        var json = System.Text.Json.JsonSerializer.Serialize(trend, options);

        Assert.Contains(
            "\"forecast\":{\"targetDate\":\"2026-12-31\",\"currentBalanceMs\":36000000,\"averageWeeklyOvertimeMs\":3600000,"
            + "\"weeksUsed\":8,\"remainingWeeks\":6.714285714285714,\"projectedBalanceMs\":60171429}",
            json);

        var empty = ReportCalculator.CalculateTrend(
            Array.Empty<WorkEntryDto>(), ForecastRef, TrendGranularity.Month, Settings, 10 * H);
        Assert.Contains("\"forecast\":null", System.Text.Json.JsonSerializer.Serialize(empty, options));
    }

    // ── Zeitraum, Repository-Monate, Validierung ───────────────────────────

    [Fact]
    public void TrendRange_CoversBucketsAndComparisonWeeks()
    {
        Assert.Equal(
            (new DateOnly(2026, 8, 24), new DateOnly(2026, 11, 15)),
            ReportCalculator.TrendRange(new DateOnly(2026, 11, 14), TrendGranularity.Week));
        Assert.Equal(
            (new DateOnly(2025, 12, 1), new DateOnly(2026, 11, 30)),
            ReportCalculator.TrendRange(new DateOnly(2026, 11, 14), TrendGranularity.Month));
    }

    [Fact]
    public void MonthsInRange_ListsEveryTouchedMonthOnce()
    {
        Assert.Equal(
            new[] { (2026, 8), (2026, 9), (2026, 10), (2026, 11) },
            WorkEntryRepository.MonthsInRange(new DateOnly(2026, 8, 24), new DateOnly(2026, 11, 15)));
        var year = WorkEntryRepository.MonthsInRange(new DateOnly(2025, 12, 1), new DateOnly(2026, 11, 30));
        Assert.Equal(12, year.Count);
        Assert.Equal((2025, 12), year[0]);
        Assert.Equal((2026, 11), year[11]);
    }

    [Theory]
    [InlineData("week", TrendGranularity.Week)]
    [InlineData("month", TrendGranularity.Month)]
    public void TryParseGranularity_Valid(string value, TrendGranularity expected)
    {
        Assert.True(ReportEndpoints.TryParseGranularity(value, out var g));
        Assert.Equal(expected, g);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("day")]
    [InlineData("year")]
    [InlineData("Week")]
    [InlineData("weeks")]
    public void TryParseGranularity_Invalid(string? value)
    {
        Assert.False(ReportEndpoints.TryParseGranularity(value, out _));
    }
}
