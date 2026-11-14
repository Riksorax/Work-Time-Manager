using System.Globalization;
using WorkTimeManager.Api.Contracts;

namespace WorkTimeManager.Api.Domain;

/// <summary>Bucket-Größe des Trends (#531); im Query-Parameter als <c>week</c> bzw. <c>month</c>.</summary>
public enum TrendGranularity
{
    Week,
    Month,
}

/// <summary>
/// Berechnet Tages-, Wochen- und Monatsberichte. Portiert aus dem Web-ReportCalculatorService —
/// Bruttozeit (Start→Ende) wird summiert, Pausen separat erfasst; Urlaub/Krank/Feiertag zählen
/// als voller Arbeitstag. Alle Zeitwerte in Millisekunden.
/// </summary>
public static class ReportCalculator
{
    /// <summary>ISO-8601-Kalenderwoche — identische Logik zur Web-Implementierung.</summary>
    public static int GetIsoWeekNumber(DateOnly date)
    {
        var year = date.Year;
        var jan4 = new DateOnly(year, 1, 4);
        var firstMonday = jan4.AddDays(-(IsoDow(jan4) - 1));
        var diffDays = date.DayNumber - firstMonday.DayNumber;
        var week = (int)Math.Floor(diffDays / 7.0) + 1;

        if (week < 1)
        {
            return GetIsoWeekNumber(new DateOnly(year - 1, 12, 28));
        }

        var jan4Next = new DateOnly(year + 1, 1, 4);
        var firstMondayNext = jan4Next.AddDays(-(IsoDow(jan4Next) - 1));
        return date >= firstMondayNext ? 1 : week;
    }

    /// <summary>
    /// Jahresauswertung Urlaub/Krank (#278): zählt <c>vacation</c>- und <c>sick</c>-Einträge mit
    /// Datum im Kalenderjahr. Ein Eintrag = ein Tag, unabhängig vom Arbeitstag-Setting; Rest wird
    /// nicht geklemmt; <c>holiday</c> zählt nicht.
    /// </summary>
    public static YearlyLeaveReportDto CalculateYearlyLeave(
        IReadOnlyList<WorkEntryDto> yearEntries, int year, SettingsDto settings)
    {
        var inYear = yearEntries.Where(e => e.Date.Year == year).ToList();
        var taken = inYear.Count(e => e.Type == "vacation");
        var sick = inYear.Count(e => e.Type == "sick");
        var entitlement = settings.VacationDaysPerYear ?? SettingsDto.DefaultVacationDaysPerYear;
        return new YearlyLeaveReportDto
        {
            Year = year,
            VacationDaysPerYear = entitlement,
            VacationDaysTaken = taken,
            VacationDaysRemaining = entitlement - taken,
            SickDays = sick,
        };
    }

    public static DailyStatDto CalculateDailyStat(
        IReadOnlyList<WorkEntryDto> monthEntries, DateOnly date, SettingsDto settings)
    {
        var daily = DailyTargetMs(settings);
        var target = settings.Workdays.Contains(IsoDow(date)) ? daily : 0;

        long worked = 0;
        long manualMs = 0;
        foreach (var entry in monthEntries.Where(e => DatePart(e.Date) == date))
        {
            worked += entry.Type != "work" ? target : NetWorkMs(entry);
            manualMs += (entry.ManualOvertimeMinutes ?? 0) * 60_000L;
        }

        return new DailyStatDto { TargetMs = target, WorkedMs = worked, OvertimeMs = worked - target + manualMs };
    }

    public static WeeklyReportDto CalculateWeeklyReport(
        IReadOnlyList<WorkEntryDto> entries, DateOnly date, SettingsDto settings)
    {
        var (weekStart, weekEnd) = WeekBounds(date);
        var t = SumPeriod(FilterByWeek(entries, date), settings);

        var days = t.DayMap.OrderBy(kvp => kvp.Key)
            .Select(kvp => new ReportDayDto(ToUtcMidnight(kvp.Key), kvp.Value))
            .ToList();

        return new WeeklyReportDto
        {
            WeekNumber = GetIsoWeekNumber(date),
            Start = ToUtcMidnight(weekStart),
            End = ToUtcMidnight(weekEnd),
            TotalWorkedMs = t.GrossWorkedMs,
            TotalBreaksMs = t.BreaksMs,
            WorkDays = t.WorkDays.Count,
            AvgPerDayMs = t.WorkDays.Count > 0 ? (double)t.NetWorkedMs / t.WorkDays.Count : 0,
            OvertimeMs = t.OvertimeMs,
            Days = days,
        };
    }

    public static MonthlyReportDto CalculateMonthlyReport(
        IReadOnlyList<WorkEntryDto> entries, DateOnly monthRef, SettingsDto settings, long storedOvertimeMs)
    {
        var t = SumPeriod(entries, settings);

        // Jeder Tag gehört zu genau einer ISO-KW; die Summen je KW ergeben sich aus der Tages-Map.
        var weekTotals = t.DayMap
            .GroupBy(kvp => GetIsoWeekNumber(kvp.Key))
            .ToDictionary(g => g.Key, g => g.Sum(kvp => kvp.Value));
        var numWeeks = weekTotals.Count;
        var workDays = t.WorkDays.Count;

        return new MonthlyReportDto
        {
            Month = ToUtcMidnight(new DateOnly(monthRef.Year, monthRef.Month, 1)),
            TotalWorkedMs = t.GrossWorkedMs,
            TotalBreaksMs = t.BreaksMs,
            WorkDays = workDays,
            AvgPerDayMs = workDays > 0 ? (double)t.NetWorkedMs / workDays : 0,
            AvgPerWeekMs = numWeeks > 0 ? (double)t.NetWorkedMs / numWeeks : 0,
            MonthlyOvertimeMs = t.OvertimeMs,
            TotalOvertimeMs = t.OvertimeMs + storedOvertimeMs,
            Weeks = weekTotals.OrderBy(kvp => kvp.Key)
                .Select(kvp => new ReportWeekDto(kvp.Key, kvp.Value)).ToList(),
            Days = t.DayMap.OrderBy(kvp => kvp.Key)
                .Select(kvp => new ReportDayDto(ToUtcMidnight(kvp.Key), kvp.Value)).ToList(),
        };
    }

    // ─── Trend (#531) ────────────────────────────────────────────────────────

    private const int TrendBucketCount = 12;
    private const int TrendComparisonWeeks = 4;

    /// <summary>
    /// Verlauf über 12 Wochen bzw. 12 Monate bis einschließlich der Woche/des Monats von
    /// <paramref name="referenceDate"/> (#531). Jeder Bucket rechnet mit demselben Kern wie Wochen- bzw.
    /// Monatsbericht (<see cref="SumPeriod"/>); <c>workedMs</c> ist netto. Der gespeicherte Gleitzeit-Saldo
    /// fließt nicht ein, <c>cumulativeOvertimeMs</c> beginnt bei 0. Dazu der Wochen-Trend (bei beiden
    /// Granularitäten). <paramref name="entries"/> muss mindestens <see cref="TrendRange"/> abdecken.
    /// </summary>
    public static TrendReportDto CalculateTrend(
        IReadOnlyList<WorkEntryDto> entries, DateOnly referenceDate, TrendGranularity granularity, SettingsDto settings)
    {
        var buckets = new List<TrendBucketDto>(TrendBucketCount);
        long cumulative = 0;
        foreach (var (start, end) in TrendPeriods(referenceDate, granularity))
        {
            var t = SumPeriod(FilterByRange(entries, start, end), settings);
            cumulative += t.OvertimeMs;
            buckets.Add(new TrendBucketDto
            {
                Key = granularity == TrendGranularity.Week ? IsoWeekKey(start) : $"{start.Year:D4}-{start.Month:D2}",
                Start = ToUtcMidnight(start),
                End = ToUtcMidnight(end),
                WorkedMs = t.NetWorkedMs,
                TargetMs = t.TargetMs,
                OvertimeMs = t.OvertimeMs,
                CumulativeOvertimeMs = cumulative,
                HasData = t.HasData,
            });
        }

        return new TrendReportDto
        {
            Granularity = granularity == TrendGranularity.Week ? "week" : "month",
            Buckets = buckets,
            WeeklyTrend = CalculateWeeklyTrend(entries, referenceDate, settings),
        };
    }

    /// <summary>
    /// Kalendertage, die der Trend braucht: alle Buckets und die Wochen des Wochen-Trends
    /// (letzte abgeschlossene Woche + vier Vergleichswochen).
    /// </summary>
    public static (DateOnly From, DateOnly To) TrendRange(DateOnly referenceDate, TrendGranularity granularity)
    {
        var periods = TrendPeriods(referenceDate, granularity);
        var comparisonStart = WeekBounds(referenceDate).Start.AddDays(-7 * (TrendComparisonWeeks + 1));
        var from = periods[0].Start < comparisonStart ? periods[0].Start : comparisonStart;
        return (from, periods[^1].End);
    }

    /// <summary>ISO-Wochenschlüssel <c>yyyy-Www</c> mit ISO-Wochenjahr (Mo 29.12.2025 → <c>2026-W01</c>).</summary>
    public static string IsoWeekKey(DateOnly date) =>
        $"{ISOWeek.GetYear(date.ToDateTime(TimeOnly.MinValue)):D4}-W{GetIsoWeekNumber(date):D2}";

    private static List<(DateOnly Start, DateOnly End)> TrendPeriods(DateOnly referenceDate, TrendGranularity granularity)
    {
        var periods = new List<(DateOnly, DateOnly)>(TrendBucketCount);
        if (granularity == TrendGranularity.Week)
        {
            var current = WeekBounds(referenceDate).Start;
            for (var i = TrendBucketCount - 1; i >= 0; i--)
            {
                var start = current.AddDays(-7 * i);
                periods.Add((start, start.AddDays(6)));
            }
        }
        else
        {
            var current = new DateOnly(referenceDate.Year, referenceDate.Month, 1);
            for (var i = TrendBucketCount - 1; i >= 0; i--)
            {
                var start = current.AddMonths(-i);
                periods.Add((start, start.AddMonths(1).AddDays(-1)));
            }
        }
        return periods;
    }

    /// <summary>
    /// Letzte abgeschlossene ISO-Woche (vor der Woche des Bezugstags) gegen das Mittel der vier Wochen davor.
    /// Vergleichswochen ohne Einträge zählen nicht. <c>null</c>, wenn die letzte Woche leer ist oder weniger
    /// als zwei Vergleichswochen Einträge haben. Mittel kaufmännisch auf ganze Millisekunden gerundet.
    /// </summary>
    private static WeeklyTrendDto? CalculateWeeklyTrend(
        IReadOnlyList<WorkEntryDto> entries, DateOnly referenceDate, SettingsDto settings)
    {
        var lastWeekStart = WeekBounds(referenceDate).Start.AddDays(-7);
        var lastWeek = SumPeriod(FilterByRange(entries, lastWeekStart, lastWeekStart.AddDays(6)), settings);
        if (!lastWeek.HasData) return null;

        var compared = Enumerable.Range(1, TrendComparisonWeeks)
            .Select(i => lastWeekStart.AddDays(-7 * i))
            .Select(start => SumPeriod(FilterByRange(entries, start, start.AddDays(6)), settings))
            .Where(t => t.HasData)
            .Select(t => t.NetWorkedMs)
            .ToList();
        if (compared.Count < 2) return null;

        var average = (long)Math.Round(
            (decimal)compared.Sum() / compared.Count, MidpointRounding.AwayFromZero);
        return new WeeklyTrendDto
        {
            LastWeekKey = IsoWeekKey(lastWeekStart),
            LastWeekWorkedMs = lastWeek.NetWorkedMs,
            AverageWorkedMs = average,
            DeltaMs = lastWeek.NetWorkedMs - average,
            ComparedWeeks = compared.Count,
        };
    }

    // ─── Gemeinsamer Kern ────────────────────────────────────────────────────

    /// <summary>Summen eines Zeitraums; Grundlage für Wochen-, Monatsbericht und Trend.</summary>
    private sealed record PeriodTotals(
        long GrossWorkedMs,
        long BreaksMs,
        long ManualMs,
        long TargetMs,
        IReadOnlySet<DateOnly> WorkDays,
        IReadOnlyDictionary<DateOnly, long> DayMap)
    {
        /// <summary>Brutto − Pausen (Urlaub/Krank/Feiertag mit dem Tagessoll).</summary>
        public long NetWorkedMs => GrossWorkedMs - BreaksMs;

        public long OvertimeMs => NetWorkedMs - TargetMs + ManualMs;

        /// <summary>Mindestens ein Eintrag im Zeitraum (jeder Eintrag erzeugt einen Tag in der Map).</summary>
        public bool HasData => DayMap.Count > 0;
    }

    /// <summary>
    /// Rechenregel der Berichte: Arbeit brutto (Start→Ende) und Pausen getrennt, Urlaub/Krank/Feiertag mit dem
    /// Tagessoll; Soll = Tage mit Eintrag (Nicht-Arbeit oder Arbeit mit Start) an einem Vertrags-Wochentag ×
    /// Tagessoll; manuelle Überstunden zusätzlich. Filtert nicht — der Aufrufer übergibt die Einträge des Zeitraums.
    /// </summary>
    private static PeriodTotals SumPeriod(IEnumerable<WorkEntryDto> entries, SettingsDto settings)
    {
        var daily = DailyTargetMs(settings);
        long totalWorked = 0, totalBreaks = 0, manualMs = 0;
        var workDays = new HashSet<DateOnly>();
        var dayMap = new Dictionary<DateOnly, long>();

        foreach (var entry in entries)
        {
            var key = DatePart(entry.Date);
            long worked, breaks = 0;

            if (entry.Type != "work")
            {
                worked = daily;
                workDays.Add(key);
            }
            else
            {
                breaks = SumBreakMs(entry);
                worked = GrossWorkMs(entry);
                if (entry.WorkStart is not null) workDays.Add(key);
            }

            totalWorked += worked;
            totalBreaks += breaks;
            manualMs += (entry.ManualOvertimeMinutes ?? 0) * 60_000L;
            dayMap[key] = dayMap.GetValueOrDefault(key) + worked;
        }

        var target = workDays.Count(d => settings.Workdays.Contains(IsoDow(d))) * daily;
        return new PeriodTotals(totalWorked, totalBreaks, manualMs, target, workDays, dayMap);
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    /// <summary>
    /// Tagessoll = Wochenstunden × 3 600 000 ÷ Zahl der Arbeitstage, auf die volle Minute gerundet
    /// (#535). Rundung wie <c>roundMsToMinute</c> im Web: kaufmännisch, .5 von der Null weg. Ohne
    /// Arbeitstage ist das Soll 0 (keine Division durch null).
    /// </summary>
    private static long DailyTargetMs(SettingsDto s)
    {
        if (s.Workdays.Count == 0) return 0;
        var minutes = s.WeeklyTargetHours * 3_600_000 / s.Workdays.Count / 60_000;
        return (long)Math.Round(minutes, MidpointRounding.AwayFromZero) * 60_000L;
    }

    private static long SumBreakMs(WorkEntryDto entry) =>
        entry.Breaks.Where(b => b.End is not null)
            .Sum(b => (long)(b.End!.Value - b.Start).TotalMilliseconds);

    private static long GrossWorkMs(WorkEntryDto entry) =>
        entry.WorkStart is not null && entry.WorkEnd is not null
            ? (long)(entry.WorkEnd.Value - entry.WorkStart.Value).TotalMilliseconds
            : 0;

    private static long NetWorkMs(WorkEntryDto entry)
    {
        if (entry.Type != "work" || entry.WorkStart is null || entry.WorkEnd is null) return 0;
        var net = GrossWorkMs(entry) - SumBreakMs(entry);
        return net > 0 ? net : 0;
    }

    private static IReadOnlyList<WorkEntryDto> FilterByWeek(IReadOnlyList<WorkEntryDto> entries, DateOnly date)
    {
        var (start, end) = WeekBounds(date);
        return FilterByRange(entries, start, end);
    }

    /// <summary>Einträge mit Kalendertag in <paramref name="start"/>..<paramref name="end"/> (inklusive).</summary>
    private static IReadOnlyList<WorkEntryDto> FilterByRange(IReadOnlyList<WorkEntryDto> entries, DateOnly start, DateOnly end) =>
        entries.Where(e =>
        {
            var d = DatePart(e.Date);
            return d >= start && d <= end;
        }).ToList();

    /// <summary>Wochengrenzen (Montag–Sonntag) der Woche, die <paramref name="date"/> enthält.</summary>
    public static (DateOnly Start, DateOnly End) WeekBounds(DateOnly date)
    {
        var start = date.AddDays(-(IsoDow(date) - 1));
        return (start, start.AddDays(6));
    }

    private static int IsoDow(DateOnly d) => d.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)d.DayOfWeek;

    private static DateOnly DatePart(DateTimeOffset d) => new(d.Year, d.Month, d.Day);

    private static DateTimeOffset ToUtcMidnight(DateOnly d) =>
        new(d.Year, d.Month, d.Day, 0, 0, 0, TimeSpan.Zero);
}
