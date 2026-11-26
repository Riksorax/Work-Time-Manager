using WorkTimeManager.Api.Contracts;

namespace WorkTimeManager.Api.Domain;

/// <summary>
/// Home-Office-Auswertung (#537). Regel 1:1 aus Mobile <c>calculateHomeOfficeStats</c>
/// (<c>mobile/lib/domain/utils/home_office_stats.dart</c>, #282), damit sich keine Zahl ändert:
/// gezählt werden Kalendertage mit Arbeitseintrag mit Start (<c>type == work</c>, <c>workStart</c> gesetzt; offene
/// Einträge zählen, leere manuelle nicht). Urlaub, Krank und Feiertag zählen nie, auch mit gesetztem Flag. Mehrere
/// Einträge am selben Kalendertag zählen einmal; der Tag ist Home-Office, wenn irgendein Eintrag das Flag trägt.
/// </summary>
public static class HomeOfficeCalculator
{
    /// <summary>
    /// Jahreswerte, 12 Monate und Home-Office-Tage für <paramref name="year"/>. Einträge außerhalb des Jahres werden
    /// ignoriert. Der Kalendertag eines Eintrags kommt aus <see cref="EntryDays.Of"/> (wie Mobile <c>entryDay</c>).
    /// </summary>
    public static HomeOfficeReportDto Calculate(IReadOnlyList<WorkEntryDto> entries, int year)
    {
        var days = new SortedDictionary<DateOnly, bool>();
        foreach (var e in entries)
        {
            if (e.Type != "work" || e.WorkStart is null) continue;
            var day = EntryDays.Of(e);
            if (day.Year != year) continue;
            days[day] = (days.TryGetValue(day, out var isHome) && isHome) || e.IsHomeOffice == true;
        }

        var homeOfficeDates = days.Where(d => d.Value).Select(d => d.Key).ToList();
        var months = Enumerable.Range(1, 12).Select(m =>
        {
            var inMonth = days.Where(d => d.Key.Month == m).ToList();
            var home = inMonth.Count(d => d.Value);
            return new HomeOfficeMonthDto(m, home, inMonth.Count - home, inMonth.Count, Ratio(home, inMonth.Count));
        }).ToList();

        return new HomeOfficeReportDto
        {
            Year = year,
            HomeOfficeDays = homeOfficeDates.Count,
            OfficeDays = days.Count - homeOfficeDates.Count,
            TotalDays = days.Count,
            HomeOfficeRatio = Ratio(homeOfficeDates.Count, days.Count),
            Months = months,
            HomeOfficeDates = homeOfficeDates,
        };
    }

    /// <summary>Wie Dart <c>homeOfficeDays / totalDays</c> (IEEE-Double), <c>null</c> ohne Bezugstage.</summary>
    private static double? Ratio(int home, int total) => total == 0 ? null : (double)home / total;
}

/// <summary>Kalendertag eines Eintrags (#537), wie Mobile <c>entryDay</c> bzw. Web <c>entryDayKey</c> (#418/#407).</summary>
public static class EntryDays
{
    /// <summary>
    /// Ist die <c>id</c> exakt <c>yyyy-MM-dd</c> und ein existierender Tag, kommt der Tag aus der <c>id</c> (der Tages-Key
    /// des Monatsdokuments); sonst aus den UTC-Feldern von <c>date</c> (UTC-Mitternacht des Kalendertags).
    /// </summary>
    public static DateOnly Of(WorkEntryDto entry)
    {
        var id = entry.Id;
        if (id.Length == 10 && id[4] == '-' && id[7] == '-'
            && id.Where((c, i) => i is not (4 or 7)).All(char.IsAsciiDigit))
        {
            var y = int.Parse(id.AsSpan(0, 4));
            var m = int.Parse(id.AsSpan(5, 2));
            var d = int.Parse(id.AsSpan(8, 2));
            if (y >= 1 && m is >= 1 and <= 12 && d >= 1 && d <= DateTime.DaysInMonth(y, m)) return new DateOnly(y, m, d);
        }

        var utc = entry.Date.UtcDateTime;
        return new DateOnly(utc.Year, utc.Month, utc.Day);
    }
}
