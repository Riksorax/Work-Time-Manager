using Google.Cloud.Firestore;

namespace WorkTimeManager.Api.Firestore;

/// <summary>
/// Basis-Collection für profil-gebundene Daten (Work Entries/Overtime/Settings, siehe #239).
/// `null`/<see cref="DefaultProfileId"/> verweist auf den bestehenden, nicht migrierten Pfad
/// <c>users/{uid}/{collection}</c>; jedes andere Profil liegt unter
/// <c>users/{uid}/profiles/{profileId}/{collection}</c> — Flutter-kompatibel, siehe
/// <c>FirestoreDataSourceImpl._profileScopedDoc</c> in der Mobile-App.
/// </summary>
internal static class ProfileScope
{
    public const string DefaultProfileId = "default";

    public static CollectionReference Collection(
        FirestoreDb db, string uid, string collection, string? profileId)
    {
        var userDoc = db.Collection("users").Document(uid);
        return profileId is null or DefaultProfileId
            ? userDoc.Collection(collection)
            : userDoc.Collection("profiles").Document(profileId).Collection(collection);
    }
}
