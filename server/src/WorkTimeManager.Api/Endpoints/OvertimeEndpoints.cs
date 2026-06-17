using System.Security.Claims;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Endpoints;

internal static class OvertimeEndpoints
{
    public sealed record SaveOvertimeRequest(int Minutes);

    public static RouteGroupBuilder MapOvertimeEndpoints(this RouteGroupBuilder group)
    {
        var overtime = group.MapGroup("/overtime").WithTags("Overtime");

        overtime.MapGet("/", async (
            ClaimsPrincipal user, OvertimeRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            return Results.Ok(await repo.GetAsync(uid, ct));
        })
        .WithName("GetOvertime");

        overtime.MapPut("/", async (
            SaveOvertimeRequest request, ClaimsPrincipal user, OvertimeRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            await repo.SaveAsync(uid, request.Minutes, ct);
            return Results.Ok(await repo.GetAsync(uid, ct));
        })
        .WithName("SaveOvertime");

        return group;
    }
}
