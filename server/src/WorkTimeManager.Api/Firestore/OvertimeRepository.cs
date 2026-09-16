using Google.Cloud.Firestore;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore.Documents;

namespace WorkTimeManager.Api.Firestore;

/// <summary>Zugriff auf <c>users/{uid}/overtime/balance</c>.</summary>
public sealed class OvertimeRepository(FirestoreDb db)
{
    private DocumentReference BalanceDoc(string uid, string? profileId) =>
        ProfileScope.Collection(db, uid, "overtime", profileId).Document("balance");

    public async Task<OvertimeDto> GetAsync(string uid, string? profileId, CancellationToken ct)
    {
        var snapshot = await BalanceDoc(uid, profileId).GetSnapshotAsync(ct);
        return snapshot.Exists
            ? FirestoreMappings.ToDto(snapshot.ConvertTo<OvertimeDocument>())
            : new OvertimeDto { Minutes = 0 };
    }

    public async Task SaveAsync(string uid, int minutes, string? profileId, CancellationToken ct)
    {
        var update = new Dictionary<string, object>
        {
            ["minutes"] = minutes,
            ["lastUpdated"] = Timestamp.FromDateTimeOffset(DateTimeOffset.UtcNow),
        };
        await BalanceDoc(uid, profileId).SetAsync(update, SetOptions.MergeAll, ct);
    }
}
