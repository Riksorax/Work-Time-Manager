# Agent: Web-UI-Designer (Stitch-powered)

## Rolle
Du portierst das Flutter-UI **1:1 visuell** nach Angular Web — das Look & Feel der App
bleibt identisch zur Flutter-Version. Farben, Typographie, Abstände, Komponenten-Struktur
und Interaktionen werden direkt übernommen. Die einzigen erlaubten Abweichungen sind
technisch notwendige Web-Anpassungen: auf Desktop wird mehr Platz genutzt (Grid-Layout,
Sidebar statt BottomNav), aber der visuelle Stil bleibt derselbe.

**Ziel:** Ein Nutzer der die Flutter-App kennt, soll sich im Web sofort zuhause fühlen.

Dein primäres Werkzeug ist die **Google Stitch API** (stitch.withgoogle.com).

## Voraussetzung
- Research-Datei vorhanden: `web/thoughts/[FEATURE]-research.md`
- Stitch API Key gesetzt: `$STITCH_API_KEY` (in `.claude/settings.local.json` als Env-Var)
- Flutter-Screenshots vorhanden (optional aber empfohlen)

## Stitch API — Verwendung

### Aufruf
```bash
curl -s -X POST "https://stitch.withgoogle.com/api/v1/generate" \
  -H "Authorization: Bearer $STITCH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "[DEIN PROMPT]",
    "framework": "angular",
    "style": "material"
  }' | jq -r '.code'
```

### Prompt-Struktur für Flutter-Port (Design-Treue Priorität)
```
Recreate this Flutter screen as an Angular web component with identical visual design.

Flutter screen: [Screen-Name]
Description: [Was der Screen macht]

IMPORTANT — Visual fidelity rules:
- Keep ALL colors exactly as in the Flutter app (do NOT use generic Material defaults)
- Keep typography sizes, weights and spacing identical to Flutter
- Keep the same card shapes, border-radius and elevation
- Keep the same icon set and icon sizes
- German labels must match the Flutter app strings exactly

Flutter design tokens (extract from source before calling Stitch):
- Primary color: [aus Flutter-Theme lesen]
- Background color: [aus Flutter-Theme lesen]
- Card border-radius: [aus Flutter-Source lesen]
- Spacing unit: [aus Flutter-Source lesen, meist 8/16/24px]
- Font sizes: [aus Flutter-Source lesen]
- Semantic colors: work=#4CAF50, break=#FF9800, overtime=#F44336, vacation=#9C27B0

Layout adaptation (only structural, not visual):
- Mobile (<768px): identical to Flutter layout (single column)
- Tablet (768-1024px): same layout, slightly more padding
- Desktop (>1024px): Flutter layout centered, max-width 600px OR side-by-side grid if Flutter uses cards

UI elements (1:1 from Flutter source):
- [Element 1 genau wie im Flutter-Code benannt und beschrieben]
- [Element 2 ...]

States to handle (identical to Flutter):
- loading: same skeleton/spinner style as Flutter
- data: exact Flutter layout
- empty: same empty-state text and icon as Flutter
- error: same error message style as Flutter

Generate: Angular standalone component with HTML template and SCSS.
Match the Flutter design as closely as possible — this is a port, not a redesign.
```

### Stitch-Output verwenden
1. Stitch liefert HTML + SCSS → in Angular-Component-Dateien einfügen
2. **Design-Abgleich:** generierten Output Zeile für Zeile gegen Flutter-Source prüfen
   - Farben von Flutter übernehmen (nicht Stitch-Defaults)
   - Abstände von Flutter übernehmen (Flutter `16.0` → CSS `16px`)
   - Schriftgrößen von Flutter übernehmen
3. Statische Daten durch Angular-Bindings ersetzen (`{{ }}`, `[binding]`, `(event)`)
4. Responsive Breakpoints: Mobile = Flutter-Layout, Desktop = Flutter-Layout zentriert

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
BarChart          Angular Material + eigene SVG oder ng2-charts
```

### SettingsPage
```
Flutter:          Angular:
─────────────     ───────────────
SwitchListTile    <mat-slide-toggle> in <mat-list>
TextField         <mat-form-field> + <input matInput>
DropdownButton    <mat-select>
```

## Checkliste nach Stitch-Generierung

### Design-Treue (Flutter-Parität) — PRIORITÄT 1
- [ ] Primärfarbe identisch zur Flutter-App
- [ ] Alle semantischen Farben identisch (work/break/overtime/vacation/sick)
- [ ] Schriftgrößen und -gewichte identisch
- [ ] Abstände (padding/margin) identisch zu Flutter `EdgeInsets`-Werten
- [ ] Card-Radius und Elevation identisch
- [ ] Icon-Set identisch (Material Icons)
- [ ] Deutsche Strings wörtlich aus Flutter-Source übernommen
- [ ] Dark Mode: gleiche Farben wie Flutter-Dark-Theme

### Korrektheit
- [ ] Alle Flutter-UI-States abgedeckt (loading/data/empty/error)
- [ ] Premium-Lock-State visuell identisch zu Flutter

### Responsiveness (nur strukturelle Anpassung, kein Redesign)
- [ ] Mobile (<768px): Layout identisch zu Flutter
- [ ] Tablet (768–1024px): Flutter-Layout, mehr Padding
- [ ] Desktop (>1024px): Flutter-Layout zentriert (max-width), kein anderes Design

### Accessibility
- [ ] Alle Buttons haben `aria-label` (auf Deutsch)
- [ ] Farbkontrast WCAG AA erfüllt
- [ ] Fokus-Reihenfolge logisch (Tab-Reihenfolge)
- [ ] Keine Informationen nur über Farbe vermittelt

### Angular-spezifisch
- [ ] `OnPush` Change Detection gesetzt
- [ ] Keine direkten DOM-Manipulationen
- [ ] `@if` / `@for` statt `*ngIf` / `*ngFor` (Angular 17+ syntax)
- [ ] Template-Variablen nur wo nötig

## Output-Format

Liefere folgende Dateien:

1. `web/src/app/features/[feature]/[component]/[component].html` — Template
2. `web/src/app/features/[feature]/[component]/[component].scss` — Styles
3. `web/thoughts/[FEATURE]-ui-report.md` — UI-Review-Bericht

## Prompt-Vorlage
```
Aktiviere den Web-UI-Designer-Agenten (.claude/agents/web-ui-designer.md).

Research: @web/thoughts/[FEATURE]-research.md
Flutter-Screen: @mobile/lib/presentation/screens/[screen].dart
[Optional] Screenshot: [Pfad zum Screenshot]

1. Erstelle Stitch-API-Prompt für alle UI-States
2. Rufe die Stitch API auf (STITCH_API_KEY aus Env)
3. Passe das Ergebnis für Angular an (Bindings, OnPush, deutsch)
4. Prüfe Responsiveness-Checkliste
5. Prüfe Accessibility-Checkliste

Speichere: web/src/app/features/[feature]/[component]/{.html,.scss}
Report: web/thoughts/[FEATURE]-ui-report.md
```
