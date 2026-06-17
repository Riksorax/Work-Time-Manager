using Google.Cloud.Firestore;

namespace WorkTimeManager.Api.Firestore.Documents;

/// <summary>Firestore-Dokument <c>users/{uid}/overtime/balance</c>.</summary>
[FirestoreData]
public sealed class OvertimeDocument
{
    [FirestoreProperty("minutes")]
    public int Minutes { get; set; }

    [FirestoreProperty("lastUpdated")]
    public Timestamp? LastUpdated { get; set; }
}
