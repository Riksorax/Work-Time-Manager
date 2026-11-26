# Gemeinsame Insights-Testfälle (#537)

`cases.json` belegt, dass `GET /api/reports/insights/{y}/{m}/{d}` (Backend, `InsightsCalculator`) genau so rechnet wie die
heutige Mobile-Rechnung (`insights_utils.dart` über `InsightsViewModel`). Die Home-Office-Fälle liegen in
`../home-office-parity/`.

| Plattform | Test | Eingebunden über |
|---|---|---|
| Backend | `server/tests/WorkTimeManager.Api.Tests/AnalyticsParityTests.cs` (`InsightsParityTests`) | Link im Test-`csproj` |
| Mobile | `mobile/test/domain/utils/insights_parity_tz_test.dart` | liest die Datei aus der Repo-Wurzel |

## Format

```jsonc
{
  "cases": [
    {
      "name": "normale-wochen-berlin",       // eindeutig, kebab-case
      "description": "…",
      "settings": { "weeklyTargetHours": 40, "workdays": [1, 2, 3, 4, 5] },
      "referenceDate": "2026-06-10",         // Bezugstag (heute des Clients)
      "timeZone": "Europe/Berlin",           // Query-Parameter tz (IANA)
      "entries": [ /* WorkEntryDto wie die API, mehrere Einträge mit derselben id erlaubt */ ],
      "expected": { /* InsightsReportDto */ }
    }
  ]
}
```

- Das Backend bekommt die Einträge wie aus `GetRangeAsync` (nach `date` auf das Fenster gefiltert), Mobile liest sie über
  die echte Lesegrenze (`ApiClient` → `WorkRepositoryImpl`) und rechnet mit dem echten `InsightsViewModel` (Monatsfenster,
  Tagessoll aus den Einstellungen).
- **Zeitzone:** Wochentage und Serie hängen nicht von der Zone ab und werden in jeder Zone verglichen. Die Startstunde
  der Heatmap hängt von der Zone ab: Mobile vergleicht die Heatmap nur, wenn `TZ` des Testprozesses gleich `timeZone`
  des Falls ist (CI: `Europe/Berlin` und `America/Los_Angeles`; `UTC` lokal mit `TZ=UTC`).

## Fall ergänzen

1. Fall ohne `expected` anlegen (feste Daten, nie „heute“).
2. Erwartete Werte aus dem Backend schreiben:

   ```bash
   cd server
   ANALYTICS_PARITY_UPDATE=1 dotnet test WorkTimeManager.slnx --filter "FullyQualifiedName~InsightsParity|FullyQualifiedName~HomeOfficeParity"
   ```

3. Werte von Hand prüfen, dann den Mobile-Test laufen lassen (`flutter test test/domain/utils/insights_parity_tz_test.dart`,
   zusätzlich mit `TZ=Europe/Berlin` und `TZ=America/Los_Angeles`). Weicht Mobile ab, ist das ein Befund, kein Grund, die
   Datei anzupassen.
