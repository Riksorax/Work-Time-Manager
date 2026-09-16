namespace WorkTimeManager.Api.Contracts;

/// <summary>Ein zusätzliches Arbeitszeit-Profil (siehe #138/#239). Das Standard-Profil
/// (<see cref="Firestore.ProfileScope.DefaultProfileId"/>) ist hier nicht enthalten - es ist
/// implizit immer vorhanden und wird clientseitig ergänzt.</summary>
public sealed record WorkProfileDto
{
    public required string Id { get; init; }
    public required string Name { get; init; }
}
