using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Nodes;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Domain;

namespace WorkTimeManager.Api.Tests;

/// <summary>
/// Gemeinsame Report-Testfälle (#535): liest <c>testdata/report-parity/cases.json</c> (Repo-Wurzel) und prüft jeden Fall
/// gegen <see cref="ReportCalculator"/>. Dieselbe Datei prüft das Web (<c>report-calculator.parity.tz.spec.ts</c>).
/// Die erwarteten Werte stammen aus dem Backend: <c>REPORT_PARITY_UPDATE=1</c> schreibt sie neu (siehe README im Ordner).
/// <c>totalOvertimeMs</c> des Monatsberichts ist seit #535 (Teil 1b) Teil der erwarteten Werte (= gespeicherter Saldo).
/// </summary>
public class ReportParityTests
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private static readonly string CasesPath = Path.Combine(AppContext.BaseDirectory, "report-parity", "cases.json");

    public static TheoryData<string> CaseNames()
    {
        var data = new TheoryData<string>();
        foreach (var c in LoadCases(CasesPath)) data.Add(c["name"]!.GetValue<string>());
        return data;
    }

    [Fact]
    public void Cases_AreLoaded_AndNamesUnique()
    {
        var names = LoadCases(CasesPath).Select(c => c["name"]!.GetValue<string>()).ToList();
        Assert.True(names.Count >= 15, $"Nur {names.Count} Fälle geladen aus {CasesPath}.");
        Assert.Equal(names.Count, names.Distinct().Count());
    }

    [Theory]
    [MemberData(nameof(CaseNames))]
    public void Case_MatchesReportCalculator(string name)
    {
        if (Environment.GetEnvironmentVariable("REPORT_PARITY_UPDATE") == "1") UpdateSourceFile();

        var testCase = LoadCases(CasesPath).Single(c => c["name"]!.GetValue<string>() == name);
        var expected = testCase["expected"]
            ?? throw new Xunit.Sdk.XunitException($"Fall '{name}' hat keine erwarteten Werte (REPORT_PARITY_UPDATE=1).");
        var actual = Compute(testCase);

        foreach (var report in new[] { "daily", "weekly", "monthly" })
        {
            var exp = expected[report]!.ToJsonString();
            var act = actual[report]!.ToJsonString();
            Assert.True(JsonNode.DeepEquals(expected[report], actual[report]),
                $"Fall '{name}', {report}:\n erwartet {exp}\n berechnet {act}");
        }
    }

    /// <summary>Rechnet die drei Berichte eines Falls wie die Endpunkte (Monatseinträge für Tag/Monat, alle für die Woche).</summary>
    private static JsonObject Compute(JsonNode testCase)
    {
        var settings = testCase["settings"].Deserialize<SettingsDto>(Json)!;
        var entries = testCase["entries"].Deserialize<List<WorkEntryDto>>(Json)!;
        var refDate = DateOnly.ParseExact(testCase["referenceDate"]!.GetValue<string>(), "yyyy-MM-dd", CultureInfo.InvariantCulture);
        var stored = testCase["storedOvertimeMs"]?.GetValue<long>() ?? 0;
        var monthPrefix = refDate.ToString("yyyy-MM", CultureInfo.InvariantCulture);
        var monthEntries = entries.Where(e => e.Id.StartsWith(monthPrefix, StringComparison.Ordinal)).ToList();

        var daily = ReportCalculator.CalculateDailyStat(monthEntries, refDate, settings);
        var weekly = ReportCalculator.CalculateWeeklyReport(entries, refDate, settings);
        var monthly = JsonSerializer.SerializeToNode(
            ReportCalculator.CalculateMonthlyReport(monthEntries, refDate, settings, stored), Json)!.AsObject();

        // Über Text normalisieren, damit Zahlen genauso vorliegen wie nach dem Einlesen der Datei.
        return JsonNode.Parse(new JsonObject
        {
            ["daily"] = JsonSerializer.SerializeToNode(daily, Json),
            ["weekly"] = JsonSerializer.SerializeToNode(weekly, Json),
            ["monthly"] = monthly,
        }.ToJsonString())!.AsObject();
    }

    private static List<JsonNode> LoadCases(string path) =>
        JsonNode.Parse(File.ReadAllText(path))!["cases"]!.AsArray().Select(c => c!).ToList();

    private static readonly object UpdateLock = new();
    private static bool _updated;

    /// <summary>Schreibt die erwarteten Werte aller Fälle aus dem Backend in die Quelldatei und in die Kopie im Ausgabeordner.</summary>
    private static void UpdateSourceFile([CallerFilePath] string thisFile = "")
    {
        lock (UpdateLock)
        {
            if (_updated) return;
            var source = Path.GetFullPath(Path.Combine(
                Path.GetDirectoryName(thisFile)!, "..", "..", "..", "testdata", "report-parity", "cases.json"));
            var root = JsonNode.Parse(File.ReadAllText(source))!;
            foreach (var c in root["cases"]!.AsArray())
            {
                c!.AsObject().Remove("expected");
                c.AsObject().Add("expected", Compute(c));
            }
            var text = root.ToJsonString(new JsonSerializerOptions
            {
                WriteIndented = true,
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            }) + "\n";
            File.WriteAllText(source, text);
            File.WriteAllText(CasesPath, text);
            _updated = true;
        }
    }
}
