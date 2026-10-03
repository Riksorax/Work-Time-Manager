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
            : new SettingsDto { VacationDaysPerYear = SettingsDto.DefaultVacationDaysPerYear };
    }

    public async Task SaveAsync(string uid, SettingsDto settings, string? profileId, CancellationToken ct)
    {
        var doc = SettingsDoc(uid, profileId);
        var document = FirestoreMappings.ToDocument(settings);
        var options = SetOptions.MergeFields(FirestoreMappings.SettingsMergeFields(settings));

        if (!FirestoreMappings.IsBundeslandDelete(settings))
        {
            await doc.SetAsync(document, options, ct);
            return;
        }

        // bundesland "" = Feld entfernen (#279): MergeFields würde sonst null schreiben.
        var batch = db.StartBatch();
        batch.Set(doc, document, options);
        batch.Update(doc, new Dictionary<string, object> { ["bundesland"] = FieldValue.Delete });
        await batch.CommitAsync(ct);
    }
}
