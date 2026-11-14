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
            int year, int month, int day, string? profileId, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidDay(year, month, day)) return Results.BadRequest("Ungültiges Datum.");

            var monthEntries = await entries.GetMonthAsync(uid, year, month, profileId, ct);
            var settings = await settingsRepo.GetAsync(uid, profileId, ct);
            var stat = ReportCalculator.CalculateDailyStat(monthEntries, new DateOnly(year, month, day), settings);
            return Results.Ok(stat);
        })
        .WithName("GetDailyReport");

        reports.MapGet("/weekly/{year:int}/{month:int}/{day:int}", async (
            int year, int month, int day, string? profileId, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidDay(year, month, day)) return Results.BadRequest("Ungültiges Datum.");

            var date = new DateOnly(year, month, day);
            var weekEntries = await entries.GetWeekAsync(uid, date, profileId, ct);
            var settings = await settingsRepo.GetAsync(uid, profileId, ct);
            var report = ReportCalculator.CalculateWeeklyReport(weekEntries, date, settings);
            return Results.Ok(report);
        })
        .WithName("GetWeeklyReport");

        reports.MapGet("/monthly/{year:int}/{month:int}", async (
            int year, int month, string? profileId, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo,
            OvertimeRepository overtimeRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidMonth(year, month)) return Results.BadRequest("Ungültiger Monat.");

            var monthEntries = await entries.GetMonthAsync(uid, year, month, profileId, ct);
            var settings = await settingsRepo.GetAsync(uid, profileId, ct);
            var overtime = await overtimeRepo.GetAsync(uid, profileId, ct);
            var report = ReportCalculator.CalculateMonthlyReport(
                monthEntries, new DateOnly(year, month, 1), settings, overtime.Minutes * 60_000L);
            return Results.Ok(report);
        })
        .WithName("GetMonthlyReport");

        reports.MapGet("/yearly/{year:int}", async (
            int year, string? profileId, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (year is < 2000 or > 2100) return Results.BadRequest("Ungültiges Jahr.");

            var yearEntries = await entries.GetYearAsync(uid, year, profileId, ct);
            var settings = await settingsRepo.GetAsync(uid, profileId, ct);
            return Results.Ok(ReportCalculator.CalculateYearlyLeave(yearEntries, year, settings));
        })
        .WithName("GetYearlyLeaveReport");

        reports.MapGet("/trend/{year:int}/{month:int}/{day:int}", async (
            int year, int month, int day, string? granularity, string? profileId, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            if (!IsValidDay(year, month, day)) return Results.BadRequest("Ungültiges Datum.");
            if (!TryParseGranularity(granularity, out var g))
                return Results.BadRequest("granularity muss 'week' oder 'month' sein.");

            var date = new DateOnly(year, month, day);
            var (from, to) = ReportCalculator.TrendRange(date, g);
            var rangeEntries = await entries.GetRangeAsync(uid, from, to, profileId, ct);
            var settings = await settingsRepo.GetAsync(uid, profileId, ct);
            return Results.Ok(ReportCalculator.CalculateTrend(rangeEntries, date, g, settings));
        })
        .WithName("GetTrendReport");

        reports.MapGet("/yearly-comparison/{year:int}", async (
            int year, string? until, string? profileId, ClaimsPrincipal user,
            WorkEntryRepository entries, SettingsRepository settingsRepo, CancellationToken ct) =>
        {
            if (user.GetUid() is not { } uid) return Results.Unauthorized();
            // Das Vorjahr muss ebenfalls im Bereich 2000–2100 liegen.
            if (year is < 2001 or > 2100) return Results.BadRequest("Ungültiges Jahr.");
            if (!TryParseUntil(until, out var cutoff))
                return Results.BadRequest("until muss ein gültiger Tag im Format MM-dd sein.");

            var previousYear = year - 1;
            var currentTask = entries.GetRangeAsync(
                uid, new DateOnly(year, 1, 1), ReportCalculator.YearlyCutoffDate(year, cutoff), profileId, ct);
            var previousTask = entries.GetRangeAsync(
                uid, new DateOnly(previousYear, 1, 1), ReportCalculator.YearlyCutoffDate(previousYear, cutoff), profileId, ct);
            var settingsTask = settingsRepo.GetAsync(uid, profileId, ct);
            await Task.WhenAll(currentTask, previousTask, settingsTask);

            var settings = settingsTask.Result;
            var current = ReportCalculator.CalculateYearlySummary(currentTask.Result, year, settings, cutoff);
            var previous = ReportCalculator.CalculateYearlySummary(previousTask.Result, previousYear, settings, cutoff);
            return Results.Ok(ReportCalculator.CalculateYearlyComparison(current, previous, cutoff));
        })
        .WithName("GetYearlyComparisonReport");

        return group;
    }

    /// <summary>
    /// Optionaler Stichtag <c>until</c> des Jahresvergleichs (#530): genau <c>MM-dd</c> (ASCII-Ziffern), ein Tag,
    /// den es in einem Schaltjahr gibt (<c>02-29</c> gültig, <c>02-30</c>/<c>13-01</c> nicht). <c>null</c> = kein
    /// Stichtag (gültig); jeder andere Wert, auch <c>""</c>, ist ungültig.
    /// </summary>
    internal static bool TryParseUntil(string? value, out MonthDay? until)
    {
        until = null;
        if (value is null) return true;
        if (value.Length != 5 || value[2] != '-'
            || !char.IsAsciiDigit(value[0]) || !char.IsAsciiDigit(value[1])
            || !char.IsAsciiDigit(value[3]) || !char.IsAsciiDigit(value[4]))
            return false;

        var month = (value[0] - '0') * 10 + (value[1] - '0');
        var day = (value[3] - '0') * 10 + (value[4] - '0');
        // 2000 ist ein Schaltjahr: so ist 02-29 gültig.
        if (month is < 1 or > 12 || day < 1 || day > DateTime.DaysInMonth(2000, month)) return false;

        until = new MonthDay(month, day);
        return true;
    }

    /// <summary>Pflicht-Query <c>granularity</c> des Trends (#531): genau <c>week</c> oder <c>month</c> (kleingeschrieben).</summary>
    internal static bool TryParseGranularity(string? value, out TrendGranularity granularity)
    {
        switch (value)
        {
            case "week":
                granularity = TrendGranularity.Week;
                return true;
            case "month":
                granularity = TrendGranularity.Month;
                return true;
            default:
                granularity = default;
                return false;
        }
    }

    private static bool IsValidMonth(int year, int month) =>
        year is >= 2000 and <= 2100 && month is >= 1 and <= 12;

    private static bool IsValidDay(int year, int month, int day) =>
        IsValidMonth(year, month) && day >= 1 && day <= DateTime.DaysInMonth(year, month);
}
