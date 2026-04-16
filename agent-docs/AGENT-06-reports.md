# Agent 06 — Reports & Statistics

## Rolle
Du implementierst alle Auswertungs-Screens. Der Wochenbericht ist kostenlos, Monats- und Jahresbericht sind Premium. Alle Berechnungen nutzen ausschließlich Funktionen aus `time-calculations.util.ts` (Agent 05).

## Input
- `AGENT-00-flutter-analysis-report.md` (Premium-Gate: Reports)
- Outputs von Agent 03 (PremiumGateComponent, Modelle)
- Outputs von Agent 05 (WorkSessionService, time-calculations.util.ts)
- Outputs von Agent 07 (PremiumService)

## Premium-Gates

| Feature | Free | Premium |
|---|---|---|
| Wochenbericht (Summen) | ✅ | ✅ |
| Wochenbericht (Tagesdetails) | ✅ | ✅ |
| Monatsbericht | ❌ | ✅ |
| Jahresbericht | ❌ | ✅ |
| Kategorie-Auswertung | ❌ | ✅ |
| PDF-Export | ❌ | ✅ |
| CSV-Export | ❌ | ✅ |

## Deine Aufgaben

### 6.1 ReportService

Datei: `src/app/features/reports/services/report.service.ts`

```typescript
@Injectable({ providedIn: 'root' })
export class ReportService {

  getWeeklyReport(weekDate: Date): Observable<WeeklyReport>
  // Lädt Sessions der Woche via WorkSessionService
  // Baut 7 DailyReports (Mo–So) auf
  // Nutzt calculateDailyTotal(), calculateOvertimeMinutes() aus util.ts

  getMonthlyReport(monthDate: Date): Observable<MonthlyReport>
  // Lädt Sessions des Monats
  // Baut WeeklyReports auf (nur Summen, keine DailyReports für Performance)
  // Arbeitstage (Mo–Fr) berechnen für korrektes Monatsziel

  getYearlyReport(year: number): Observable<YearlyReport>
  // 12 MonthlyReports zusammenfassen

  getCategoryBreakdown(start: Date, end: Date): Observable<CategoryBreakdown[]>
  // Nutzt calculateCategoryBreakdown() aus util.ts

  exportToCsv(sessions: WorkSession[], filename: string): void
  // Browser-Download ohne externe Library
  // Spalten: Datum, Startzeit, Endzeit, Pause (Min), Nettozeit, Kategorie, Notiz

  exportToPdf(reportHtml: string, filename: string): void
  // Via window.print() + CSS @media print
  // Oder jspdf wenn komplexes Layout nötig
}
```

Keine Berechnungen im Service — ausschließlich Daten laden und `util.ts` Funktionen aufrufen.

### 6.2 ReportsOverviewComponent (Free)

Route: `/reports`

**Layout:**
```
┌─── Wochen-Selektor (← KW 15, 14.–20. Apr 2025, →) ──────────┐
│                                                                 │
│  ┌─ Gesamt ──────┐  ┌─ Soll ────────┐  ┌─ Überstunden ──────┐│
│  │   32h 15min   │  │   40h 00min   │  │    -7h 45min       ││
│  └───────────────┘  └───────────────┘  └────────────────────┘│
│                                                                 │
│  Balkendiagramm: Tägliche Stunden (Mo–So)                      │
│  [MatProgressBar oder ng2-charts BarChart]                      │
│  Jeder Balken zeigt: Ist-Stunden, Soll-Linie                   │
│                                                                 │
│  ┌─ Tages-Tabelle ──────────────────────────────────────────┐  │
│  │ Mo 14.04 │ 7h 30min │ -0h 30min │ [Details]             │  │
│  │ Di 15.04 │ 8h 45min │ +0h 45min │ [Details]             │  │
│  │ ...                                                       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  [🔒 Monatsbericht] [🔒 Jahresbericht]  ← Premium-Gates        │
└─────────────────────────────────────────────────────────────────┘
```

Woche wechseln: Pfeile navigieren zur Vorwoche/Nächste Woche. Nächste Woche nur bis aktuelle Woche (keine Zukunft).

### 6.3 MonthlyReportComponent (Premium)

Route: `/reports/monthly` [PremiumGuard]

- Monats-Selektor (← April 2025 →)
- Gesamt-Karte: Geleistete Stunden / Soll / Überstunden
- Wochenweise Tabelle (4–5 Zeilen)
- Kategorie-Pie-Chart (`ng2-charts` oder SVG)
- [CSV exportieren] Button

Wenn kein Premium: `<app-premium-gate>` statt dem Content.

### 6.4 YearlyReportComponent (Premium)

Route: `/reports/yearly` [PremiumGuard]

- Jahr-Selektor (← 2024 →)
- Gesamt-Jahresübersicht
- Monatsweise Balkendiagramm (12 Balken)
- Top-Kategorien des Jahres
- [CSV exportieren] Button

### 6.5 PDF-Export (Premium)

CSS `@media print` Stylesheet für sauberen PDF-Druck:
- Sidebar/Header ausblenden
- Report-Content optimieren für A4
- Print-Button triggert `window.print()`
- Browser öffnet nativen Druck-Dialog (Export als PDF)

### 6.6 Diagramm-Bibliothek

Nutze `ng2-charts` (Chart.js Wrapper für Angular):
```bash
npm install ng2-charts chart.js
```

Diagramm-Typen:
- Balkendiagramm (Wochenbericht): `BaseChartDirective` mit `type: 'bar'`
- Pie-Chart (Kategorien): `type: 'doughnut'`
- Linien-Chart (Jahrestrend): `type: 'line'`

Design: Angular Material-Farben für Charts nutzen.

## Output
- `src/app/features/reports/services/report.service.ts`
- `src/app/features/reports/components/reports-overview/`
- `src/app/features/reports/components/monthly-report/`
- `src/app/features/reports/components/yearly-report/`
- `src/styles/print.scss`

## Tests
- `report.service.spec.ts`: Mock WorkSessionService, prüfe korrekte Aggregation
- Wochenbericht: Montag = Wochenstart, 7 Tage, korrekte Summen
- Überstunden: positiv und negativ
