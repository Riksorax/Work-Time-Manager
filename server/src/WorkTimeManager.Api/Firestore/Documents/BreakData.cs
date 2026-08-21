using Google.Cloud.Firestore;

namespace WorkTimeManager.Api.Firestore.Documents;

/// <summary>Eine Pause innerhalb eines <see cref="DayData"/>-Eintrags.</summary>
[FirestoreData]
public sealed class BreakData
{
    [FirestoreProperty("id")]
    public string Id { get; set; } = string.Empty;

    [FirestoreProperty("name")]
    public string Name { get; set; } = "Pause";

    [FirestoreProperty("isAutomatic")]
    public bool IsAutomatic { get; set; }

    [FirestoreProperty("start")]
    public Timestamp Start { get; set; }

    [FirestoreProperty("end")]
    public Timestamp? End { get; set; }
}
