using Google.Cloud.Firestore;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore.Documents;

namespace WorkTimeManager.Api.Firestore;

/// <summary>Zugriff auf <c>users/{uid}/settings/current</c>.</summary>
public sealed class SettingsRepository(FirestoreDb db)
{
    private DocumentReference SettingsDoc(string uid, string? profileId) =>
        ProfileScope.Collection(db, uid, "settings", profileId).Document("current");

    public async Task<SettingsDto> GetAsync(string uid, string? profileId, CancellationToken ct)
    {
        var snapshot = await SettingsDoc(uid, profileId).GetSnapshotAsync(ct);
        return snapshot.Exists
            ? FirestoreMappings.ToDto(snapshot.ConvertTo<SettingsDocument>())
            : new SettingsDto();
    }

    public async Task SaveAsync(string uid, SettingsDto settings, string? profileId, CancellationToken ct)
    {
        await SettingsDoc(uid, profileId).SetAsync(FirestoreMappings.ToDocument(settings), SetOptions.MergeAll, ct);
    }
}
