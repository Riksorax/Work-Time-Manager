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
}
