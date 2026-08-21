using Google.Cloud.Firestore;

namespace WorkTimeManager.Api.Firestore.Documents;

/// <summary>Ein einzelner Tageseintrag innerhalb der <see cref="MonthDocument.Days"/>-Map.</summary>
[FirestoreData]
public sealed class DayData
{
    [FirestoreProperty("date")]
    public Timestamp Date { get; set; }

    [FirestoreProperty("workStart")]
    public Timestamp? WorkStart { get; set; }

    [FirestoreProperty("workEnd")]
    public Timestamp? WorkEnd { get; set; }

    [FirestoreProperty("type")]
    public string Type { get; set; } = "work";

    [FirestoreProperty("isManuallyEntered")]
    public bool IsManuallyEntered { get; set; }

    [FirestoreProperty("manualOvertimeMinutes")]
    public int? ManualOvertimeMinutes { get; set; }

    [FirestoreProperty("description")]
    public string? Description { get; set; }

    [FirestoreProperty("breaks")]
    public List<BreakData> Breaks { get; set; } = new();
}
