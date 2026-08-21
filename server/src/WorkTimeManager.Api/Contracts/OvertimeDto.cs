namespace WorkTimeManager.Api.Contracts;

/// <summary>Gleitzeit-Saldo. <see cref="Minutes"/> kann negativ sein (Minusstunden).</summary>
public sealed record OvertimeDto
{
    public int Minutes { get; init; }
    public DateTimeOffset? LastUpdated { get; init; }
}
