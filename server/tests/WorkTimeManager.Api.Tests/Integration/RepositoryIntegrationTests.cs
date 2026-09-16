using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore;

namespace WorkTimeManager.Api.Tests.Integration;

/// <summary>
/// End-to-End-Tests der Repositories gegen einen echten Firestore-Emulator. Validiert die
/// POCO-Serialisierung (days-Map, Timestamps, breaks) gegen die tatsächliche Firestore-Engine.
/// Ohne Docker/Emulator werden die Tests übersprungen (siehe <see cref="FirestoreEmulatorFixture"/>).
/// </summary>
[Collection(FirestoreEmulatorCollection.Name)]
public class RepositoryIntegrationTests(FirestoreEmulatorFixture fixture)
{
    private static readonly CancellationToken Ct = CancellationToken.None;

    private static string NewUid() => $"user-{Guid.NewGuid():N}";

    private void RequireEmulator() => Skip.If(fixture.SkipReason is not null, fixture.SkipReason);

    [SkippableFact]
    public async Task WorkEntry_SaveAndGetMonth_RoundTrips()
    {
        RequireEmulator();
        var repo = new WorkEntryRepository(fixture.Db!);
        var uid = NewUid();
        var entry = new WorkEntryDto
        {
            Id = "2026-06-05",
            Date = new DateTimeOffset(2026, 6, 5, 0, 0, 0, TimeSpan.Zero),
            WorkStart = new DateTimeOffset(2026, 6, 5, 8, 0, 0, TimeSpan.Zero),
            WorkEnd = new DateTimeOffset(2026, 6, 5, 16, 30, 0, TimeSpan.Zero),
            Type = "work",
            IsManuallyEntered = true,
            Description = "Integrationstest",
            Breaks =
            [
                new BreakDto
                {
                    Id = "b1",
                    Name = "Mittag",
                    IsAutomatic = true,
                    Start = new DateTimeOffset(2026, 6, 5, 12, 0, 0, TimeSpan.Zero),
                    End = new DateTimeOffset(2026, 6, 5, 12, 30, 0, TimeSpan.Zero),
                },
            ],
        };

        await repo.SaveAsync(uid, entry, null, Ct);
        var month = await repo.GetMonthAsync(uid, 2026, 6, null, Ct);

        var loaded = Assert.Single(month);
        Assert.Equal("2026-06-05", loaded.Id);
        Assert.Equal(entry.WorkStart, loaded.WorkStart);
        Assert.Equal(entry.WorkEnd, loaded.WorkEnd);
        Assert.Equal("Integrationstest", loaded.Description);
        Assert.True(loaded.IsManuallyEntered);
        var b = Assert.Single(loaded.Breaks);
        Assert.Equal("Mittag", b.Name);
        Assert.Equal(entry.Breaks[0].End, b.End);
    }

    [SkippableFact]
    public async Task WorkEntry_GetDay_ReturnsNullWhenMissing()
    {
        RequireEmulator();
        var repo = new WorkEntryRepository(fixture.Db!);
        Assert.Null(await repo.GetDayAsync(NewUid(), 2026, 6, 5, null, Ct));
    }

    [SkippableFact]
    public async Task WorkEntry_Delete_RemovesSingleDayKeepsOthers()
    {
        RequireEmulator();
        var repo = new WorkEntryRepository(fixture.Db!);
        var uid = NewUid();
        await repo.SaveAsync(uid, Day(5), null, Ct);
        await repo.SaveAsync(uid, Day(6), null, Ct);

        await repo.DeleteAsync(uid, 2026, 6, 5, null, Ct);

        var month = await repo.GetMonthAsync(uid, 2026, 6, null, Ct);
        var remaining = Assert.Single(month);
        Assert.Equal("2026-06-06", remaining.Id);

        static WorkEntryDto Day(int day) => new()
        {
            Id = $"2026-06-{day:D2}",
            Date = new DateTimeOffset(2026, 6, day, 0, 0, 0, TimeSpan.Zero),
            WorkStart = new DateTimeOffset(2026, 6, day, 9, 0, 0, TimeSpan.Zero),
            WorkEnd = new DateTimeOffset(2026, 6, day, 17, 0, 0, TimeSpan.Zero),
        };
    }

    [SkippableFact]
    public async Task GetWeek_LoadsEntriesAcrossMonthBoundary()
    {
        RequireEmulator();
        var repo = new WorkEntryRepository(fixture.Db!);
        var uid = NewUid();
        // Woche Mo 30.03.2026 – So 05.04.2026 (kreuzt März/April)
        await repo.SaveAsync(uid, Day(2026, 3, 31), null, Ct);
        await repo.SaveAsync(uid, Day(2026, 4, 1), null, Ct);

        var week = await repo.GetWeekAsync(uid, new DateOnly(2026, 4, 1), null, Ct);

        Assert.Equal(2, week.Count);
        Assert.Contains(week, e => e.Id == "2026-03-31");
        Assert.Contains(week, e => e.Id == "2026-04-01");

        static WorkEntryDto Day(int y, int m, int d) => new()
        {
            Id = $"{y:D4}-{m:D2}-{d:D2}",
            Date = new DateTimeOffset(y, m, d, 0, 0, 0, TimeSpan.Zero),
            WorkStart = new DateTimeOffset(y, m, d, 9, 0, 0, TimeSpan.Zero),
            WorkEnd = new DateTimeOffset(y, m, d, 17, 0, 0, TimeSpan.Zero),
        };
    }

    [SkippableFact]
    public async Task Overtime_SaveAndGet_RoundTrips()
    {
        RequireEmulator();
        var repo = new OvertimeRepository(fixture.Db!);
        var uid = NewUid();

        await repo.SaveAsync(uid, -125, null, Ct);
        var result = await repo.GetAsync(uid, null, Ct);

        Assert.Equal(-125, result.Minutes);
        Assert.NotNull(result.LastUpdated);
    }

    [SkippableFact]
    public async Task Settings_SaveAndGet_RoundTrips()
    {
        RequireEmulator();
        var repo = new SettingsRepository(fixture.Db!);
        var uid = NewUid();
        var settings = new SettingsDto
        {
            WeeklyTargetHours = 38.5,
            Workdays = [1, 2, 3, 4],
            NotificationsEnabled = true,
            NotificationTime = "07:30",
            NotificationDays = [1, 3, 5],
            NotifyBreaks = true,
        };

        await repo.SaveAsync(uid, settings, null, Ct);
        var loaded = await repo.GetAsync(uid, null, Ct);

        Assert.Equal(38.5, loaded.WeeklyTargetHours);
        Assert.Equal([1, 2, 3, 4], loaded.Workdays);
        Assert.True(loaded.NotificationsEnabled);
        Assert.Equal("07:30", loaded.NotificationTime);
        Assert.Equal([1, 3, 5], loaded.NotificationDays);
        Assert.True(loaded.NotifyBreaks);
    }

    [SkippableFact]
    public async Task Profile_DefaultsToNonPremium_WhenMissing()
    {
        RequireEmulator();
        var repo = new ProfileRepository(fixture.Db!);
        var uid = NewUid();

        var profile = await repo.GetAsync(uid, Ct);

        Assert.Equal(uid, profile.Uid);
        Assert.False(profile.IsPremium);
    }

    // ── Multi-Profile (siehe #138/#239) ────────────────────────────────────

    [SkippableFact]
    public async Task WorkEntry_DifferentProfiles_AreIsolated()
    {
        RequireEmulator();
        var repo = new WorkEntryRepository(fixture.Db!);
        var uid = NewUid();
        var defaultEntry = new WorkEntryDto
        {
            Id = "2026-06-05",
            Date = new DateTimeOffset(2026, 6, 5, 0, 0, 0, TimeSpan.Zero),
            WorkStart = new DateTimeOffset(2026, 6, 5, 8, 0, 0, TimeSpan.Zero),
        };
        var secondProfileEntry = new WorkEntryDto
        {
            Id = "2026-06-05",
            Date = new DateTimeOffset(2026, 6, 5, 0, 0, 0, TimeSpan.Zero),
            WorkStart = new DateTimeOffset(2026, 6, 5, 9, 0, 0, TimeSpan.Zero),
        };

        await repo.SaveAsync(uid, defaultEntry, null, Ct);
        await repo.SaveAsync(uid, secondProfileEntry, "second", Ct);

        var defaultMonth = await repo.GetMonthAsync(uid, 2026, 6, null, Ct);
        var secondMonth = await repo.GetMonthAsync(uid, 2026, 6, "second", Ct);

        Assert.Equal(defaultEntry.WorkStart, Assert.Single(defaultMonth).WorkStart);
        Assert.Equal(secondProfileEntry.WorkStart, Assert.Single(secondMonth).WorkStart);
    }

    [SkippableFact]
    public async Task Overtime_DifferentProfiles_AreIsolated()
    {
        RequireEmulator();
        var repo = new OvertimeRepository(fixture.Db!);
        var uid = NewUid();

        await repo.SaveAsync(uid, 60, null, Ct);
        await repo.SaveAsync(uid, -30, "second", Ct);

        Assert.Equal(60, (await repo.GetAsync(uid, null, Ct)).Minutes);
        Assert.Equal(-30, (await repo.GetAsync(uid, "second", Ct)).Minutes);
    }

    [SkippableFact]
    public async Task WorkProfile_AddAndGetAll_RoundTrips()
    {
        RequireEmulator();
        var repo = new WorkProfileRepository(fixture.Db!);
        var uid = NewUid();

        var created = await repo.AddAsync(uid, "Zweitjob", Ct);
        var all = await repo.GetAllAsync(uid, Ct);

        var found = Assert.Single(all);
        Assert.Equal(created.Id, found.Id);
        Assert.Equal("Zweitjob", found.Name);
    }

    [SkippableFact]
    public async Task WorkProfile_Delete_RemovesProfileAndItsData()
    {
        RequireEmulator();
        var profileRepo = new WorkProfileRepository(fixture.Db!);
        var entryRepo = new WorkEntryRepository(fixture.Db!);
        var uid = NewUid();
        var profile = await profileRepo.AddAsync(uid, "Zweitjob", Ct);
        await entryRepo.SaveAsync(uid, new WorkEntryDto
        {
            Id = "2026-06-05",
            Date = new DateTimeOffset(2026, 6, 5, 0, 0, 0, TimeSpan.Zero),
            WorkStart = new DateTimeOffset(2026, 6, 5, 8, 0, 0, TimeSpan.Zero),
        }, profile.Id, Ct);

        await profileRepo.DeleteAsync(uid, profile.Id, Ct);

        Assert.Empty(await profileRepo.GetAllAsync(uid, Ct));
        Assert.Empty(await entryRepo.GetMonthAsync(uid, 2026, 6, profile.Id, Ct));
    }
}
