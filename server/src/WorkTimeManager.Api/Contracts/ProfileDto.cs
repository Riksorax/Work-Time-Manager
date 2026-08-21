namespace WorkTimeManager.Api.Contracts;

/// <summary>Profil-/Premium-Status aus <c>users/{uid}</c>.</summary>
public sealed record ProfileDto
{
    public required string Uid { get; init; }
    public bool IsPremium { get; init; }
}
