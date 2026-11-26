using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Domain;
using WorkTimeManager.Api.Endpoints;

namespace WorkTimeManager.Api.Tests;

/// <summary>Insights und Home-Office (#537): Regeln 1:1 aus Mobile, von Hand nachgerechnet.</summary>
public class InsightsCalculatorTests
{
    private static readonly SettingsDto Settings40 = new() { WeeklyTargetHours = 40, Workdays = new[] { 1, 2, 3, 4, 5 } };
    private static readonly TimeZoneInfo Berlin = Zone("Europe/Berlin");
    private static readonly TimeZoneInfo LosAngeles = Zone("America/Los_Angeles");

    private static TimeZoneInfo Zone(string id)
    {
        Assert.True(ReportEndpoints.TryParseTimeZone(id, out var zone), id);
        return zone;
    }

    private static WorkEntryDto Work(string day, string? startUtc, string? endUtc, bool homeOffice = false,
        string type = "work", params (string Start, string? End)[] breaks) => new()
    {
        Id = day,
        Date = DateTimeOffset.Parse($"{day}T00:00:00Z"),
        WorkStart = startUtc is null ? null : DateTimeOffset.Parse($"{day}T{startUtc}Z"),
        WorkEnd = endUtc is null ? null : DateTimeOffset.Parse($"{day}T{endUtc}Z"),
        Type = type,
        IsHomeOffice = homeOffice,
        Breaks = breaks.Select((b, i) => new BreakDto
        {
            Id = $"b{i}",
            Start = DateTimeOffset.Parse($"{day}T{b.Start}Z"),
            End = b.End is null ? null : DateTimeOffset.Parse($"{day}T{b.End}Z"),
        }).ToList(),
    };

    // ─── Zeitfenster ─────────────────────────────────────────────────────────

    [Theory]
    [InlineData("2026-06-10", "2026-04-01", "2026-06-30")]
    [InlineData("2026-01-10", "2025-11-01", "2026-01-31")]
    [InlineData("2026-02-01", "2025-12-01", "2026-02-28")]
    [InlineData("2028-03-31", "2028-01-01", "2028-03-31")]
    public void Range_ThreeWholeCalendarMonths(string reference, string from, string to)
    {
        var (f, t) = InsightsCalculator.Range(DateOnly.Parse(reference));
        Assert.Equal(DateOnly.Parse(from), f);
        Assert.Equal(DateOnly.Parse(to), t);
    }

    // ─── Wochentage ──────────────────────────────────────────────────────────

    [Fact]
    public void WeekdayAverages_OnlyClosedWork_TruncatedTowardZero()
    {
        var entries = new[]
        {
            Work("2026-06-01", "08:00:00", "16:00:00"),                                  // Mo 480 min
            Work("2026-06-08", "08:00:00", "16:01:00", breaks: ("12:00:00", "12:30:00")), // Mo 451 min
            Work("2026-06-02", "08:00:00", "15:00:00", breaks: ("12:00:00", null)),       // Di 420 min, offene Pause 0
            Work("2026-06-03", "08:00:00", null),                                         // offen: fehlt
            Work("2026-06-04", null, null, type: "vacation"),                             // Urlaub: fehlt
            Work("2026-06-05", "10:00:00", "09:00:00"),                                   // negativ -> 0
        };

        var result = InsightsCalculator.WeekdayAverages(entries);

        // Mittel aller vier Werte: (480 + 451 + 420 + 0) / 4 = 337,75 min = 20 265 000 ms.
        Assert.Equal(new[] { 1, 2, 5 }, result.Select(r => r.Weekday));
        var mo = result[0];
        Assert.Equal(27_930_000, mo.AverageWorkedMs); // 465,5 min
        Assert.Equal(27_930_000 - 20_265_000, mo.DeviationMs);
        Assert.Equal(2, mo.SampleCount);
        Assert.Equal(0, result[2].AverageWorkedMs);
        Assert.Equal(-20_265_000, result[2].DeviationMs);
    }

    [Fact]
    public void WeekdayAverages_SecondsAreCutAtTheMinute_LikeTheMobileReadBoundary()
    {
        // 08:00:59 -> 08:00, 16:00:30 -> 16:00: 480 min, nicht 479,5 min.
        var result = InsightsCalculator.WeekdayAverages(new[] { Work("2026-06-01", "08:00:59", "16:00:30") });
        Assert.Equal(28_800_000, result.Single().AverageWorkedMs);
    }

    [Fact]
    public void WeekdayAverages_NegativeDeviation()
    {
        // Mo 0 min, Di 1 min, Di 0 min: Mittel 1/3 min = 20 000 ms; Mo-Abweichung −20 000, Di 30 000 − 20 000.
        var result = InsightsCalculator.WeekdayAverages(new[]
        {
            Work("2026-06-01", "08:00:00", "08:00:00"),
            Work("2026-06-02", "08:00:00", "08:01:00"),
            Work("2026-06-09", "08:00:00", "08:00:00"),
        });
        Assert.Equal(-20_000, result[0].DeviationMs);
        Assert.Equal(10_000, result[1].DeviationMs);
    }

    [Fact]
    public void WeekdayAverages_WeekdayFromCalendarDay_NotFromUtcStart()
    {
        // Do 04.06. 18:00 in LA = Fr 05.06. 01:00Z: zählt als Donnerstag.
        var entry = Work("2026-06-04", "08:00:00", "12:00:00") with
        {
            WorkStart = DateTimeOffset.Parse("2026-06-05T01:00:00Z"),
            WorkEnd = DateTimeOffset.Parse("2026-06-05T06:00:00Z"),
        };
        Assert.Equal(4, InsightsCalculator.WeekdayAverages(new[] { entry }).Single().Weekday);
    }

    // ─── Serie ───────────────────────────────────────────────────────────────

    [Fact]
    public void Streak_FreeDaysDoNotBreak_ContractDayWithoutOvertimeDoes()
    {
        const long target = 480L * 60_000 * 1000;
        var entries = new[]
        {
            Work("2026-06-04", "08:00:00", "16:01:00"), // Do über Soll
            Work("2026-06-05", "08:00:00", "16:01:00"), // Fr
            Work("2026-06-06", "08:00:00", "09:00:00"), // Sa frei, unter Soll: unterbricht nicht
            Work("2026-06-08", "08:00:00", "16:01:00"), // Mo
            Work("2026-06-09", "08:00:00", "16:00:00"), // Di genau Soll: nicht darüber -> 0
            Work("2026-06-10", "08:00:00", "16:01:00"), // Mi
        };
        var streak = InsightsCalculator.OvertimeStreak(entries, Settings40.Workdays, target);
        Assert.Equal(new OvertimeStreakDto(1, 3, false, 5), streak);
    }

    [Fact]
    public void Streak_AbsenceAndMissingContractDayEndIt_EntriesAreNotSummed()
    {
        const long target = 480L * 60_000 * 1000;
        var entries = new[]
        {
            Work("2026-06-01", "06:00:00", "11:00:00"), // Mo 5 h
            Work("2026-06-01", "12:00:00", "17:00:00"), // Mo 5 h: einzeln nicht über Soll
            Work("2026-06-02", "06:00:00", "16:00:00"),
            Work("2026-06-03", null, null, type: "vacation"),
            Work("2026-06-04", "06:00:00", "16:00:00"),
            Work("2026-06-08", "06:00:00", "16:00:00"), // Fr 05.06. ohne Eintrag beendet
        };
        var streak = InsightsCalculator.OvertimeStreak(entries, Settings40.Workdays, target);
        Assert.Equal(new OvertimeStreakDto(1, 1, false, 5), streak);
    }

    [Fact]
    public void Streak_FiveDaysIsWarning_EmptyOrNoWorkdaysIsZero()
    {
        const long target = 480L * 60_000 * 1000;
        var five = Enumerable.Range(1, 5).Select(d => Work($"2026-06-0{d}", "08:00:00", "17:00:00")).ToList();
        Assert.Equal(new OvertimeStreakDto(5, 5, true, 5), InsightsCalculator.OvertimeStreak(five, Settings40.Workdays, target));
        Assert.Equal(new OvertimeStreakDto(0, 0, false, 5), InsightsCalculator.OvertimeStreak(five, Array.Empty<int>(), target));
        Assert.Equal(new OvertimeStreakDto(0, 0, false, 5), InsightsCalculator.OvertimeStreak(Array.Empty<WorkEntryDto>(), Settings40.Workdays, target));
        var onlyVacation = new[] { Work("2026-06-01", null, null, type: "vacation") };
        Assert.Equal(new OvertimeStreakDto(0, 0, false, 5), InsightsCalculator.OvertimeStreak(onlyVacation, Settings40.Workdays, target));
    }

    // ─── Heatmap ─────────────────────────────────────────────────────────────

    [Fact]
    public void Heatmap_LocalHour_MinTwoSamples_OpenEntriesCountMinusTarget()
    {
        const long target = 480L * 60_000 * 1000;
        var entries = new[]
        {
            Work("2026-06-01", "05:00:00", "14:00:00"), // 07:00 MESZ, +60 min
            Work("2026-06-02", "05:59:00", null),       // 07:59 MESZ, offen: −480 min
            Work("2026-06-03", "06:00:00", "15:00:00"), // 08:00 MESZ, nur einer: fehlt
            Work("2026-06-04", null, null, type: "sick"),
        };
        var heatmap = InsightsCalculator.StartTimeHeatmap(entries, target, Berlin);
        var bucket = Assert.Single(heatmap);
        Assert.Equal(7, bucket.StartHour);
        Assert.Equal((60 - 480) / 2 * 60_000L, bucket.AverageOvertimeMs);
        Assert.Equal(2, bucket.SampleCount);
    }

    [Fact]
    public void Heatmap_DaylightSavingTime_SameUtcHourShiftsLocalHour()
    {
        var entries = new[]
        {
            Work("2026-03-26", "06:30:00", "14:30:00"), // MEZ 07:30
            Work("2026-03-27", "06:30:00", "14:30:00"),
            Work("2026-03-30", "06:30:00", "14:30:00"), // MESZ 08:30
            Work("2026-03-31", "06:30:00", "14:30:00"),
        };
        Assert.Equal(new[] { 7, 8 }, InsightsCalculator.StartTimeHeatmap(entries, 0, Berlin).Select(b => b.StartHour));
        // LA: 06:30Z ist am 26.03. (PDT) 23:30 des Vortags.
        Assert.Equal(new[] { 23 }, InsightsCalculator.StartTimeHeatmap(entries, 0, LosAngeles).Select(b => b.StartHour));
    }

    [Fact]
    public void Calculate_UsesWindowTargetAndZone()
    {
        var entries = new[]
        {
            Work("2026-03-31", "06:00:00", "18:00:00"), // vor dem Fenster
            Work("2026-04-01", "06:00:00", "15:00:00"),
            Work("2026-06-30", "06:00:00", "15:00:00"), // nach dem Bezugstag, im Fenster
        };
        var settings = new SettingsDto { WeeklyTargetHours = 39, Workdays = new[] { 1, 2, 3, 4, 5, 6, 7 } };
        var result = InsightsCalculator.Calculate(entries, new DateOnly(2026, 6, 10), settings, Berlin);
        Assert.Equal(new DateOnly(2026, 4, 1), result.From);
        Assert.Equal(new DateOnly(2026, 6, 30), result.To);
        Assert.Equal("Europe/Berlin", result.TimeZone);
        Assert.Equal(334 * 60_000L, result.DailyTargetMs); // 39 h / 7 = 334,29 min -> 334
        Assert.Equal(2, result.WeekdayAverages.Sum(w => w.SampleCount));
        var bucket = Assert.Single(result.StartTimeHeatmap);
        Assert.Equal(8, bucket.StartHour);
        Assert.Equal((540 - 334) * 60_000L, bucket.AverageOvertimeMs);
    }

    // ─── Zeitzone ────────────────────────────────────────────────────────────

    [Theory]
    [InlineData("Europe/Berlin")]
    [InlineData("America/Los_Angeles")]
    [InlineData("Pacific/Auckland")]
    [InlineData("UTC")]
    public void TryParseTimeZone_AcceptsIana(string id)
    {
        Assert.True(ReportEndpoints.TryParseTimeZone(id, out var zone));
        Assert.Equal(id, zone.Id);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("Europe/Bärlin")]
    [InlineData("Mars/Olympus")]
    [InlineData("W. Europe Standard Time")]
    [InlineData("../etc/passwd")]
    [InlineData("/etc/localtime")]
    [InlineData("localtime")]
    [InlineData("Europe/../UTC")]
    public void TryParseTimeZone_RejectsInvalid(string? id) =>
        Assert.False(ReportEndpoints.TryParseTimeZone(id, out _));

    // ─── Home-Office ─────────────────────────────────────────────────────────

    [Fact]
    public void HomeOffice_Rules()
    {
        var entries = new[]
        {
            Work("2026-03-02", "07:00:00", "15:00:00", homeOffice: true),
            Work("2026-03-03", "07:00:00", "15:00:00"),
            Work("2026-03-04", "07:00:00", null, homeOffice: true),     // offen zählt
            Work("2026-03-05", null, null, homeOffice: true),           // leer zählt nicht
            Work("2026-03-06", null, null, homeOffice: true, type: "vacation"),
            Work("2026-03-09", null, null, homeOffice: true, type: "sick"),
            Work("2026-03-10", null, null, homeOffice: true, type: "holiday"),
            Work("2026-03-11", "07:00:00", "11:00:00"),
            Work("2026-03-11", "12:00:00", "15:00:00", homeOffice: true), // ein Eintrag mit Flag reicht
            Work("2026-03-12", "07:00:00", "11:00:00"),
            Work("2026-03-12", "12:00:00", "15:00:00"),                   // ein Bürotag
            Work("2026-04-01", "07:00:00", "15:00:00"),
            Work("2025-12-31", "07:00:00", "15:00:00", homeOffice: true), // anderes Jahr
        };

        var r = HomeOfficeCalculator.Calculate(entries, 2026);

        Assert.Equal(3, r.HomeOfficeDays);
        Assert.Equal(3, r.OfficeDays);
        Assert.Equal(6, r.TotalDays);
        Assert.Equal(0.5, r.HomeOfficeRatio);
        Assert.Equal(new[] { new DateOnly(2026, 3, 2), new DateOnly(2026, 3, 4), new DateOnly(2026, 3, 11) }, r.HomeOfficeDates);
        Assert.Equal(12, r.Months.Count);
        Assert.Equal(new HomeOfficeMonthDto(3, 3, 2, 5, 0.6), r.Months[2]);
        Assert.Equal(new HomeOfficeMonthDto(4, 0, 1, 1, 0), r.Months[3]);
        Assert.Equal(new HomeOfficeMonthDto(1, 0, 0, 0, null), r.Months[0]);
        Assert.Equal(r.HomeOfficeDays, r.Months.Sum(m => m.HomeOfficeDays));
        Assert.Equal(r.OfficeDays, r.Months.Sum(m => m.OfficeDays));
    }

    [Fact]
    public void HomeOffice_Empty_RatioNull()
    {
        var r = HomeOfficeCalculator.Calculate(Array.Empty<WorkEntryDto>(), 2026);
        Assert.Null(r.HomeOfficeRatio);
        Assert.Equal(0, r.TotalDays);
        Assert.Empty(r.HomeOfficeDates);
        Assert.Equal(12, r.Months.Count);
    }

    [Fact]
    public void EntryDay_FromId_FallbackToUtcDate()
    {
        var entry = Work("2026-06-04", "08:00:00", "12:00:00") with { Date = DateTimeOffset.Parse("2026-06-05T00:00:00Z") };
        Assert.Equal(new DateOnly(2026, 6, 4), EntryDays.Of(entry));
        Assert.Equal(new DateOnly(2026, 6, 5), EntryDays.Of(entry with { Id = "x" }));
        Assert.Equal(new DateOnly(2026, 6, 5), EntryDays.Of(entry with { Id = "2026-02-30" }));
    }
}
