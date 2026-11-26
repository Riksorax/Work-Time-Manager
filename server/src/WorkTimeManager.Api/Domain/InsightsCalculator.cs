using WorkTimeManager.Api.Contracts;

namespace WorkTimeManager.Api.Domain;

/// <summary>
/// Arbeitszeit-Insights (#537): Wochentags-Durchschnitte, Überstunden-Serie und Startzeit-Heatmap. Regeln 1:1 aus
/// Mobile (<c>mobile/lib/domain/utils/insights_utils.dart</c>, <c>insights_view_model.dart</c>, #134), damit sich keine
/// Zahl ändert. Zeitpunkte (Start, Ende, Pausen) werden wie an der Mobile-Lesegrenze auf die volle Minute abgeschnitten.
/// Gerechnet wird wie in Dart in <b>Mikrosekunden</b> (Mittelwerte ganzzahlig zur Null hin geteilt); erst die Ausgabe wird auf ganze ms zur Null hin abgeschnitten
/// (Dart <c>Duration.inMilliseconds</c>). Keine Server-Uhr, keine Server-Zeitzone.
/// </summary>
public static class InsightsCalculator
{
    /// <summary>Warnschwelle der Überstunden-Serie in Vertrags-Arbeitstagen (Mobile <c>_burnoutWarningThresholdDays</c>).</summary>
    public const int WarningThresholdDays = 5;

    /// <summary>Mindestzahl Einträge je Startstunde (Mobile <c>minSampleCount</c>).</summary>
    public const int MinHeatmapSamples = 2;

    /// <summary>
    /// Zeitfenster: die drei Kalendermonate bis einschließlich des Monats von <paramref name="referenceDate"/>, ganz
    /// (1. des Monats zwei Monate davor bis Monatsletzter des Bezugsmonats; Mobile <c>_monthCount = 3</c>).
    /// </summary>
    public static (DateOnly From, DateOnly To) Range(DateOnly referenceDate)
    {
        var first = new DateOnly(referenceDate.Year, referenceDate.Month, 1);
        return (first.AddMonths(-2), first.AddMonths(1).AddDays(-1));
    }

    /// <summary>
    /// Rechnet die Insights über <paramref name="entries"/> (alle Einträge des Zeitfensters, beliebige Typen).
    /// Tagessoll = <see cref="ReportCalculator.DailyTargetMs"/> (#535). Die Startstunde der Heatmap ist die Stunde von
    /// <c>workStart</c> in <paramref name="timeZone"/>.
    /// </summary>
    public static InsightsReportDto Calculate(
        IReadOnlyList<WorkEntryDto> entries, DateOnly referenceDate, SettingsDto settings, TimeZoneInfo timeZone)
    {
        var (from, to) = Range(referenceDate);
        var inRange = entries.Where(e =>
        {
            var d = EntryDays.Of(e);
            return d >= from && d <= to;
        }).ToList();
        var dailyTargetMs = ReportCalculator.DailyTargetMs(settings);

        return new InsightsReportDto
        {
            From = from,
            To = to,
            TimeZone = timeZone.Id,
            DailyTargetMs = dailyTargetMs,
            WeekdayAverages = WeekdayAverages(inRange),
            OvertimeStreak = OvertimeStreak(inRange, settings.Workdays, dailyTargetMs * 1000),
            StartTimeHeatmap = StartTimeHeatmap(inRange, dailyTargetMs * 1000, timeZone),
        };
    }

    /// <summary>
    /// Mobile <c>calculateWeekdayAverages</c>: nur <c>work</c> mit Start <b>und</b> Ende; Wochentag aus dem Kalendertag
    /// des Eintrags; jeder Eintrag ist ein Wert (mehrere am Tag zählen einzeln); nur Wochentage mit Daten.
    /// </summary>
    internal static IReadOnlyList<WeekdayAverageDto> WeekdayAverages(IEnumerable<WorkEntryDto> entries)
    {
        var byWeekday = new SortedDictionary<int, List<long>>();
        foreach (var e in entries)
        {
            if (e.Type != "work" || e.WorkStart is null || e.WorkEnd is null) continue;
            var weekday = IsoDow(EntryDays.Of(e));
            if (!byWeekday.TryGetValue(weekday, out var list)) byWeekday[weekday] = list = new List<long>();
            list.Add(EffectiveMicros(e));
        }

        if (byWeekday.Count == 0) return Array.Empty<WeekdayAverageDto>();
        var overall = Average(byWeekday.Values.SelectMany(v => v).ToList());
        return byWeekday.Select(kv =>
        {
            var avg = Average(kv.Value);
            return new WeekdayAverageDto(kv.Key, ToMs(avg), ToMs(avg - overall), kv.Value.Count);
        }).ToList();
    }

    /// <summary>
    /// Mobile <c>detectOvertimeStreak</c>: ein Tag ist „über Soll“, wenn ein einzelner <c>work</c>-Eintrag effektiv
    /// <b>mehr</b> als das Tagessoll hat (Einträge eines Tages werden nicht summiert). Der Zeitraum reicht vom ersten bis
    /// zum letzten Kalendertag mit <c>work</c>-Eintrag (auch ohne Start). Nur Vertrags-Wochentage zählen; ein
    /// Vertragstag ohne Überschreitung (oder ohne Eintrag, auch Urlaub/Krank/Feiertag) beendet die Serie, freie Tage
    /// nicht. Ohne Einträge oder ohne Arbeitstage: 0/0.
    /// </summary>
    internal static OvertimeStreakDto OvertimeStreak(
        IReadOnlyList<WorkEntryDto> entries, IReadOnlyList<int> workdays, long dailyTargetMicros)
    {
        var none = new OvertimeStreakDto(0, 0, false, WarningThresholdDays);
        if (entries.Count == 0 || workdays.Count == 0) return none;

        var overTarget = new HashSet<DateOnly>();
        DateOnly? min = null, max = null;
        foreach (var e in entries)
        {
            if (e.Type != "work") continue;
            var day = EntryDays.Of(e);
            if (min is null || day < min) min = day;
            if (max is null || day > max) max = day;
            if (EffectiveMicros(e) > dailyTargetMicros) overTarget.Add(day);
        }

        if (min is null || max is null) return none;

        var streak = 0;
        var longest = 0;
        for (var day = min.Value; day <= max.Value; day = day.AddDays(1))
        {
            if (!workdays.Contains(IsoDow(day))) continue;
            if (overTarget.Contains(day))
            {
                streak++;
                if (streak > longest) longest = streak;
            }
            else
            {
                streak = 0;
            }
        }

        return new OvertimeStreakDto(streak, longest, streak >= WarningThresholdDays, WarningThresholdDays);
    }

    /// <summary>
    /// Mobile <c>buildStartTimeHeatmap</c>: alle <c>work</c>-Einträge mit Start (auch offene: effektiv 0, also −Soll),
    /// gruppiert nach der Stunde des Starts in <paramref name="timeZone"/>; Wert = effektiv − Tagessoll; nur Stunden mit
    /// mindestens <see cref="MinHeatmapSamples"/> Einträgen, aufsteigend.
    /// </summary>
    internal static IReadOnlyList<StartTimeBucketDto> StartTimeHeatmap(
        IEnumerable<WorkEntryDto> entries, long dailyTargetMicros, TimeZoneInfo timeZone)
    {
        var byHour = new SortedDictionary<int, List<long>>();
        foreach (var e in entries)
        {
            if (e.Type != "work" || e.WorkStart is null) continue;
            var hour = TimeZoneInfo.ConvertTime(e.WorkStart.Value, timeZone).Hour;
            if (!byHour.TryGetValue(hour, out var list)) byHour[hour] = list = new List<long>();
            list.Add(EffectiveMicros(e) - dailyTargetMicros);
        }

        return byHour
            .Where(kv => kv.Value.Count >= MinHeatmapSamples)
            .Select(kv => new StartTimeBucketDto(kv.Key, ToMs(Average(kv.Value)), kv.Value.Count))
            .ToList();
    }

    /// <summary>
    /// Mobile <c>_effectiveDuration</c>: nur mit Start und Ende; Ende − Start − Summe der <b>abgeschlossenen</b> Pausen
    /// (offene zählen 0), nie negativ. Typunabhängig (die Aufrufer filtern).
    /// </summary>
    private static long EffectiveMicros(WorkEntryDto e)
    {
        if (e.WorkStart is null || e.WorkEnd is null) return 0;
        var breaks = e.Breaks.Where(b => b.End is not null).Sum(b => Micros(b.End!.Value) - Micros(b.Start));
        var net = Micros(e.WorkEnd.Value) - Micros(e.WorkStart.Value) - breaks;
        return net < 0 ? 0 : net;
    }

    /// <summary>
    /// Zeitpunkt in µs, vorher auf die volle Minute <b>abgeschnitten</b>: Mobile liest Start, Ende und Pausen an der
    /// Lesegrenze über <c>roundToMinute</c> (<c>ApiClient._entryFromJson</c>, verwirft Sekunden und Bruchteile), die
    /// Insights rechnen also mit Minuten. Alle heutigen Zonen haben Offsets in ganzen Minuten, daher ist das Abschneiden
    /// in UTC gleich dem in Ortszeit.
    /// </summary>
    private static long Micros(DateTimeOffset d)
    {
        var ticks = d.UtcTicks;
        return (ticks - ticks % TimeSpan.TicksPerMinute) / 10;
    }

    /// <summary>Dart <c>_average</c>: Summe in µs ganzzahlig durch die Anzahl, zur Null hin.</summary>
    private static long Average(IReadOnlyCollection<long> micros) =>
        micros.Count == 0 ? 0 : micros.Sum() / micros.Count;

    /// <summary>Dart <c>Duration.inMilliseconds</c>: zur Null hin abgeschnitten.</summary>
    private static long ToMs(long micros) => micros / 1000;

    private static int IsoDow(DateOnly d) => d.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)d.DayOfWeek;
}
