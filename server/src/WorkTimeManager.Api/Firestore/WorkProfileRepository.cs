using Google.Cloud.Firestore;
using WorkTimeManager.Api.Contracts;

namespace WorkTimeManager.Api.Firestore;

/// <summary>
/// Verwaltung zusätzlicher Arbeitszeit-Profile unter <c>users/{uid}/profiles/{profileId}</c>
/// (siehe #138/#239). Das Standard-Profil ist hier nicht enthalten - es ist implizit immer
/// vorhanden und wird clientseitig ergänzt (Flutter-kompatibel, siehe mobile
/// <c>WorkProfileRepositoryImpl</c>).
/// </summary>
public sealed class WorkProfileRepository(FirestoreDb db)
{
    private CollectionReference ProfilesCollection(string uid) =>
        db.Collection("users").Document(uid).Collection("profiles");

    public async Task<IReadOnlyList<WorkProfileDto>> GetAllAsync(string uid, CancellationToken ct)
    {
        var snapshot = await ProfilesCollection(uid).GetSnapshotAsync(ct);
        return snapshot.Documents
            .Select(doc => new WorkProfileDto
            {
                Id = doc.Id,
                Name = doc.TryGetValue<string>("name", out var name) ? name : "Profil",
            })
            .ToList();
    }

    public async Task<WorkProfileDto> AddAsync(string uid, string name, CancellationToken ct)
    {
        var data = new Dictionary<string, object>
        {
            ["name"] = name,
            ["createdAt"] = Timestamp.FromDateTimeOffset(DateTimeOffset.UtcNow),
        };
        var docRef = await ProfilesCollection(uid).AddAsync(data, ct);
        return new WorkProfileDto { Id = docRef.Id, Name = name };
    }

    /// <summary>Löscht ein Profil unwiderruflich inkl. aller zugehörigen Arbeitseinträge,
    /// Überstunden und Einstellungen - analog zur mobilen <c>deleteWorkProfile</c>-Methode.</summary>
    public async Task DeleteAsync(string uid, string profileId, CancellationToken ct)
    {
        var profileDoc = ProfilesCollection(uid).Document(profileId);
        var batch = db.StartBatch();

        foreach (var collection in new[] { "work_entries", "overtime", "settings" })
        {
            var snapshot = await profileDoc.Collection(collection).GetSnapshotAsync(ct);
            foreach (var doc in snapshot.Documents)
            {
                batch.Delete(doc.Reference);
            }
        }

        batch.Delete(profileDoc);
        await batch.CommitAsync(ct);
    }
}
