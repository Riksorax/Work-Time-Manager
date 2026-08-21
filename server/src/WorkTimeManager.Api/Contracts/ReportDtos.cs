namespace WorkTimeManager.Api.Contracts;

/// <summary>Tagesstatistik. Alle Zeitwerte in Millisekunden.</summary>
public sealed record DailyStatDto
{
    public long TargetMs { get; init; }
    public long WorkedMs { get; init; }
    public long OvertimeMs { get; init; }
}

public sealed record ReportDayDto(DateTimeOffset Date, long WorkedMs);

public sealed record WeeklyReportDto
{
    public int WeekNumber { get; init; }
    public DateTimeOffset Start { get; init; }
    public DateTimeOffset End { get; init; }
    public long TotalWorkedMs { get; init; }
    public long TotalBreaksMs { get; init; }
    public int WorkDays { get; init; }
    public double AvgPerDayMs { get; init; }
    public long OvertimeMs { get; init; }
    public IReadOnlyList<ReportDayDto> Days { get; init; } = Array.Empty<ReportDayDto>();
}

public sealed record ReportWeekDto(int WeekNumber, long TotalWorkedMs);

public sealed record MonthlyReportDto
{
    public DateTimeOffset Month { get; init; }
    public long TotalWorkedMs { get; init; }
    public long TotalBreaksMs { get; init; }
    public int WorkDays { get; init; }
    public double AvgPerDayMs { get; init; }
    public double AvgPerWeekMs { get; init; }
    public long MonthlyOvertimeMs { get; init; }
    public long TotalOvertimeMs { get; init; }
    public IReadOnlyList<ReportWeekDto> Weeks { get; init; } = Array.Empty<ReportWeekDto>();
    public IReadOnlyList<ReportDayDto> Days { get; init; } = Array.Empty<ReportDayDto>();
}
