using System.Security.Claims;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Endpoints;

internal static class WorkProfileEndpoints
{
    public sealed record CreateWorkProfileRequest(string Name);

    public static RouteGroupBuilder MapWorkProfileEndpoints(this RouteGroupBuilder group)
    {
        var profiles = group.MapGroup("/work-profiles").WithTags("Work Profiles");

        profiles.MapGet("/", async (
            ClaimsPrincipal user, WorkProfileRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            return Results.Ok(await repo.GetAllAsync(uid, ct));
        })
        .WithName("GetWorkProfiles");

        profiles.MapPost("/", async (
            CreateWorkProfileRequest request, ClaimsPrincipal user,
            WorkProfileRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (string.IsNullOrWhiteSpace(request.Name)) return Results.BadRequest("Name darf nicht leer sein.");
            return Results.Ok(await repo.AddAsync(uid, request.Name, ct));
        })
        .WithName("AddWorkProfile");

        profiles.MapDelete("/{profileId}", async (
            string profileId, ClaimsPrincipal user, WorkProfileRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            await repo.DeleteAsync(uid, profileId, ct);
            return Results.NoContent();
        })
        .WithName("DeleteWorkProfile");

        return group;
    }
}
