using Google.Cloud.Firestore;

namespace WorkTimeManager.Api.Firestore.Documents;

/// <summary>Firestore-Dokument <c>users/{uid}/settings/current</c> (nur Web/Backend).</summary>
[FirestoreData]
public sealed class SettingsDocument
{
    [FirestoreProperty("weeklyTargetHours")]
    public double WeeklyTargetHours { get; set; } = 40;

    [FirestoreProperty("workdays")]
    public List<int>? Workdays { get; set; }

    /// <summary>Legacy-Feld (Anzahl statt konkreter Wochentage). Nur für Migration gelesen, siehe #217.</summary>
    [FirestoreProperty("workdaysPerWeek")]
    public int? WorkdaysPerWeek { get; set; }

    [FirestoreProperty("notificationsEnabled")]
    public bool NotificationsEnabled { get; set; }

    [FirestoreProperty("notificationTime")]
    public string NotificationTime { get; set; } = "08:00";

    [FirestoreProperty("notificationDays")]
    public List<int> NotificationDays { get; set; } = new() { 1, 2, 3, 4, 5 };

    [FirestoreProperty("notifyWorkStart")]
    public bool NotifyWorkStart { get; set; }

    [FirestoreProperty("notifyWorkEnd")]
    public bool NotifyWorkEnd { get; set; }

    [FirestoreProperty("notifyBreaks")]
    public bool NotifyBreaks { get; set; }
}
