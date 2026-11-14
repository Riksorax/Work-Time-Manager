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

    /// <summary>Gespeicherter Gleitzeit-Saldo (#535); enthält den laufenden Monat schon, wird nicht mit <see cref="MonthlyOvertimeMs"/> addiert.</summary>
    public long TotalOvertimeMs { get; init; }
    public IReadOnlyList<ReportWeekDto> Weeks { get; init; } = Array.Empty<ReportWeekDto>();
    public IReadOnlyList<ReportDayDto> Days { get; init; } = Array.Empty<ReportDayDto>();
}

/// <summary>Jahresauswertung Urlaub/Krank (#278). Rest darf negativ sein (Überschreitung).</summary>
public sealed record YearlyLeaveReportDto
{
    public int Year { get; init; }
    public int VacationDaysPerYear { get; init; }
    public int VacationDaysTaken { get; init; }
    public int VacationDaysRemaining { get; init; }
    public int SickDays { get; init; }
}

/// <summary>
/// Verlauf von Arbeitszeit und Überstunden über 12 Wochen bzw. 12 Monate (#531). Alle Zeitwerte in
/// Millisekunden. Es gibt keine Historie des Gleitzeit-Saldos: <see cref="TrendBucketDto.CumulativeOvertimeMs"/>
/// summiert nur die Überstunden im Zeitfenster ab 0, der gespeicherte Saldo fließt nirgends ein.
/// </summary>
public sealed record TrendReportDto
{
    /// <summary><c>week</c> oder <c>month</c>.</summary>
    public required string Granularity { get; init; }

    /// <summary>Immer genau 12 Buckets, älteste zuerst; der letzte enthält den Bezugstag (ggf. unvollständig).</summary>
    public IReadOnlyList<TrendBucketDto> Buckets { get; init; } = Array.Empty<TrendBucketDto>();

    /// <summary>
    /// Letzte abgeschlossene ISO-Woche gegen die vier Wochen davor; bei beiden Granularitäten gesetzt.
    /// <c>null</c>, wenn die letzte Woche keine Einträge hat oder weniger als zwei Vergleichswochen Einträge haben.
    /// </summary>
    public WeeklyTrendDto? WeeklyTrend { get; init; }
}

/// <summary>
/// Eine Woche (Mo–So) oder ein Kalendermonat im Trend (#531). Rechenregel wie Wochen- bzw. Monatsbericht
/// für denselben Zeitraum.
/// </summary>
public sealed record TrendBucketDto
{
    /// <summary>Woche: ISO-Wochenjahr + KW (<c>yyyy-Www</c>, z. B. <c>2026-W01</c>); Monat: <c>yyyy-MM</c>.</summary>
    public required string Key { get; init; }

    /// <summary>UTC-Mitternacht des ersten Kalendertags (Montag bzw. Monatserster).</summary>
    public DateTimeOffset Start { get; init; }

    /// <summary>UTC-Mitternacht des letzten Kalendertags (Sonntag bzw. Monatsletzter).</summary>
    public DateTimeOffset End { get; init; }

    /// <summary>
    /// <b>Netto</b>-Arbeitszeit: Brutto − Pausen, Urlaub/Krank/Feiertag mit dem Tagessoll. Entspricht
    /// <c>TotalWorkedMs − TotalBreaksMs</c> des Wochen- bzw. Monatsberichts (dort ist <c>TotalWorkedMs</c> brutto).
    /// </summary>
    public long WorkedMs { get; init; }

    /// <summary>
    /// Soll: (Tage mit Arbeit an einem Vertrags-Wochentag und jeder Tag mit Urlaub/Krank/Feiertag, #535) × Tagessoll
    /// (Regel der Berichte).
    /// </summary>
    public long TargetMs { get; init; }

    /// <summary>
    /// Überstunden des Zeitraums inkl. manueller Überstunden; Woche = <c>WeeklyReportDto.OvertimeMs</c>,
    /// Monat = <c>MonthlyReportDto.MonthlyOvertimeMs</c> (ohne gespeicherten Saldo).
    /// </summary>
    public long OvertimeMs { get; init; }

    /// <summary>Laufende Summe von <see cref="OvertimeMs"/> über die Buckets ab 0; der erste trägt seinen eigenen Wert.</summary>
    public long CumulativeOvertimeMs { get; init; }

    /// <summary><c>false</c>, wenn im Zeitraum kein Eintrag existiert (dann sind Ist, Soll und Überstunden 0).</summary>
    public bool HasData { get; init; }
}

/// <summary>Kennzahl „Wochen-Trend“ (#531). Zeitwerte netto in Millisekunden.</summary>
public sealed record WeeklyTrendDto
{
    /// <summary>ISO-Woche vor der Woche des Bezugstags (<c>yyyy-Www</c>).</summary>
    public required string LastWeekKey { get; init; }

    /// <summary>Netto-Arbeitszeit der letzten abgeschlossenen Woche.</summary>
    public long LastWeekWorkedMs { get; init; }

    /// <summary>
    /// Mittel der Netto-Arbeitszeit der vier Wochen vor der letzten Woche, nur Wochen mit Einträgen; auf ganze
    /// Millisekunden kaufmännisch gerundet (.5 von der Null weg, <c>MidpointRounding.AwayFromZero</c>).
    /// </summary>
    public long AverageWorkedMs { get; init; }

    /// <summary><see cref="LastWeekWorkedMs"/> − <see cref="AverageWorkedMs"/>.</summary>
    public long DeltaMs { get; init; }

    /// <summary>Anzahl der eingerechneten Vergleichswochen (2–4).</summary>
    public int ComparedWeeks { get; init; }
}

/// <summary>
/// Jahresvergleich mit dem Vorjahr (#530). Beide Jahre rechnen nach der Regel des Monatsberichts (je Monat,
/// dann summiert) mit den heutigen Einstellungen. Alle Zeitwerte in Millisekunden. Der gespeicherte
/// Gleitzeit-Saldo fließt nirgends ein.
/// </summary>
public sealed record YearlyComparisonDto
{
    /// <summary>
    /// Stichtag <c>MM-dd</c> wie übergeben (in beiden Jahren zählen nur Einträge bis einschließlich dieses Tags);
    /// <c>null</c> = ganzes Jahr.
    /// </summary>
    public string? Until { get; init; }

    /// <summary>Das angefragte Jahr.</summary>
    public required YearlySummaryDto Current { get; init; }

    /// <summary>Das Vorjahr, mit demselben Stichtag abgeschnitten.</summary>
    public required YearlySummaryDto Previous { get; init; }

    /// <summary><see cref="Current"/> − <see cref="Previous"/> je Feld; <c>null</c>, wenn das Vorjahr keine Einträge hat.</summary>
    public YearlyDeltaDto? Delta { get; init; }
}

/// <summary>Kennzahlen eines (ggf. bis zum Stichtag abgeschnittenen) Kalenderjahres (#530).</summary>
public sealed record YearlySummaryDto
{
    public int Year { get; init; }

    /// <summary><c>false</c>, wenn im (abgeschnittenen) Jahr kein Eintrag existiert; dann sind alle Werte 0.</summary>
    public bool HasData { get; init; }

    /// <summary>
    /// <b>Netto</b>-Arbeitszeit: Brutto − Pausen, Urlaub/Krank/Feiertag mit dem Tagessoll. Summe der
    /// <c>TotalWorkedMs − TotalBreaksMs</c> der Monatsberichte (dort ist <c>TotalWorkedMs</c> brutto).
    /// </summary>
    public long TotalWorkedMs { get; init; }

    /// <summary>Summe der Pausen (= Summe der <c>TotalBreaksMs</c> der Monatsberichte).</summary>
    public long TotalBreaksMs { get; init; }

    /// <summary>Summe der <c>MonthlyOvertimeMs</c> der 12 Monate (inkl. manueller Überstunden, ohne gespeicherten Saldo).</summary>
    public long OvertimeMs { get; init; }

    /// <summary>Summe der <c>WorkDays</c> der Monatsberichte.</summary>
    public int WorkDays { get; init; }

    /// <summary>Einträge vom Typ <c>vacation</c> (ein Eintrag = ein Tag, auch am Wochenende; Regel wie <c>/reports/yearly</c>).</summary>
    public int VacationDays { get; init; }

    /// <summary>Einträge vom Typ <c>sick</c> (Zählregel wie <see cref="VacationDays"/>).</summary>
    public int SickDays { get; init; }

    /// <summary>Einträge vom Typ <c>holiday</c> (Zählregel wie <see cref="VacationDays"/>).</summary>
    public int HolidayDays { get; init; }

    /// <summary>Immer 12 Einträge (Monat 1–12); Monate nach dem Stichtag sind 0, der Stichtag-Monat zählt nur bis zum Tag.</summary>
    public IReadOnlyList<YearlySummaryMonthDto> Months { get; init; } = Array.Empty<YearlySummaryMonthDto>();
}

/// <summary>Ein Monat im Jahresvergleich (#530); Regel wie der Monatsbericht für denselben Monat.</summary>
public sealed record YearlySummaryMonthDto
{
    /// <summary>1–12.</summary>
    public int Month { get; init; }

    /// <summary><b>Netto</b>-Arbeitszeit des Monats (= <c>TotalWorkedMs − TotalBreaksMs</c> des Monatsberichts).</summary>
    public long WorkedMs { get; init; }

    /// <summary><c>MonthlyOvertimeMs</c> des Monatsberichts (inkl. manueller Überstunden, ohne Saldo).</summary>
    public long OvertimeMs { get; init; }

    /// <summary><c>WorkDays</c> des Monatsberichts.</summary>
    public int WorkDays { get; init; }
}

/// <summary>Differenz aktuelles Jahr − Vorjahr je Feld (#530).</summary>
public sealed record YearlyDeltaDto
{
    /// <summary>Differenz der Netto-Arbeitszeit.</summary>
    public long WorkedMs { get; init; }

    /// <summary>
    /// <see cref="WorkedMs"/> ÷ Netto-Arbeitszeit des Vorjahres × 100, kaufmännisch auf eine Nachkommastelle gerundet
    /// (.5 von der Null weg); <c>null</c>, wenn die Netto-Arbeitszeit des Vorjahres 0 ist.
    /// </summary>
    public double? WorkedPercent { get; init; }

    public long OvertimeMs { get; init; }
    public int WorkDays { get; init; }
    public int VacationDays { get; init; }
    public int SickDays { get; init; }
    public int HolidayDays { get; init; }
}
