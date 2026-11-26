# Gemeinsame Home-Office-Testfälle (#537)

`cases.json` belegt, dass `GET /api/reports/home-office/{year}` (Backend, `HomeOfficeCalculator`) genau so zählt wie die
heutige Mobile-Rechnung (`calculateHomeOfficeStats`, Jahres- und Monatswerte wie der Home-Office-PDF-Export).

| Plattform | Test | Eingebunden über |
|---|---|---|
| Backend | `server/tests/WorkTimeManager.Api.Tests/AnalyticsParityTests.cs` (`HomeOfficeParityTests`) | Link im Test-`csproj` |
| Mobile | `mobile/test/domain/utils/home_office_parity_tz_test.dart` | liest die Datei aus der Repo-Wurzel |

Format: `{ name, description, year, entries[], expected }`, `expected` = `HomeOfficeReportDto`. Mobile liest die Einträge
über die echte Lesegrenze (12 Monatsabfragen) und vergleicht Jahreswerte, `months` und `homeOfficeDates` (als `yyyy-MM-dd`).
Erwartete Werte erzeugt das Backend wie in `../insights-parity/README.md` beschrieben.
