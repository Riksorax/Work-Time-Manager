namespace WorkTimeManager.Api.Contracts;

/// <summary>API-Repräsentation eines Tageseintrags. Datumsangaben als ISO-8601 (UTC).</summary>
public sealed record WorkEntryDto
{
    /// <summary>Eintrags-ID im Format <c>yyyy-MM-dd</c>.</summary>
    public required string Id { get; init; }
    public required DateTimeOffset Date { get; init; }
    public DateTimeOffset? WorkStart { get; init; }
    public DateTimeOffset? WorkEnd { get; init; }
    public string Type { get; init; } = "work";
    public bool IsManuallyEntered { get; init; }
    public int? ManualOvertimeMinutes { get; init; }
    public string? Description { get; init; }

    /// <summary>
    /// Home-Office-Tag (#277). GET liefert immer <c>true</c>/<c>false</c>. Im PUT bedeutet
    /// <c>null</c>/fehlend (alte Clients): gespeicherten Wert nicht anfassen.
    /// </summary>
    public bool? IsHomeOffice { get; init; }

    public IReadOnlyList<BreakDto> Breaks { get; init; } = Array.Empty<BreakDto>();
}

/// <summary>API-Repräsentation einer Pause.</summary>
public sealed record BreakDto
{
    public required string Id { get; init; }
    public string Name { get; init; } = "Pause";
    public bool IsAutomatic { get; init; }
    public required DateTimeOffset Start { get; init; }
    public DateTimeOffset? End { get; init; }
}
