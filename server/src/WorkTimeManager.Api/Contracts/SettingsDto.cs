namespace WorkTimeManager.Api.Contracts;

/// <summary>Benutzereinstellungen (Arbeitszeit-Soll, Benachrichtigungen).</summary>
public sealed record SettingsDto
{
    public double WeeklyTargetHours { get; init; } = 40;

    /// <summary>Konkrete Arbeitstage als ISO-Wochentage (1 = Montag, 7 = Sonntag). Siehe #217.</summary>
    public IReadOnlyList<int> Workdays { get; init; } = new[] { 1, 2, 3, 4, 5 };
    public bool NotificationsEnabled { get; init; }
    public string NotificationTime { get; init; } = "08:00";
    public IReadOnlyList<int> NotificationDays { get; init; } = new[] { 1, 2, 3, 4, 5 };
    public bool NotifyWorkStart { get; init; }
    public bool NotifyWorkEnd { get; init; }
    public bool NotifyBreaks { get; init; }

    /// <summary>Standard-Urlaubsanspruch, wenn das Feld nie gesetzt wurde (#278).</summary>
    public const int DefaultVacationDaysPerYear = 30;

    /// <summary>
    /// Urlaubsanspruch in ganzen Tagen pro Jahr (0-366, #278). Im GET immer gesetzt (fehlt das
    /// Feld im Dokument: 30). Im PUT optional: <c>null</c> (alte Clients) lässt den gespeicherten
    /// Wert unangetastet.
    /// </summary>
    public int? VacationDaysPerYear { get; init; }

    /// <summary>
    /// Bundesland für Feiertage (#279), Dart-Enum-Name (z. B. <c>nordrheinWestfalen</c>). Im GET der
    /// Wert oder <c>null</c> (nicht ausgewählt). Im PUT: <c>null</c>/fehlend lässt den gespeicherten
    /// Wert unangetastet, <c>""</c> löscht das Feld, ein ungültiger Wert ergibt 400.
    /// </summary>
    public string? Bundesland { get; init; }
}
