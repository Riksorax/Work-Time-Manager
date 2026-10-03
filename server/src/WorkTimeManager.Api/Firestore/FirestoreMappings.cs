using System.Globalization;
using Google.Cloud.Firestore;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore.Documents;

namespace WorkTimeManager.Api.Firestore;

/// <summary>Konvertierung zwischen Firestore-Dokumenten und API-DTOs (Flutter-kompatibel).</summary>
internal static class FirestoreMappings
{
    // ── Work Entry ──────────────────────────────────────────────────────────

    public static WorkEntryDto ToDto(DayData day, string id) => new()
    {
        Id = id,
        Date = day.Date.ToDateTimeOffset(),
        WorkStart = day.WorkStart?.ToDateTimeOffset(),
        WorkEnd = day.WorkEnd?.ToDateTimeOffset(),
        Type = day.Type,
        IsManuallyEntered = day.IsManuallyEntered,
        ManualOvertimeMinutes = day.ManualOvertimeMinutes,
        Description = day.Description,
        Breaks = day.Breaks.Select(ToDto).ToList(),
    };

    private static BreakDto ToDto(BreakData b) => new()
    {
        Id = b.Id,
        Name = b.Name,
        IsAutomatic = b.IsAutomatic,
        Start = b.Start.ToDateTimeOffset(),
        End = b.End?.ToDateTimeOffset(),
    };

    public static DayData ToDocument(WorkEntryDto dto) => new()
    {
        Date = Timestamp.FromDateTimeOffset(dto.Date.ToUniversalTime()),
        WorkStart = ToTimestamp(dto.WorkStart),
        WorkEnd = ToTimestamp(dto.WorkEnd),
        Type = dto.Type,
        IsManuallyEntered = dto.IsManuallyEntered,
        ManualOvertimeMinutes = dto.ManualOvertimeMinutes,
        Description = dto.Description,
        Breaks = dto.Breaks.Select(ToDocument).ToList(),
    };

    private static BreakData ToDocument(BreakDto b) => new()
    {
        Id = b.Id,
        Name = b.Name,
        IsAutomatic = b.IsAutomatic,
        Start = Timestamp.FromDateTimeOffset(b.Start.ToUniversalTime()),
        End = ToTimestamp(b.End),
    };

    // ── Overtime ────────────────────────────────────────────────────────────

    public static OvertimeDto ToDto(OvertimeDocument doc) => new()
    {
        Minutes = doc.Minutes,
        LastUpdated = doc.LastUpdated?.ToDateTimeOffset(),
    };

    // ── Settings ────────────────────────────────────────────────────────────

    public static SettingsDto ToDto(SettingsDocument doc) => new()
    {
        WeeklyTargetHours = doc.WeeklyTargetHours,
        Workdays = ResolveWorkdays(doc),
        NotificationsEnabled = doc.NotificationsEnabled,
        NotificationTime = doc.NotificationTime,
        NotificationDays = doc.NotificationDays,
        NotifyWorkStart = doc.NotifyWorkStart,
        NotifyWorkEnd = doc.NotifyWorkEnd,
        NotifyBreaks = doc.NotifyBreaks,
        VacationDaysPerYear = doc.VacationDaysPerYear ?? SettingsDto.DefaultVacationDaysPerYear,
        Bundesland = IsValidBundesland(doc.Bundesland) ? NullIfEmpty(doc.Bundesland) : null,
    };

    public static SettingsDocument ToDocument(SettingsDto dto) => new()
    {
        WeeklyTargetHours = dto.WeeklyTargetHours,
        Workdays = dto.Workdays.ToList(),
        NotificationsEnabled = dto.NotificationsEnabled,
        NotificationTime = dto.NotificationTime,
        NotificationDays = dto.NotificationDays.ToList(),
        NotifyWorkStart = dto.NotifyWorkStart,
        NotifyWorkEnd = dto.NotifyWorkEnd,
        NotifyBreaks = dto.NotifyBreaks,
        VacationDaysPerYear = dto.VacationDaysPerYear,
        Bundesland = NullIfEmpty(dto.Bundesland),
    };

    /// <summary>
    /// Felder für den Merge-Schreibvorgang. Ist <c>vacationDaysPerYear</c> nicht gesetzt (alter
    /// Client), wird das Feld ausgelassen, damit ein gespeicherter Wert nicht überschrieben wird
    /// (MergeAll würde sonst <c>null</c> schreiben). Siehe #278.
    /// </summary>
    public static string[] SettingsMergeFields(SettingsDto dto)
    {
        var fields = new List<string>
        {
            "weeklyTargetHours", "workdays", "notificationsEnabled", "notificationTime",
            "notificationDays", "notifyWorkStart", "notifyWorkEnd", "notifyBreaks",
        };
        if (dto.VacationDaysPerYear is not null) fields.Add("vacationDaysPerYear");
        if (dto.Bundesland is not null) fields.Add("bundesland"); // "" = löschen (siehe IsBundeslandDelete)
        return fields.ToArray();
    }

    /// <summary>Gültiger Urlaubsanspruch: nicht gesetzt oder 0-366.</summary>
    public static bool IsValidVacationDays(int? value) => value is null or >= 0 and <= 366;

    /// <summary>Die 16 gültigen Bundesland-Werte (Dart-Enum-Namen aus <c>bundesland.dart</c>, #279).</summary>
    public static readonly IReadOnlySet<string> Bundeslaender = new HashSet<string>(StringComparer.Ordinal)
    {
        "badenWuerttemberg", "bayern", "berlin", "brandenburg", "bremen", "hamburg", "hessen",
        "mecklenburgVorpommern", "niedersachsen", "nordrheinWestfalen", "rheinlandPfalz",
        "saarland", "sachsen", "sachsenAnhalt", "schleswigHolstein", "thueringen",
    };

    /// <summary>Gültiges Bundesland: <c>null</c>, <c>""</c> (löschen) oder einer der 16 Namen (exakte Schreibweise).</summary>
    public static bool IsValidBundesland(string? value) =>
        string.IsNullOrEmpty(value) || Bundeslaender.Contains(value);

    /// <summary>PUT mit <c>bundesland: ""</c> = gespeichertes Feld entfernen (#279).</summary>
    public static bool IsBundeslandDelete(SettingsDto dto) => dto.Bundesland is "";

    private static string? NullIfEmpty(string? value) => string.IsNullOrEmpty(value) ? null : value;

    /// <summary>
    /// Migriert das alte <c>workdaysPerWeek</c>-Feld (Anzahl) in konkrete ISO-Wochentage
    /// (erste N Tage ab Montag), damit bestehende Nutzer ihr bisheriges Verhalten behalten.
    /// Siehe #217.
    /// </summary>
    private static IReadOnlyList<int> ResolveWorkdays(SettingsDocument doc)
    {
        if (doc.Workdays is { Count: > 0 }) return doc.Workdays;
        if (doc.WorkdaysPerWeek is { } count)
        {
            var clamped = Math.Clamp(count, 0, 7);
            return Enumerable.Range(1, clamped).ToList();
        }
        return new[] { 1, 2, 3, 4, 5 };
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private static Timestamp? ToTimestamp(DateTimeOffset? value) =>
        value is null ? null : Timestamp.FromDateTimeOffset(value.Value.ToUniversalTime());

    /// <summary>Tages-Schlüssel innerhalb der days-Map ("5", ohne führende Null — Flutter-Format).</summary>
    public static string DayKey(DateTimeOffset date) =>
        date.Day.ToString(CultureInfo.InvariantCulture);

    /// <summary>Eintrags-ID im Format <c>yyyy-MM-dd</c>.</summary>
    public static string EntryId(int year, int month, int day) =>
        $"{year:D4}-{month:D2}-{day:D2}";

    /// <summary>Monats-Dokument-ID im Format <c>yyyy-MM</c>.</summary>
    public static string MonthId(int year, int month) =>
        $"{year:D4}-{month:D2}";
}
