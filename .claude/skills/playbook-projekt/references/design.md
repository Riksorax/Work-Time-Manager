# Work-Time-Manager — UI-Design (Flutter → Angular)

WTM-Besonderheiten zu `playbook-angular`, Referenz `design`. Wörtlich aus der bisherigen Agent-Datei.

> **Stitch:** Die Stitch API antwortete zuletzt mit HTTP 405. Das UI wird manuell nach der Flutter-Vorlage gebaut; im UI-Report vermerken.

## Design-System dieser App

### Farben (aus Flutter-Theme portieren)
```scss
// Primär-Palette (analog zu Flutter MaterialColor)
$primary: #1976D2;
$primary-light: #42A5F5;
$on-primary: #FFFFFF;

// Semantische Farben
$color-work: #4CAF50;      // Arbeitszeit grün
$color-break: #FF9800;     // Pause orange
$color-overtime: #F44336;  // Überstunden rot
$color-vacation: #9C27B0;  // Urlaub lila
$color-sick: #607D8B;      // Krank grau-blau

// Surface (Light/Dark via Angular Material theme)
```

### Typographie
```scss
// Zeitanzeige (Timer, große Zahlen)
.time-display { font-size: 3rem; font-weight: 300; font-variant-numeric: tabular-nums; }

// Labels (Deutsche Beschriftungen)
.label { font-size: 0.875rem; color: var(--mat-sys-on-surface-variant); }
```

### Responsive Layout-Prinzipien
```scss
// Mobile first — analog zur Flutter-App
.container {
  padding: 16px;               // Flutter: EdgeInsets.all(16)

  @media (min-width: 768px) {
    max-width: 600px;
    margin: 0 auto;
    padding: 24px;
  }

  @media (min-width: 1024px) {
    display: grid;
    grid-template-columns: 1fr 1fr;
    max-width: 1200px;
    gap: 24px;
  }
}
```

## Flutter-Screen → Angular-Component Mapping

### DashboardScreen
```
Flutter:          Angular:
─────────────     ───────────────
AppBar            <mat-toolbar> in Shell-Layout
Column            flex-direction: column
Timer-Display     <app-timer-display> Komponente
BreakButton       <button mat-raised-button>
OverviewCards     <mat-card> Grid
```

### ReportsPage
```
Flutter:          Angular:
─────────────     ───────────────
CalendarView      <mat-calendar> oder eigene Grid-Impl
ListTile          <mat-list-item>
BarChart          eigene SVG-Komponente (shared/components/charts/), keine Chart-Bibliothek
```

### SettingsPage
```
Flutter:          Angular:
─────────────     ───────────────
SwitchListTile    <mat-slide-toggle> in <mat-list>
TextField         <mat-form-field> + <input matInput>
DropdownButton    <mat-select>
```

## Diagramme (Web, Muster seit #531)

- **Eigene SVG-Komponenten** unter `web/src/app/shared/components/charts/` (`BarChartComponent`, `LineChartComponent`, Basis
  `ChartBase`); keine Chart-Bibliothek, keine neue Abhängigkeit. Werte kommen fertig vom Backend, der Client skaliert und
  formatiert nur (`shared/utils/chart-scale.util.ts`).
- **Eingabe:** `points: ChartPoint[]` (Kurz- und Langbezeichnung, Wert, optional Soll bzw. Zusatzwert, `hasData`, `partial`) und
  übersetzte `labels: ChartLabels` von der aufrufenden Komponente.
- **Lesbarkeit:** Pixelbreite per `ResizeObserver` statt `viewBox`; Achsenbeschriftungen werden auf Handy-Breite ausgedünnt; Lücken
  und laufender Zeitraum sind über Form erkennbar (gestrichelt, hohl), nicht nur über Farbe, und stehen in der Legende.
- **Barrierefreiheit:** SVG `role="group"` mit `aria-label`, jede Spalte `role="img"` mit Werten im `aria-label`; ein Tab-Stopp je
  Diagramm (Roving tabindex, Pfeile/Home/End), Hover/Fokus füllen eine Detailzeile; Textalternative als visuell versteckte Tabelle.
- **Farben:** nur `--mat-sys-*` (Balken/Linie `primary`, Soll `on-surface`, Raster `outline-variant`, Nulllinie und Achsen
  `on-surface-variant`), dadurch hell und dunkel ohne eigene Regeln.
