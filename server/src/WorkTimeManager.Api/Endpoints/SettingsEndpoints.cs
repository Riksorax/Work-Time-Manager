using System.Security.Claims;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Endpoints;

internal static class SettingsEndpoints
{
    public static RouteGroupBuilder MapSettingsEndpoints(this RouteGroupBuilder group)
    {
        var settings = group.MapGroup("/settings").WithTags("Settings");

        settings.MapGet("/", async (
            string? profileId, ClaimsPrincipal user, SettingsRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            return Results.Ok(await repo.GetAsync(uid, profileId, ct));
        })
        .WithName("GetSettings");

        settings.MapPut("/", async (
            SettingsDto dto, string? profileId,
            ClaimsPrincipal user, SettingsRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            await repo.SaveAsync(uid, dto, profileId, ct);
            return Results.Ok(await repo.GetAsync(uid, profileId, ct));
        })
        .WithName("SaveSettings");

        return group;
    }
}
