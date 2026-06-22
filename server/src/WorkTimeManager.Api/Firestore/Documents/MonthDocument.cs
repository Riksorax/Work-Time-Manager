using Google.Cloud.Firestore;

namespace WorkTimeManager.Api.Firestore.Documents;

/// <summary>
/// Firestore-Dokument <c>users/{uid}/work_entries/{yyyy-MM}</c>.
/// Die Tage werden als Map abgelegt, Schlüssel ist der Tag ohne führende Null ("5"),
/// identisch zum Flutter-/Web-Format.
/// </summary>
[FirestoreData]
public sealed class MonthDocument
{
    [FirestoreProperty("days")]
    public Dictionary<string, DayData> Days { get; set; } = new();
}
