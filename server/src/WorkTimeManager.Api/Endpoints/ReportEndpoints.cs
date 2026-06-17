using System.Security.Claims;
using WorkTimeManager.Api.Domain;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Endpoints;

internal static class ReportEndpoints
{
    public static RouteGroupBuilder MapReportEndpoints(this RouteGroupBuilder group)
    {
        var reports = group.MapGroup("/reports").WithTags("Reports");

        reports.MapGet("/daily/{year:int}/{month:int}/{day:int}", async (
            int year, int month, int day, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidDay(year, month, day)) return Results.BadRequest("Ungültiges Datum.");

            var monthEntries = await entries.GetMonthAsync(uid, year, month, ct);
            var settings = await settingsRepo.GetAsync(uid, ct);
            var stat = ReportCalculator.CalculateDailyStat(monthEntries, new DateOnly(year, month, day), settings);
            return Results.Ok(stat);
        })
        .WithName("GetDailyReport");

        reports.MapGet("/weekly/{year:int}/{month:int}/{day:int}", async (
            int year, int month, int day, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidDay(year, month, day)) return Results.BadRequest("Ungültiges Datum.");

            var monthEntries = await entries.GetMonthAsync(uid, year, month, ct);
            var settings = await settingsRepo.GetAsync(uid, ct);
            var report = ReportCalculator.CalculateWeeklyReport(monthEntries, new DateOnly(year, month, day), settings);
            return Results.Ok(report);
        })
        .WithName("GetWeeklyReport");

        reports.MapGet("/monthly/{year:int}/{month:int}", async (
            int year, int month, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo,
            OvertimeRepository overtimeRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidMonth(year, month)) return Results.BadRequest("Ungültiger Monat.");

            var monthEntries = await entries.GetMonthAsync(uid, year, month, ct);
            var settings = await settingsRepo.GetAsync(uid, ct);
            var overtime = await overtimeRepo.GetAsync(uid, ct);
            var report = ReportCalculator.CalculateMonthlyReport(
                monthEntries, new DateOnly(year, month, 1), settings, overtime.Minutes * 60_000L);
            return Results.Ok(report);
        })
        .WithName("GetMonthlyReport");

        return group;
    }

    private static bool IsValidMonth(int year, int month) =>
        year is >= 2000 and <= 2100 && month is >= 1 and <= 12;

    private static bool IsValidDay(int year, int month, int day) =>
        IsValidMonth(year, month) && day >= 1 && day <= DateTime.DaysInMonth(year, month);
}
