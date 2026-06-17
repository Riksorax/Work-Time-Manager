using Google.Cloud.Firestore;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore.Documents;

namespace WorkTimeManager.Api.Firestore;

/// <summary>Zugriff auf <c>users/{uid}/settings/current</c>.</summary>
public sealed class SettingsRepository(FirestoreDb db)
{
    private DocumentReference SettingsDoc(string uid) =>
        db.Collection("users").Document(uid).Collection("settings").Document("current");

    public async Task<SettingsDto> GetAsync(string uid, CancellationToken ct)
    {
        var snapshot = await SettingsDoc(uid).GetSnapshotAsync(ct);
        return snapshot.Exists
            ? FirestoreMappings.ToDto(snapshot.ConvertTo<SettingsDocument>())
            : new SettingsDto();
    }

    public async Task SaveAsync(string uid, SettingsDto settings, CancellationToken ct)
    {
        await SettingsDoc(uid).SetAsync(FirestoreMappings.ToDocument(settings), SetOptions.MergeAll, ct);
    }
}
