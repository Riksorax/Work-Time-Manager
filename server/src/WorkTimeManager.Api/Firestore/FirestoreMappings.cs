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
        WorkdaysPerWeek = doc.WorkdaysPerWeek,
        NotificationsEnabled = doc.NotificationsEnabled,
        NotificationTime = doc.NotificationTime,
        NotificationDays = doc.NotificationDays,
        NotifyWorkStart = doc.NotifyWorkStart,
        NotifyWorkEnd = doc.NotifyWorkEnd,
        NotifyBreaks = doc.NotifyBreaks,
    };

    public static SettingsDocument ToDocument(SettingsDto dto) => new()
    {
        WeeklyTargetHours = dto.WeeklyTargetHours,
        WorkdaysPerWeek = dto.WorkdaysPerWeek,
        NotificationsEnabled = dto.NotificationsEnabled,
        NotificationTime = dto.NotificationTime,
        NotificationDays = dto.NotificationDays.ToList(),
        NotifyWorkStart = dto.NotifyWorkStart,
        NotifyWorkEnd = dto.NotifyWorkEnd,
        NotifyBreaks = dto.NotifyBreaks,
    };

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
