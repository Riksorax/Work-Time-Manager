namespace WorkTimeManager.Api.Contracts;

/// <summary>Tagesstatistik. Alle Zeitwerte in Millisekunden.</summary>
public sealed record DailyStatDto
{
    public long TargetMs { get; init; }
    public long WorkedMs { get; init; }
    public long OvertimeMs { get; init; }
}

/// <summary>
/// Tag im Wochen-/Monatsbericht. <c>WorkedMs</c> ist brutto (Start bis Ende; Urlaub/Krank/Feiertag mit dem Tagessoll),
/// <c>NetWorkedMs</c> = brutto − abgeschlossene Pausen des Tages (#551), nicht bei 0 gekappt, also immer ≤ <c>WorkedMs</c>.
/// </summary>
public sealed record ReportDayDto(DateTimeOffset Date, long WorkedMs, long NetWorkedMs = 0);

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

/// <summary>Woche im Monatsbericht: <c>TotalWorkedMs</c> brutto, <c>NetWorkedMs</c> ohne Pausen (#551, nur Tage des Monats).</summary>
public sealed record ReportWeekDto(int WeekNumber, long TotalWorkedMs, long NetWorkedMs = 0);

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

    /// <summary>Immer 12 Einträge (Monat 1–12), Zählung wie die Summen (#284).</summary>
    public IReadOnlyList<YearlyLeaveMonthDto> Months { get; init; } = Array.Empty<YearlyLeaveMonthDto>();

    /// <summary>Urlaubszeiträume, aufsteigend nach Start, auf das Jahr beschnitten (#284).</summary>
    public IReadOnlyList<LeavePeriodDto> VacationPeriods { get; init; } = Array.Empty<LeavePeriodDto>();

    /// <summary>Krankheitszeiträume, aufsteigend nach Start, auf das Jahr beschnitten (#284).</summary>
    public IReadOnlyList<LeavePeriodDto> SickPeriods { get; init; } = Array.Empty<LeavePeriodDto>();
}

/// <summary>Urlaubs- und Krankheitstage eines Monats (#284).</summary>
public sealed record YearlyLeaveMonthDto(int Month, int VacationDays, int SickDays);

/// <summary>
/// Zusammenhängender Zeitraum (kalendarisch direkt aufeinander folgende Tage), <c>Start</c>/<c>End</c>
/// als Kalendertag (JSON <c>yyyy-MM-dd</c>), <c>Days</c> = Zahl der gezählten Einträge (#284).
/// </summary>
public sealed record LeavePeriodDto(DateOnly Start, DateOnly End, int Days);

/// <summary>
/// Verlauf von Arbeitszeit und Überstunden über 12 Wochen bzw. 12 Monate (#531). Alle Zeitwerte in
/// Millisekunden. Es gibt keine Historie des Gleitzeit-Saldos: <see cref="TrendBucketDto.CumulativeOvertimeMs"/>
/// summiert nur die Überstunden im Zeitfenster ab 0; der gespeicherte Saldo fließt nur in
/// <see cref="Forecast"/> ein (#532).
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

    /// <summary>
    /// Hochrechnung des Gleitzeit-Saldos zum 31.12. des Bezugsjahres (#532); bei beiden Granularitäten gesetzt und
    /// identisch. <c>null</c>, wenn in den acht abgeschlossenen ISO-Wochen vor der Woche des Bezugstags weniger als
    /// vier Wochen Einträge haben. Additiv, ältere Clients ignorieren das Feld.
    /// </summary>
    public OvertimeForecastDto? Forecast { get; init; }
}

/// <summary>
/// Überstunden-Prognose zum Jahresende (#532). Zeitwerte in Millisekunden. Geplanter Urlaub und Feiertage im Rest
/// des Jahres werden nicht gesondert berücksichtigt.
/// </summary>
public sealed record OvertimeForecastDto
{
    /// <summary>31.12. des Jahres des Bezugstags (JSON <c>yyyy-MM-dd</c>).</summary>
    public DateOnly TargetDate { get; init; }

    /// <summary>Gespeicherter Gleitzeit-Saldo (<c>overtime/balance</c>, Minuten × 60 000).</summary>
    public long CurrentBalanceMs { get; init; }

    /// <summary>
    /// Mittel der Wochen-Überstunden (<c>OvertimeMs</c> wie im Wochenbericht, inkl. manueller Überstunden) über die
    /// eingerechneten Wochen; nur zur Anzeige kaufmännisch auf ganze Millisekunden gerundet (.5 von der Null weg).
    /// </summary>
    public long AverageWeeklyOvertimeMs { get; init; }

    /// <summary>Zahl der eingerechneten Wochen mit Einträgen (4–8) aus den acht Wochen vor der Woche des Bezugstags.</summary>
    public int WeeksUsed { get; init; }

    /// <summary>Kalendertage nach dem Bezugstag bis einschließlich 31.12., geteilt durch 7, nicht gerundet (am 31.12. 0).</summary>
    public double RemainingWeeks { get; init; }

    /// <summary>
    /// <see cref="CurrentBalanceMs"/> + Mittel × <see cref="RemainingWeeks"/>. Gerechnet mit dem <b>ungerundeten</b>
    /// Mittel (nicht mit <see cref="AverageWeeklyOvertimeMs"/>), erst das Ergebnis wird kaufmännisch auf ganze
    /// Millisekunden gerundet (.5 von der Null weg).
    /// </summary>
    public long ProjectedBalanceMs { get; init; }
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

/// <summary>
/// Home-Office-Auswertung eines Kalenderjahres (#537, Regel 1:1 aus Mobile <c>calculateHomeOfficeStats</c>, #282).
/// Gezählt werden Kalendertage mit Arbeitseintrag mit Start (<c>type == work</c>, <c>workStart</c> gesetzt; offene
/// Einträge zählen). Urlaub, Krank und Feiertag zählen nie, auch mit gesetztem Flag. Mehrere Einträge an einem Tag
/// zählen einmal; der Tag ist Home-Office, wenn irgendein Eintrag das Flag trägt.
/// </summary>
public sealed record HomeOfficeReportDto
{
    public int Year { get; init; }

    /// <summary>Tage mit erfasster Zeit und Home-Office-Flag.</summary>
    public int HomeOfficeDays { get; init; }

    /// <summary>Tage mit erfasster Zeit ohne Home-Office-Flag.</summary>
    public int OfficeDays { get; init; }

    /// <summary>Bezugstage: <see cref="HomeOfficeDays"/> + <see cref="OfficeDays"/>.</summary>
    public int TotalDays { get; init; }

    /// <summary>Anteil 0..1 (<c>HomeOfficeDays ÷ TotalDays</c>, ungerundet); <c>null</c> ohne Bezugstage.</summary>
    public double? HomeOfficeRatio { get; init; }

    /// <summary>Immer 12 Einträge (Monat 1–12); die Summen der Monate ergeben die Jahreswerte.</summary>
    public IReadOnlyList<HomeOfficeMonthDto> Months { get; init; } = Array.Empty<HomeOfficeMonthDto>();

    /// <summary>Home-Office-Tage als Kalendertage <c>yyyy-MM-dd</c>, aufsteigend, ohne Duplikate.</summary>
    public IReadOnlyList<DateOnly> HomeOfficeDates { get; init; } = Array.Empty<DateOnly>();
}

/// <summary>Home-Office-Werte eines Monats (#537), Regel wie <see cref="HomeOfficeReportDto"/>.</summary>
public sealed record HomeOfficeMonthDto(int Month, int HomeOfficeDays, int OfficeDays, int TotalDays, double? HomeOfficeRatio);

/// <summary>
/// Arbeitszeit-Insights (#537, Regeln 1:1 aus Mobile <c>insights_utils.dart</c>/<c>InsightsViewModel</c>, #134).
/// Datenbasis: die drei Kalendermonate bis einschließlich des Monats des Bezugstags, jeweils ganz. Zeitwerte in ms.
/// </summary>
public sealed record InsightsReportDto
{
    /// <summary>Erster Tag des Zeitfensters (1. des Monats zwei Monate vor dem Bezugsmonat).</summary>
    public DateOnly From { get; init; }

    /// <summary>Letzter Tag des Zeitfensters (Monatsletzter des Bezugsmonats).</summary>
    public DateOnly To { get; init; }

    /// <summary>Die übergebene IANA-Zeitzone (bestimmt die Startstunde der Heatmap).</summary>
    public required string TimeZone { get; init; }

    /// <summary>Tagessoll (Regel der Berichte, auf die Minute gerundet, #535); Bezug für Streak und Heatmap.</summary>
    public long DailyTargetMs { get; init; }

    /// <summary>Nur Wochentage mit Daten, aufsteigend (1 = Mo … 7 = So).</summary>
    public IReadOnlyList<WeekdayAverageDto> WeekdayAverages { get; init; } = Array.Empty<WeekdayAverageDto>();

    public required OvertimeStreakDto OvertimeStreak { get; init; }

    /// <summary>Nur Startstunden mit mindestens 2 Einträgen, aufsteigend nach Stunde.</summary>
    public IReadOnlyList<StartTimeBucketDto> StartTimeHeatmap { get; init; } = Array.Empty<StartTimeBucketDto>();
}

/// <summary>
/// Durchschnittliche effektive Arbeitszeit eines Wochentags (#537). <c>DeviationMs</c> = Durchschnitt des Wochentags −
/// Durchschnitt aller eingerechneten Einträge (kann negativ sein). Gerechnet in Mikrosekunden mit Abschneiden zur Null
/// hin, dann auf ganze ms abgeschnitten (wie Dart <c>Duration ~/</c> und <c>inMilliseconds</c>).
/// </summary>
public sealed record WeekdayAverageDto(int Weekday, long AverageWorkedMs, long DeviationMs, int SampleCount);

/// <summary>
/// Serie aufeinanderfolgender Vertrags-Arbeitstage mit effektiver Zeit über dem Tagessoll (#537). Freie Wochentage
/// unterbrechen nicht; <c>CurrentStreak</c> endet am letzten Tag mit Arbeitseintrag im Zeitfenster.
/// </summary>
public sealed record OvertimeStreakDto(int CurrentStreak, int LongestStreak, bool IsWarning, int WarningThresholdDays);

/// <summary>Durchschnittliche Abweichung vom Tagessoll für Einträge, die in dieser lokalen Stunde begannen (#537).</summary>
public sealed record StartTimeBucketDto(int StartHour, long AverageOvertimeMs, int SampleCount);
