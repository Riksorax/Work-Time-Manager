using Google.Cloud.Firestore;
using WorkTimeManager.Api.Contracts;

namespace WorkTimeManager.Api.Firestore;

/// <summary>Zugriff auf das Benutzer-Profildokument <c>users/{uid}</c> (Premium-Flag).</summary>
public sealed class ProfileRepository(FirestoreDb db)
{
    private DocumentReference UserDoc(string uid) =>
        db.Collection("users").Document(uid);

    public async Task<ProfileDto> GetAsync(string uid, CancellationToken ct)
    {
        var snapshot = await UserDoc(uid).GetSnapshotAsync(ct);
        var isPremium = snapshot.Exists
            && snapshot.TryGetValue<bool>("isPremium", out var premium)
            && premium;

        return new ProfileDto { Uid = uid, IsPremium = isPremium };
    }
}
