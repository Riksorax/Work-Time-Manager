using Google.Cloud.Firestore;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore;
using WorkTimeManager.Api.Firestore.Documents;

namespace WorkTimeManager.Api.Tests;

public class FirestoreMappingsTests
{
    [Fact]
    public void WorkEntry_RoundTrip_PreservesFields()
    {
        var date = new DateTimeOffset(2026, 6, 5, 0, 0, 0, TimeSpan.Zero);
        var start = new DateTimeOffset(2026, 6, 5, 8, 0, 0, TimeSpan.Zero);
        var end = new DateTimeOffset(2026, 6, 5, 17, 0, 0, TimeSpan.Zero);

        var original = new DayData
        {
            Date = Timestamp.FromDateTimeOffset(date),
            WorkStart = Timestamp.FromDateTimeOffset(start),
            WorkEnd = Timestamp.FromDateTimeOffset(end),
            Type = "vacation",
            IsManuallyEntered = true,
            ManualOvertimeMinutes = 42,
            Description = "Test",
            Breaks =
            [
                new BreakData
                {
                    Id = "b1",
                    Name = "Mittag",
                    IsAutomatic = true,
                    Start = Timestamp.FromDateTimeOffset(start.AddHours(4)),
                    End = Timestamp.FromDateTimeOffset(start.AddHours(4).AddMinutes(30)),
                },
            ],
        };

        var dto = FirestoreMappings.ToDto(original, "2026-06-05");
        var roundTripped = FirestoreMappings.ToDocument(dto);

        Assert.Equal("2026-06-05", dto.Id);
        Assert.Equal(original.Date, roundTripped.Date);
        Assert.Equal(original.WorkStart, roundTripped.WorkStart);
        Assert.Equal(original.WorkEnd, roundTripped.WorkEnd);
        Assert.Equal("vacation", roundTripped.Type);
        Assert.True(roundTripped.IsManuallyEntered);
        Assert.Equal(42, roundTripped.ManualOvertimeMinutes);
        Assert.Equal("Test", roundTripped.Description);
        var b = Assert.Single(roundTripped.Breaks);
        Assert.Equal("b1", b.Id);
        Assert.Equal("Mittag", b.Name);
        Assert.True(b.IsAutomatic);
        Assert.Equal(original.Breaks[0].Start, b.Start);
        Assert.Equal(original.Breaks[0].End, b.End);
    }

    [Theory]
    [InlineData(2026, 6, 5, "5")]
    [InlineData(2026, 6, 15, "15")]
    public void DayKey_OmitsLeadingZero(int year, int month, int day, string expected)
    {
        var date = new DateTimeOffset(year, month, day, 0, 0, 0, TimeSpan.Zero);
        Assert.Equal(expected, FirestoreMappings.DayKey(date));
    }

    [Fact]
    public void EntryId_And_MonthId_UseZeroPadding()
    {
        Assert.Equal("2026-06-05", FirestoreMappings.EntryId(2026, 6, 5));
        Assert.Equal("2026-06", FirestoreMappings.MonthId(2026, 6));
    }

    // ── Urlaubsanspruch (#278) ──────────────────────────────────────────────

    [Fact]
    public void Settings_MissingVacationField_DefaultsTo30()
    {
        var dto = FirestoreMappings.ToDto(new SettingsDocument());
        Assert.Equal(30, dto.VacationDaysPerYear);
    }

    [Fact]
    public void Settings_StoredVacationField_IsReturned()
    {
        var dto = FirestoreMappings.ToDto(new SettingsDocument { VacationDaysPerYear = 25 });
        Assert.Equal(25, dto.VacationDaysPerYear);
    }

    [Fact]
    public void Settings_ZeroVacation_IsKeptNotDefaulted()
    {
        var dto = FirestoreMappings.ToDto(new SettingsDocument { VacationDaysPerYear = 0 });
        Assert.Equal(0, dto.VacationDaysPerYear);
    }

    [Fact]
    public void Settings_PutWithoutVacationField_DoesNotMergeVacationField()
    {
        // Alter Client: Feld fehlt im JSON -> null -> darf den gespeicherten Wert nicht überschreiben.
        var dto = System.Text.Json.JsonSerializer.Deserialize<SettingsDto>(
            "{\"weeklyTargetHours\":38}",
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web))!;

        Assert.Null(dto.VacationDaysPerYear);
        Assert.DoesNotContain("vacationDaysPerYear", FirestoreMappings.SettingsMergeFields(dto));
        Assert.Contains("weeklyTargetHours", FirestoreMappings.SettingsMergeFields(dto));
    }

    [Fact]
    public void Settings_PutWithVacationField_MergesVacationField()
    {
        var dto = new SettingsDto { VacationDaysPerYear = 25 };
        Assert.Contains("vacationDaysPerYear", FirestoreMappings.SettingsMergeFields(dto));
        Assert.Equal(25, FirestoreMappings.ToDocument(dto).VacationDaysPerYear);
    }

    [Theory]
    [InlineData(null, true)]
    [InlineData(0, true)]
    [InlineData(30, true)]
    [InlineData(366, true)]
    [InlineData(-1, false)]
    [InlineData(367, false)]
    public void IsValidVacationDays_EnforcesRange(int? value, bool expected) =>
        Assert.Equal(expected, FirestoreMappings.IsValidVacationDays(value));

    // ── Bundesland (#279) ───────────────────────────────────────────────────

    private static readonly string[] AllBundeslaender =
    [
        "badenWuerttemberg", "bayern", "berlin", "brandenburg", "bremen", "hamburg", "hessen",
        "mecklenburgVorpommern", "niedersachsen", "nordrheinWestfalen", "rheinlandPfalz",
        "saarland", "sachsen", "sachsenAnhalt", "schleswigHolstein", "thueringen",
    ];

    [Fact]
    public void Settings_MissingBundesland_IsNull()
    {
        Assert.Null(FirestoreMappings.ToDto(new SettingsDocument()).Bundesland);
    }

    [Fact]
    public void Settings_StoredBundesland_IsReturned()
    {
        var dto = FirestoreMappings.ToDto(new SettingsDocument { Bundesland = "nordrheinWestfalen" });
        Assert.Equal("nordrheinWestfalen", dto.Bundesland);
    }

    [Fact]
    public void Settings_StoredInvalidBundesland_IsReturnedAsNull()
    {
        Assert.Null(FirestoreMappings.ToDto(new SettingsDocument { Bundesland = "atlantis" }).Bundesland);
    }

    [Fact]
    public void Settings_PutWithoutBundeslandField_DoesNotMergeBundesland()
    {
        var dto = System.Text.Json.JsonSerializer.Deserialize<SettingsDto>(
            "{\"weeklyTargetHours\":38}",
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web))!;

        Assert.Null(dto.Bundesland);
        Assert.DoesNotContain("bundesland", FirestoreMappings.SettingsMergeFields(dto));
    }

    [Fact]
    public void Settings_PutWithBundesland_MergesBundesland()
    {
        var dto = new SettingsDto { Bundesland = "bayern" };
        Assert.Contains("bundesland", FirestoreMappings.SettingsMergeFields(dto));
        Assert.Equal("bayern", FirestoreMappings.ToDocument(dto).Bundesland);
    }

    [Fact]
    public void Settings_PutWithEmptyBundesland_MergesFieldButStoresNoValue()
    {
        // "" = Feld löschen: Merge-Feld ist enthalten, das Dokument trägt aber keinen Text.
        var dto = new SettingsDto { Bundesland = "" };
        Assert.Contains("bundesland", FirestoreMappings.SettingsMergeFields(dto));
        Assert.Null(FirestoreMappings.ToDocument(dto).Bundesland);
        Assert.True(FirestoreMappings.IsBundeslandDelete(dto));
        Assert.False(FirestoreMappings.IsBundeslandDelete(new SettingsDto { Bundesland = "bayern" }));
        Assert.False(FirestoreMappings.IsBundeslandDelete(new SettingsDto()));
    }

    [Fact]
    public void IsValidBundesland_AcceptsAll16Names()
    {
        Assert.Equal(16, AllBundeslaender.Length);
        foreach (var name in AllBundeslaender)
            Assert.True(FirestoreMappings.IsValidBundesland(name), name);
    }

    [Theory]
    [InlineData(null, true)]
    [InlineData("", true)]
    [InlineData("Bayern", false)]
    [InlineData("BAYERN", false)]
    [InlineData(" bayern", false)]
    [InlineData("nordrhein-westfalen", false)]
    [InlineData("atlantis", false)]
    public void IsValidBundesland_NullEmptyOrWhitelist(string? value, bool expected) =>
        Assert.Equal(expected, FirestoreMappings.IsValidBundesland(value));
}
