using System.Security.Claims;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Endpoints;

internal static class WorkEntryEndpoints
{
    public static RouteGroupBuilder MapWorkEntryEndpoints(this RouteGroupBuilder group)
    {
        var entries = group.MapGroup("/work-entries").WithTags("Work Entries");

        entries.MapGet("/{year:int}/{month:int}", async (
            int year, int month, ClaimsPrincipal user, WorkEntryRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidMonth(year, month)) return Results.BadRequest("Ungültiger Monat.");
            return Results.Ok(await repo.GetMonthAsync(uid, year, month, ct));
        })
        .WithName("GetWorkEntriesForMonth");

        entries.MapGet("/{year:int}/{month:int}/{day:int}", async (
            int year, int month, int day, ClaimsPrincipal user, WorkEntryRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidDay(year, month, day)) return Results.BadRequest("Ungültiges Datum.");
            var entry = await repo.GetDayAsync(uid, year, month, day, ct);
            return entry is null ? Results.NotFound() : Results.Ok(entry);
        })
        .WithName("GetWorkEntry");

        entries.MapPut("/", async (
            WorkEntryDto entry, ClaimsPrincipal user, WorkEntryRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            await repo.SaveAsync(uid, entry, ct);
            return Results.Ok(entry);
        })
        .WithName("SaveWorkEntry");

        entries.MapDelete("/{year:int}/{month:int}/{day:int}", async (
            int year, int month, int day, ClaimsPrincipal user, WorkEntryRepository repo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidDay(year, month, day)) return Results.BadRequest("Ungültiges Datum.");
            await repo.DeleteAsync(uid, year, month, day, ct);
            return Results.NoContent();
        })
        .WithName("DeleteWorkEntry");

        return group;
    }

    private static bool IsValidMonth(int year, int month) =>
        year is >= 2000 and <= 2100 && month is >= 1 and <= 12;

    private static bool IsValidDay(int year, int month, int day) =>
        IsValidMonth(year, month) && day >= 1 && day <= DateTime.DaysInMonth(year, month);
}
