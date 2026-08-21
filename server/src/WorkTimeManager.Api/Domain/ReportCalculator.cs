using WorkTimeManager.Api.Contracts;

namespace WorkTimeManager.Api.Domain;

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

    public static DailyStatDto CalculateDailyStat(
        IReadOnlyList<WorkEntryDto> monthEntries, DateOnly date, SettingsDto settings)
    {
        var daily = DailyTargetMs(settings);
        var weekEntries = FilterByWeek(monthEntries, date);
        var target = EffectiveDailyTarget(date, weekEntries, settings, daily);

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
        var daily = DailyTargetMs(settings);
        var (weekStart, weekEnd) = WeekBounds(date);
        var weekEntries = FilterByWeek(entries, date);

        long totalWorked = 0, totalBreaks = 0, manualMs = 0;
        var workDays = new HashSet<DateOnly>();
        var dayMap = new Dictionary<DateOnly, long>();

        foreach (var entry in weekEntries)
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

        var effectiveDays = Math.Min(workDays.Count, settings.WorkdaysPerWeek);
        var weekTarget = effectiveDays * daily;
        var netWork = totalWorked - totalBreaks;
        var days = dayMap.OrderBy(kvp => kvp.Key)
            .Select(kvp => new ReportDayDto(ToUtcMidnight(kvp.Key), kvp.Value))
            .ToList();

        return new WeeklyReportDto
        {
            WeekNumber = GetIsoWeekNumber(date),
            Start = ToUtcMidnight(weekStart),
            End = ToUtcMidnight(weekEnd),
            TotalWorkedMs = totalWorked,
            TotalBreaksMs = totalBreaks,
            WorkDays = workDays.Count,
            AvgPerDayMs = workDays.Count > 0 ? (double)netWork / workDays.Count : 0,
            OvertimeMs = netWork - weekTarget + manualMs,
            Days = days,
        };
    }

    public static MonthlyReportDto CalculateMonthlyReport(
        IReadOnlyList<WorkEntryDto> entries, DateOnly monthRef, SettingsDto settings, long storedOvertimeMs)
    {
        var daily = DailyTargetMs(settings);
        var weekWorkDays = new Dictionary<int, HashSet<DateOnly>>();
        var weekTotals = new Dictionary<int, long>();
        var dayMap = new Dictionary<DateOnly, long>();

        long totalWorked = 0, totalBreaks = 0, manualMs = 0;

        foreach (var entry in entries)
        {
            var key = DatePart(entry.Date);
            var weekNum = GetIsoWeekNumber(key);
            var daySet = weekWorkDays.TryGetValue(weekNum, out var s) ? s : weekWorkDays[weekNum] = new();

            long worked, breaks = 0;
            if (entry.Type != "work")
            {
                worked = daily;
                daySet.Add(key);
            }
            else
            {
                breaks = SumBreakMs(entry);
                worked = GrossWorkMs(entry);
                if (entry.WorkStart is not null) daySet.Add(key);
            }

            totalWorked += worked;
            totalBreaks += breaks;
            manualMs += (entry.ManualOvertimeMinutes ?? 0) * 60_000L;
            dayMap[key] = dayMap.GetValueOrDefault(key) + worked;
            weekTotals[weekNum] = weekTotals.GetValueOrDefault(weekNum) + worked;
        }

        var effectiveTotalWorkDays = weekWorkDays.Values
            .Sum(set => Math.Min(set.Count, settings.WorkdaysPerWeek));
        var monthTarget = effectiveTotalWorkDays * daily;
        var netWork = totalWorked - totalBreaks;
        var monthlyOvertime = netWork - monthTarget + manualMs;

        var workDays = weekWorkDays.Values.Sum(set => set.Count);
        var numWeeks = weekWorkDays.Count;

        return new MonthlyReportDto
        {
            Month = ToUtcMidnight(new DateOnly(monthRef.Year, monthRef.Month, 1)),
            TotalWorkedMs = totalWorked,
            TotalBreaksMs = totalBreaks,
            WorkDays = workDays,
            AvgPerDayMs = workDays > 0 ? (double)netWork / workDays : 0,
            AvgPerWeekMs = numWeeks > 0 ? (double)netWork / numWeeks : 0,
            MonthlyOvertimeMs = monthlyOvertime,
            TotalOvertimeMs = monthlyOvertime + storedOvertimeMs,
            Weeks = weekTotals.OrderBy(kvp => kvp.Key)
                .Select(kvp => new ReportWeekDto(kvp.Key, kvp.Value)).ToList(),
            Days = dayMap.OrderBy(kvp => kvp.Key)
                .Select(kvp => new ReportDayDto(ToUtcMidnight(kvp.Key), kvp.Value)).ToList(),
        };
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static long DailyTargetMs(SettingsDto s) =>
        (long)(s.WeeklyTargetHours * 3_600_000 / s.WorkdaysPerWeek);

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

    private static long EffectiveDailyTarget(
        DateOnly date, IReadOnlyList<WorkEntryDto> weekEntries, SettingsDto settings, long daily)
    {
        var workDays = weekEntries
            .Where(e => e.WorkStart is not null || e.Type != "work")
            .Select(e => DatePart(e.Date))
            .Distinct()
            .OrderBy(d => d)
            .ToList();

        var idx = workDays.IndexOf(date);
        if (idx == -1) return daily;
        return idx < settings.WorkdaysPerWeek ? daily : 0;
    }

    private static IReadOnlyList<WorkEntryDto> FilterByWeek(IReadOnlyList<WorkEntryDto> entries, DateOnly date)
    {
        var (start, end) = WeekBounds(date);
        return entries.Where(e =>
        {
            var d = DatePart(e.Date);
            return d >= start && d <= end;
        }).ToList();
    }

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
