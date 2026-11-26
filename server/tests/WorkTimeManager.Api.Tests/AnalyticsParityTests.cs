using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Text.Json.Nodes;
using WorkTimeManager.Api.Contracts;
using WorkTimeManager.Api.Domain;
using WorkTimeManager.Api.Endpoints;

namespace WorkTimeManager.Api.Tests;

/// <summary>
/// Gemeinsame Testfälle (#537) für Insights (<c>testdata/insights-parity/cases.json</c>) und Home-Office
/// (<c>testdata/home-office-parity/cases.json</c>). Dieselben Dateien schickt Mobile durch die <b>heutigen</b>
/// Dart-Funktionen (<c>insights_parity_tz_test.dart</c>, <c>home_office_parity_tz_test.dart</c>) und verlangt dieselben
/// Ergebnisse: damit ist belegt, dass der Umzug ins Backend keine Zahl ändert. Die erwarteten Werte schreibt das
/// Backend mit <c>ANALYTICS_PARITY_UPDATE=1</c> (siehe README in den Ordnern).
/// </summary>
public abstract class AnalyticsParityTestsBase
{
    protected static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    protected abstract string Folder { get; }

    /// <summary>Rechnet einen Fall wie der Endpunkt (Einträge vorher wie <c>GetRangeAsync</c> nach <c>date</c> gefiltert).</summary>
    protected abstract JsonNode Compute(JsonNode testCase);

    protected string CasesPath => Path.Combine(AppContext.BaseDirectory, Folder, "cases.json");

    protected static List<JsonNode> LoadCases(string path) =>
        JsonNode.Parse(File.ReadAllText(path))!["cases"]!.AsArray().Select(c => c!).ToList();

    protected static TheoryData<string> Names(string folder)
    {
        var data = new TheoryData<string>();
        foreach (var c in LoadCases(Path.Combine(AppContext.BaseDirectory, folder, "cases.json")))
            data.Add(c["name"]!.GetValue<string>());
        return data;
    }

    protected static List<WorkEntryDto> Entries(JsonNode testCase) =>
        testCase["entries"].Deserialize<List<WorkEntryDto>>(Json)!;

    /// <summary>Wie <c>WorkEntryRepository.GetRangeAsync</c>: Kalendertag aus den UTC-Feldern von <c>date</c>.</summary>
    protected static List<WorkEntryDto> InRange(IEnumerable<WorkEntryDto> entries, DateOnly from, DateOnly to) =>
        entries.Where(e =>
        {
            var d = new DateOnly(e.Date.Year, e.Date.Month, e.Date.Day);
            return d >= from && d <= to;
        }).ToList();

    protected static JsonNode Normalize(object value) =>
        JsonNode.Parse(JsonSerializer.SerializeToNode(value, Json)!.ToJsonString())!;

    protected void AssertCase(string name, int minCases)
    {
        if (Environment.GetEnvironmentVariable("ANALYTICS_PARITY_UPDATE") == "1") UpdateSourceFile();

        var all = LoadCases(CasesPath);
        Assert.True(all.Count >= minCases, $"Nur {all.Count} Fälle aus {CasesPath}.");
        Assert.Equal(all.Count, all.Select(c => c["name"]!.GetValue<string>()).Distinct().Count());

        var testCase = all.Single(c => c["name"]!.GetValue<string>() == name);
        var expected = testCase["expected"]
            ?? throw new Xunit.Sdk.XunitException($"Fall '{name}' hat keine erwarteten Werte (ANALYTICS_PARITY_UPDATE=1).");
        var actual = Compute(testCase);
        Assert.True(JsonNode.DeepEquals(expected, actual),
            $"Fall '{name}':\n erwartet {expected.ToJsonString()}\n berechnet {actual.ToJsonString()}");
    }

    private static readonly object UpdateLock = new();
    private static readonly HashSet<string> Updated = new();

    private void UpdateSourceFile([CallerFilePath] string thisFile = "")
    {
        lock (UpdateLock)
        {
            if (!Updated.Add(Folder)) return;
            var source = Path.GetFullPath(Path.Combine(
                Path.GetDirectoryName(thisFile)!, "..", "..", "..", "testdata", Folder, "cases.json"));
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
        }
    }
}

public class InsightsParityTests : AnalyticsParityTestsBase
{
    protected override string Folder => "insights-parity";

    public static TheoryData<string> CaseNames() => Names("insights-parity");

    [Theory]
    [MemberData(nameof(CaseNames))]
    public void Case_MatchesInsightsCalculator(string name) => AssertCase(name, 12);

    protected override JsonNode Compute(JsonNode testCase)
    {
        var settings = testCase["settings"].Deserialize<SettingsDto>(Json)!;
        var refDate = DateOnly.ParseExact(
            testCase["referenceDate"]!.GetValue<string>(), "yyyy-MM-dd", CultureInfo.InvariantCulture);
        Assert.True(ReportEndpoints.TryParseTimeZone(testCase["timeZone"]!.GetValue<string>(), out var zone));
        var (from, to) = InsightsCalculator.Range(refDate);
        return Normalize(InsightsCalculator.Calculate(InRange(Entries(testCase), from, to), refDate, settings, zone));
    }
}

public class HomeOfficeParityTests : AnalyticsParityTestsBase
{
    protected override string Folder => "home-office-parity";

    public static TheoryData<string> CaseNames() => Names("home-office-parity");

    [Theory]
    [MemberData(nameof(CaseNames))]
    public void Case_MatchesHomeOfficeCalculator(string name) => AssertCase(name, 5);

    protected override JsonNode Compute(JsonNode testCase)
    {
        var year = testCase["year"]!.GetValue<int>();
        var entries = InRange(Entries(testCase), new DateOnly(year, 1, 1), new DateOnly(year, 12, 31));
        return Normalize(HomeOfficeCalculator.Calculate(entries, year));
    }
}
