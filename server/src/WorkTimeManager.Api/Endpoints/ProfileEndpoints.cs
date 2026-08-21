using System.Security.Claims;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Endpoints;

internal static class ProfileEndpoints
{
    public static RouteGroupBuilder MapProfileEndpoints(this RouteGroupBuilder group)
    {
        var profile = group.MapGroup("/profile").WithTags("Profile");

        profile.MapGet("/", async (
            ClaimsPrincipal user, ProfileRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            return Results.Ok(await repo.GetAsync(uid, ct));
        })
        .WithName("GetProfile");

        return group;
    }
}
