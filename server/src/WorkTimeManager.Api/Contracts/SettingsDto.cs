namespace WorkTimeManager.Api.Contracts;

/// <summary>Benutzereinstellungen (Arbeitszeit-Soll, Benachrichtigungen).</summary>
public sealed record SettingsDto
{
    public double WeeklyTargetHours { get; init; } = 40;
    public int WorkdaysPerWeek { get; init; } = 5;
    public bool NotificationsEnabled { get; init; }
    public string NotificationTime { get; init; } = "08:00";
    public IReadOnlyList<int> NotificationDays { get; init; } = new[] { 1, 2, 3, 4, 5 };
    public bool NotifyWorkStart { get; init; }
    public bool NotifyWorkEnd { get; init; }
    public bool NotifyBreaks { get; init; }
}
