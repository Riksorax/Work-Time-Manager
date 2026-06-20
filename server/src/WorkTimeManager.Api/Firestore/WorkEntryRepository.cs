using System.Globalization;
using Google.Cloud.Firestore;
using Grpc.Core;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Firestore.Documents;

namespace WorkTimeManager.Api.Firestore;

/// <summary>Zugriff auf <c>users/{uid}/work_entries/{yyyy-MM}</c> (Flutter-kompatibles days-Map-Format).</summary>
public sealed class WorkEntryRepository(FirestoreDb db)
{
    private DocumentReference MonthDoc(string uid, int year, int month) =>
        db.Collection("users").Document(uid)
          .Collection("work_entries").Document(FirestoreMappings.MonthId(year, month));

    public async Task<IReadOnlyList<WorkEntryDto>> GetMonthAsync(
        string uid, int year, int month, CancellationToken ct)
    {
        var snapshot = await MonthDoc(uid, year, month).GetSnapshotAsync(ct);
        if (!snapshot.Exists)
        {
            return Array.Empty<WorkEntryDto>();
        }

        var doc = snapshot.ConvertTo<MonthDocument>();
        return doc.Days
            .Where(kvp => int.TryParse(kvp.Key, NumberStyles.Integer, CultureInfo.InvariantCulture, out _))
            .Select(kvp =>
            {
                var day = int.Parse(kvp.Key, CultureInfo.InvariantCulture);
                return FirestoreMappings.ToDto(kvp.Value, FirestoreMappings.EntryId(year, month, day));
            })
            .OrderBy(e => e.Date)
            .ToList();
    }

    /// <summary>
    /// Lädt alle Einträge der Woche (Mo–So), die <paramref name="date"/> enthält — über
    /// Monatsgrenzen hinweg (1–2 Monatsdokumente). Für den Wochenbericht.
    /// </summary>
    public async Task<IReadOnlyList<WorkEntryDto>> GetWeekAsync(
        string uid, DateOnly date, CancellationToken ct)
    {
        var (start, end) = Domain.ReportCalculator.WeekBounds(date);
        var months = new[] { (start.Year, start.Month), (end.Year, end.Month) }.Distinct();

        var all = new List<WorkEntryDto>();
        foreach (var (year, month) in months)
        {
            all.AddRange(await GetMonthAsync(uid, year, month, ct));
        }
        return all;
    }

    public async Task<WorkEntryDto?> GetDayAsync(
        string uid, int year, int month, int day, CancellationToken ct)
    {
        var snapshot = await MonthDoc(uid, year, month).GetSnapshotAsync(ct);
        if (!snapshot.Exists)
        {
            return null;
        }

        var doc = snapshot.ConvertTo<MonthDocument>();
        return doc.Days.TryGetValue(day.ToString(CultureInfo.InvariantCulture), out var dayData)
            ? FirestoreMappings.ToDto(dayData, FirestoreMappings.EntryId(year, month, day))
            : null;
    }

    public async Task SaveAsync(string uid, WorkEntryDto entry, CancellationToken ct)
    {
        var dayKey = FirestoreMappings.DayKey(entry.Date);
        var update = new Dictionary<string, object>
        {
            ["days"] = new Dictionary<string, object>
            {
                [dayKey] = FirestoreMappings.ToDocument(entry),
            },
        };
        await MonthDoc(uid, entry.Date.Year, entry.Date.Month)
            .SetAsync(update, SetOptions.MergeAll, ct);
    }

    public async Task DeleteAsync(string uid, int year, int month, int day, CancellationToken ct)
    {
        var dayKey = day.ToString(CultureInfo.InvariantCulture);
        try
        {
            await MonthDoc(uid, year, month).UpdateAsync(
                new Dictionary<FieldPath, object> { [new FieldPath("days", dayKey)] = FieldValue.Delete },
                cancellationToken: ct);
        }
        catch (RpcException ex) when (ex.StatusCode == StatusCode.NotFound)
        {
            // Monatsdokument existiert nicht — nichts zu löschen.
        }
    }
}
