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
            IsHomeOffice = true,
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
        Assert.True(roundTripped.IsHomeOffice);
        var b = Assert.Single(roundTripped.Breaks);
        Assert.Equal("b1", b.Id);
        Assert.Equal("Mittag", b.Name);
        Assert.True(b.IsAutomatic);
        Assert.Equal(original.Breaks[0].Start, b.Start);
        Assert.Equal(original.Breaks[0].End, b.End);
    }

    // ── Home-Office (#277) ──────────────────────────────────────────────────

    private static readonly Timestamp HoDate =
        Timestamp.FromDateTimeOffset(new DateTimeOffset(2026, 6, 5, 0, 0, 0, TimeSpan.Zero));

    [Fact]
    public void WorkEntry_MissingHomeOffice_MapsToFalse()
    {
        var dto = FirestoreMappings.ToDto(new DayData { Date = HoDate, IsHomeOffice = null }, "2026-06-05");
        Assert.False(dto.IsHomeOffice);
    }

    [Fact]
    public void WorkEntry_StoredHomeOfficeTrue_MapsToTrue()
    {
        var dto = FirestoreMappings.ToDto(new DayData { Date = HoDate, IsHomeOffice = true }, "2026-06-05");
        Assert.True(dto.IsHomeOffice);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    [InlineData(null)]
    public void WorkEntry_ToDocument_PassesHomeOfficeThrough(bool? value)
    {
        var dto = new WorkEntryDto { Id = "2026-06-05", Date = HoDate.ToDateTimeOffset(), IsHomeOffice = value };
        Assert.Equal(value, FirestoreMappings.ToDocument(dto).IsHomeOffice);
    }

    private static WorkEntryDto HoDto(bool? value) =>
        new() { Id = "2026-06-05", Date = HoDate.ToDateTimeOffset(), IsHomeOffice = value };

    [Fact]
    public void DayMergeFields_WithoutHomeOffice_OmitsHomeOfficePath()
    {
        var fields = FirestoreMappings.DayMergeFields(HoDto(null), "5");

        Assert.DoesNotContain("days.5.isHomeOffice", fields);
        Assert.Contains("days.5.date", fields);
        Assert.Contains("days.5.workStart", fields);
        Assert.Contains("days.5.breaks", fields);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void DayMergeFields_WithHomeOfficeTrueOrFalse_IncludesPath(bool value)
    {
        var fields = FirestoreMappings.DayMergeFields(HoDto(value), "5");
        Assert.Contains("days.5.isHomeOffice", fields);
    }

    [Fact]
    public void DayMergeFields_UsesDayKeyWithoutLeadingZero()
    {
        var dto = HoDto(true);
        var key = FirestoreMappings.DayKey(dto.Date);
        Assert.Equal("5", key);
        Assert.Contains("days.5.isHomeOffice", FirestoreMappings.DayMergeFields(dto, key));
    }

    [Fact]
    public void DayMergeFields_CoversAllDayDataProperties_ExceptOptionalFlags()
    {
        var expected = typeof(DayData).GetProperties()
            .Select(p => p.GetCustomAttributes(typeof(FirestorePropertyAttribute), false)
                .Cast<FirestorePropertyAttribute>().Single().Name ?? p.Name)
            .Where(n => n is not ("isHomeOffice" or "workLocations"))
            .Select(n => $"days.5.{n}")
            .OrderBy(n => n, StringComparer.Ordinal);

        var actual = FirestoreMappings.DayMergeFields(HoDto(null), "5").OrderBy(n => n, StringComparer.Ordinal);

        Assert.Equal(expected, actual);
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

    // ── Arbeitsorte (#526) ──────────────────────────────────────────────────

    private static WorkEntryDto WlDto(IReadOnlyList<string>? locations) =>
        new() { Id = "2026-06-05", Date = HoDate.ToDateTimeOffset(), WorkLocations = locations };

    [Fact]
    public void WorkLocations_RoundTrip_PreservesOrder()
    {
        var doc = FirestoreMappings.ToDocument(WlDto(new[] { "Kunde A", "Büro" }));
        var dto = FirestoreMappings.ToDto(doc, "2026-06-05");
        Assert.Equal(new[] { "Kunde A", "Büro" }, dto.WorkLocations);
    }

    [Fact]
    public void WorkLocations_MissingField_MapsToEmptyList_NotNull()
    {
        var dto = FirestoreMappings.ToDto(new DayData { Date = HoDate, WorkLocations = null }, "2026-06-05");
        Assert.NotNull(dto.WorkLocations);
        Assert.Empty(dto.WorkLocations!);
    }

    [Fact]
    public void DayMergeFields_WithoutWorkLocations_OmitsPath()
    {
        Assert.DoesNotContain("days.5.workLocations", FirestoreMappings.DayMergeFields(WlDto(null), "5"));
    }

    [Fact]
    public void DayMergeFields_WithWorkLocations_IncludesPath()
    {
        Assert.Contains("days.5.workLocations", FirestoreMappings.DayMergeFields(WlDto(new[] { "Büro" }), "5"));
    }

    [Fact]
    public void DayMergeFields_WithEmptyWorkLocations_IncludesPath_AndIsDelete()
    {
        var dto = WlDto(Array.Empty<string>());
        Assert.Contains("days.5.workLocations", FirestoreMappings.DayMergeFields(dto, "5"));
        Assert.True(FirestoreMappings.IsWorkLocationsDelete(dto));
        Assert.Null(FirestoreMappings.ToDocument(dto).WorkLocations);
    }

    [Fact]
    public void IsWorkLocationsDelete_OnlyForEmptyList()
    {
        Assert.False(FirestoreMappings.IsWorkLocationsDelete(WlDto(null)));
        Assert.False(FirestoreMappings.IsWorkLocationsDelete(WlDto(new[] { "Büro" })));
    }

    [Fact]
    public void WorkLocations_Normalize_TrimsDedupesCaseInsensitive_KeepsOrderAndFirst()
    {
        var input = new[] { " Kunde A ", "büro", "kunde a", "Büro", "Zuhause" };
        var expected = new[] { "Kunde A", "büro", "Zuhause" };
        Assert.Equal(expected, FirestoreMappings.NormalizeWorkLocations(input));
        Assert.Equal(expected, FirestoreMappings.ToDocument(WlDto(input)).WorkLocations);
    }

    [Fact]
    public void WorkLocations_Normalize_NullStaysNull() =>
        Assert.Null(FirestoreMappings.NormalizeWorkLocations(null));

    [Fact]
    public void IsValidWorkLocations_NullAndEmpty_AreValid()
    {
        Assert.True(FirestoreMappings.IsValidWorkLocations(null));
        Assert.True(FirestoreMappings.IsValidWorkLocations(Array.Empty<string>()));
    }

    [Fact]
    public void IsValidWorkLocations_CountLimit_FiveOkSixInvalid()
    {
        Assert.True(FirestoreMappings.IsValidWorkLocations(new[] { "a", "b", "c", "d", "e" }));
        Assert.False(FirestoreMappings.IsValidWorkLocations(new[] { "a", "b", "c", "d", "e", "f" }));
    }

    [Fact]
    public void IsValidWorkLocations_CountLimit_AppliesAfterDeduplication()
    {
        Assert.True(FirestoreMappings.IsValidWorkLocations(new[] { "a", "b", "c", "d", "e", "A", " b " }));
    }

    [Fact]
    public void IsValidWorkLocations_LengthLimit_SixtyOkSixtyOneInvalid_AfterTrim()
    {
        Assert.True(FirestoreMappings.IsValidWorkLocations(new[] { new string('x', 60) }));
        Assert.True(FirestoreMappings.IsValidWorkLocations(new[] { " " + new string('x', 60) + " " }));
        Assert.False(FirestoreMappings.IsValidWorkLocations(new[] { new string('x', 61) }));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void IsValidWorkLocations_EmptyEntry_IsInvalid(string entry) =>
        Assert.False(FirestoreMappings.IsValidWorkLocations(new[] { "Büro", entry }));

    [Fact]
    public void IsValidWorkLocations_NullEntry_IsInvalid() =>
        Assert.False(FirestoreMappings.IsValidWorkLocations(new string[] { null! }));

    [Fact]
    public void WorkLocations_JsonWithoutField_DeserializesToNull()
    {
        var dto = System.Text.Json.JsonSerializer.Deserialize<WorkEntryDto>(
            "{\"id\":\"2026-06-05\",\"date\":\"2026-06-05T00:00:00Z\"}",
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web));
        Assert.Null(dto!.WorkLocations);
        Assert.DoesNotContain("days.5.workLocations", FirestoreMappings.DayMergeFields(dto, "5"));
    }

    // ── Dashboard-Einstellungen (#526) ──────────────────────────────────────

    [Fact]
    public void Settings_MissingDashboardFlags_UseDefaults()
    {
        var dto = FirestoreMappings.ToDto(new SettingsDocument());
        Assert.False(dto.ShowWorkLocationOnDashboard);
        Assert.True(dto.ShowHomeOfficeOnDashboard);
    }

    [Fact]
    public void Settings_StoredDashboardFlags_AreReturned()
    {
        var dto = FirestoreMappings.ToDto(new SettingsDocument
        {
            ShowWorkLocationOnDashboard = true,
            ShowHomeOfficeOnDashboard = false,
        });
        Assert.True(dto.ShowWorkLocationOnDashboard);
        Assert.False(dto.ShowHomeOfficeOnDashboard);
    }

    [Fact]
    public void Settings_PutWithoutDashboardFlags_DoesNotMergeThem()
    {
        var dto = System.Text.Json.JsonSerializer.Deserialize<SettingsDto>(
            "{\"weeklyTargetHours\":36}",
            new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web))!;
        var fields = FirestoreMappings.SettingsMergeFields(dto);
        Assert.DoesNotContain("showWorkLocationOnDashboard", fields);
        Assert.DoesNotContain("showHomeOfficeOnDashboard", fields);
    }

    [Fact]
    public void Settings_PutWithDashboardFlags_MergesThem_EvenWhenFalse()
    {
        var dto = new SettingsDto { ShowWorkLocationOnDashboard = false, ShowHomeOfficeOnDashboard = false };
        var fields = FirestoreMappings.SettingsMergeFields(dto);
        Assert.Contains("showWorkLocationOnDashboard", fields);
        Assert.Contains("showHomeOfficeOnDashboard", fields);
        var doc = FirestoreMappings.ToDocument(dto);
        Assert.False(doc.ShowWorkLocationOnDashboard);
        Assert.False(doc.ShowHomeOfficeOnDashboard);
    }
}
