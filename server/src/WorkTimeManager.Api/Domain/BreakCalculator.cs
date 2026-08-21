using WorkTimeManager.Api.Contracts;

namespace WorkTimeManager.Api.Domain;

/// <summary>Pflichtpausen-Logik (Deutschland). Portiert aus dem Web/Flutter-BreakCalculator.</summary>
public static class BreakCalculator
{
    private static readonly TimeSpan MinWorkFirstBreak = TimeSpan.FromHours(6);
    private static readonly TimeSpan MinWorkSecondBreak = TimeSpan.FromHours(9);
    private static readonly TimeSpan FirstBreak = TimeSpan.FromMinutes(30);
    private static readonly TimeSpan SecondBreak = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan RequiredLongDay = TimeSpan.FromMinutes(45);

    public sealed record ComplianceResult(
        bool IsCompliant, long RequiredBreakMs, long ActualBreakMs, long MissingBreakMs);

    private static TimeSpan TotalBreak(IEnumerable<BreakDto> breaks) =>
        breaks.Where(b => b.End is not null)
              .Aggregate(TimeSpan.Zero, (sum, b) => sum + (b.End!.Value - b.Start));

    private static TimeSpan NetWork(WorkEntryDto entry)
    {
        if (entry.WorkStart is null || entry.WorkEnd is null) return TimeSpan.Zero;
        var gross = entry.WorkEnd.Value - entry.WorkStart.Value;
        var net = gross - TotalBreak(entry.Breaks);
        return net > TimeSpan.Zero ? net : TimeSpan.Zero;
    }

    private static TimeSpan RequiredFor(TimeSpan work) =>
        work >= MinWorkSecondBreak ? RequiredLongDay
        : work >= MinWorkFirstBreak ? FirstBreak
        : TimeSpan.Zero;

    public static ComplianceResult ValidateCompliance(WorkEntryDto entry)
    {
        var actual = TotalBreak(entry.Breaks);
        var required = RequiredFor(NetWork(entry));
        var missing = required > actual ? required - actual : TimeSpan.Zero;
        return new ComplianceResult(
            missing == TimeSpan.Zero,
            (long)required.TotalMilliseconds,
            (long)actual.TotalMilliseconds,
            (long)missing.TotalMilliseconds);
    }

    /// <summary>Berechnet bzw. ergänzt automatische Pausen für einen Eintrag (immutabel).</summary>
    public static WorkEntryDto CalculateAndApply(WorkEntryDto entry)
    {
        if (entry.WorkStart is null || entry.WorkEnd is null) return entry;

        var start = entry.WorkStart.Value;
        var end = entry.WorkEnd.Value;
        var totalWork = end - start;

        var breaks = entry.Breaks.Count == 0
            ? CalculateBreaks(start, end, totalWork)
            : AdjustExisting(start, end, totalWork, entry.Breaks);

        return entry with { Breaks = breaks };
    }

    private static List<BreakDto> CalculateBreaks(DateTimeOffset start, DateTimeOffset end, TimeSpan totalWork)
    {
        var breaks = new List<BreakDto>();

        if (totalWork >= MinWorkSecondBreak)
        {
            var s1 = start + TimeSpan.FromHours(4);
            var e1 = s1 + FirstBreak;
            if (e1 < end)
            {
                breaks.Add(NewBreak("Mittagspause", s1, e1));
                var s2 = e1 + TimeSpan.FromHours(2);
                var e2 = s2 + SecondBreak;
                if (e2 < end) breaks.Add(NewBreak("Kurzpause", s2, e2));
            }
        }
        else if (totalWork >= MinWorkFirstBreak)
        {
            var s = start + TimeSpan.FromHours(4);
            var e = s + FirstBreak;
            if (e < end) breaks.Add(NewBreak("Mittagspause", s, e));
        }

        return breaks;
    }

    private static List<BreakDto> AdjustExisting(
        DateTimeOffset start, DateTimeOffset end, TimeSpan totalWork, IReadOnlyList<BreakDto> existing)
    {
        var required = RequiredFor(totalWork);
        var actual = TotalBreak(existing);
        if (actual >= required) return existing.ToList();

        var missing = required - actual;
        var result = existing.Where(b => !b.IsAutomatic).ToList();

        var lastEnd = existing.Where(b => b.End is not null)
                              .OrderByDescending(b => b.End!.Value)
                              .Select(b => (DateTimeOffset?)b.End!.Value)
                              .FirstOrDefault();
        var autoStart = lastEnd is not null
            ? lastEnd.Value + TimeSpan.FromHours(1)
            : start + TimeSpan.FromHours(4);
        var autoEnd = autoStart + missing;

        if (autoEnd < end) result.Add(NewBreak("Automatische Pause", autoStart, autoEnd));
        return result;
    }

    private static BreakDto NewBreak(string name, DateTimeOffset start, DateTimeOffset end) => new()
    {
        Id = Guid.NewGuid().ToString(),
        Name = name,
        IsAutomatic = true,
        Start = start,
        End = end,
    };
}
