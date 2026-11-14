# Gemeinsame Report-Testfälle (#535)

`cases.json` enthält Testfälle für Tages-, Wochen- und Monatsbericht, die alle Plattformen gegen ihre Rechnung
prüfen. Ziel: Backend, Web (und später Mobile) rechnen nachweisbar gleich.

| Plattform | Test | Eingebunden über |
|---|---|---|
| Backend | `server/tests/WorkTimeManager.Api.Tests/ReportParityTests.cs` | Link im Test-`csproj` (`report-parity/*.json` im Ausgabeordner) |
| Web | `web/src/app/domain/services/report-calculator.parity.tz.spec.ts` | JSON-Import; läuft in CI auch unter `TZ=America/Los_Angeles` und `Pacific/Auckland` |

## Format

```jsonc
{
  "cases": [
    {
      "name": "normale-woche",              // eindeutig, kebab-case
      "description": "…",                   // was der Fall abdeckt
      "settings": { "weeklyTargetHours": 40, "workdays": [1, 2, 3, 4, 5] },   // ISO-Wochentage 1 = Mo … 7 = So
      "storedOvertimeMs": 0,                // gespeicherter Saldo (nur Eingabe für den Monatsbericht)
      "referenceDate": "2026-06-03",        // Bezugstag (yyyy-MM-dd)
      "entries": [ /* WorkEntryDto wie die API: id yyyy-MM-dd, date (UTC-Mitternacht), workStart, workEnd,
                      type, manualOvertimeMinutes, breaks [{ id, name, isAutomatic, start, end }] */ ],
      "expected": {
        "daily":   { /* DailyStatDto */ },
        "weekly":  { /* WeeklyReportDto */ },
        "monthly": { /* MonthlyReportDto ohne totalOvertimeMs */ }
      }
    }
  ]
}
```

Eingaben je Bericht (wie die Endpunkte):

- **Tag** und **Monat** bekommen nur die Einträge, deren `id` im Monat des Bezugstags liegt.
- **Woche** bekommt alle Einträge des Falls (die Rechnung filtert selbst auf die ISO-Woche des Bezugstags).

`totalOvertimeMs` des Monatsberichts ist bewusst **nicht** Teil der erwarteten Werte: Die Regel dafür ist offen.

**Zeitzonen:** Zeitpunkte (`workStart`, `workEnd`, Pausen) sind UTC-Instants auf volle Minuten, der Kalendertag kommt
aus der `id`. Berichtstage (`start`, `end`, `month`, `days[].date`) liefert das Backend als UTC-Mitternacht; die Clients
vergleichen sie als Kalendertag. Dadurch hängt kein Fall von der Zeitzone des Testlaufs ab.

## Fall ergänzen

1. Fall in `cases.json` ohne `expected` anlegen (Name eindeutig, Daten fest, nie „heute“).
2. Erwartete Werte **aus dem Backend** erzeugen (schreibt `expected` aller Fälle neu):

   ```bash
   cd server
   REPORT_PARITY_UPDATE=1 dotnet test WorkTimeManager.slnx --filter "FullyQualifiedName~ReportParity"
   ```

3. Die neuen Werte von Hand auf Plausibilität prüfen und den Diff von `cases.json` ansehen: Bestehende Fälle dürfen
   sich nur ändern, wenn die Rechenregel im Backend bewusst geändert wurde.
4. Backend- und Web-Tests laufen lassen. Weicht das Web ab, ist das ein Befund (Backend ist kanonisch), kein Grund,
   die erwarteten Werte anzupassen.
