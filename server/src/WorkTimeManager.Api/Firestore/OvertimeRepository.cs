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

    /// <summary>
    /// Baut das Merge-Update für <c>balance</c>. Standard: <c>minutes</c> + <c>lastUpdated = now</c>.
    /// Mit <paramref name="keepLastUpdated"/> nur <c>minutes</c> (#406).
    /// </summary>
    public static Dictionary<string, object> BuildUpdate(int minutes, bool keepLastUpdated, DateTimeOffset now)
    {
        var update = new Dictionary<string, object> { ["minutes"] = minutes };
        if (!keepLastUpdated)
            update["lastUpdated"] = Timestamp.FromDateTimeOffset(now);
        return update;
    }

    public async Task SaveAsync(
        string uid, int minutes, string? profileId, CancellationToken ct, bool keepLastUpdated = false)
    {
        var update = BuildUpdate(minutes, keepLastUpdated, DateTimeOffset.UtcNow);
        await BalanceDoc(uid, profileId).SetAsync(update, SetOptions.MergeAll, ct);
    }
}
