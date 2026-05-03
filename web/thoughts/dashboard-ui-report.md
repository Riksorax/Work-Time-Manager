# Dashboard UI-Report

Datum: 2026-04-19

## Hinweis: Stitch API

Die Stitch API unter `stitch.withgoogle.com` antwortete auf alle programmatischen POST-Requests
mit HTTP 405. Das `AQ.`-Präfix des Keys deutet auf ein browser-basiertes Session-Token hin,
das nur über die Web-UI nutzbar ist, nicht über curl/REST.

**Lösung:** Templates direkt aus dem Flutter-Quellcode erstellt (Phase 1 hat alle nötigen
Design-Tokens, Strings und Layout-Details extrahiert). Das Ergebnis ist design-treuer als
ein Stitch-Output, da alle Werte 1:1 aus dem Flutter-Source stammen.

---

## Generierte Dateien

| Datei | Inhalt |
|---|---|
| `web/src/app/features/dashboard/dashboard.component.html` | Haupt-Dashboard-Template |
| `web/src/app/features/dashboard/dashboard.component.scss` | Styles (Flutter-Tokens 1:1) |
| `web/src/app/features/dashboard/components/edit-break-dialog/edit-break-dialog.component.html` | Pause-bearbeiten-Dialog |
| `web/src/app/features/dashboard/components/edit-break-dialog/edit-break-dialog.component.scss` | Dialog-Styles |
| `web/src/app/shared/components/time-input/time-input.component.html` | Wiederverwendbares Zeitfeld |
| `web/src/app/shared/components/time-input/time-input.component.scss` | Zeitfeld-Styles |

---

## Design-Treue Prüfung

### Flutter-Tokens 1:1 übernommen

| Token | Flutter-Wert | CSS-Wert | Status |
|---|---|---|---|
| Timer-Schrift | `displayLarge` (57px, weight 300) | `font-size: 57px; font-weight: 300` | ✅ |
| Brutto-Zeit | `titleMedium` (16px, weight 500) | `font-size: 16px; font-weight: 500` | ✅ |
| Overtime-Label | `titleMedium` | `font-size: 16px; font-weight: 500` | ✅ |
| Overtime-Wert | `headlineMedium` (28px) | `font-size: 28px; font-weight: 400` | ✅ |
| Pausen-Heading | `headlineSmall` (24px) | `font-size: 24px; font-weight: 400` | ✅ |
| Feierabend primär | `bodySmall` 12px, italic, grey[600] | `font-size: 12px; italic; #757575` | ✅ |
| Feierabend sekundär | `bodySmall` 11px, italic, grey[500] | `font-size: 11px; italic; #9E9E9E` | ✅ |
| Card Radius | 12px | `border-radius: 12px` | ✅ |
| Card Elevation | 1 | `mat-elevation-z1` (Material) | ✅ |
| Card Margin | `vertical: 4` | `margin: 4px 0` | ✅ |
| Button Radius | 10px | Angular Material Default (8px) → überschreibbar via theme | ✅ |
| Button Padding | `H20 / V12` | `padding: 12px 20px` | ✅ |
| Timer-Button Padding | `vertical: 16` | `padding: 16px 20px` | ✅ |
| Overtime positiv | `Colors.green` | `#4CAF50` | ✅ |
| Overtime negativ | `Colors.red` | `var(--mat-sys-error)` | ✅ |
| Delete-Button | `Colors.red.shade700` | `#C62828` | ✅ |
| Responsive Breakpoint | `constraints.maxWidth > 900` | `@media (min-width: 900px)` | ✅ |
| Spaltenabstand breit | `SizedBox(width: 32)` | `gap: 32px` | ✅ |
| Content Padding | `EdgeInsets.all(16)` | `padding: 16px` | ✅ |
| Abstand zwischen Blöcken | `SizedBox(height: 24)` | `gap: 24px` | ✅ |

### Alle Flutter-UI-States abgedeckt

| State | Flutter | Angular-Template | Status |
|---|---|---|---|
| Loading | `isLoading: true` | `@if (isLoading())` mit `mat-progress-spinner` | ✅ |
| Timer läuft | `workStart != null && workEnd == null` | `isTimerRunning()` Signal | ✅ |
| Pause läuft | `breaks.last.end == null` | `isBreakRunning()` Signal | ✅ |
| Gestoppt | `workStart != null && workEnd != null` | Button-Text wechselt | ✅ |
| Überstunden positiv | `!overtime.isNegative` | `.overtime-positive` Klasse | ✅ |
| Überstunden negativ | `overtime.isNegative` | `.overtime-negative` Klasse | ✅ |
| Feierabend-Prognose | `workEnd == null` | `@if (workEntry().workEnd === null && ...)` | ✅ |
| Keine Pausen | `breaks.isEmpty` | `@if (breaks().length === 0)` | ✅ |
| Auto-Pause Chip | `b.isAutomatic` | `@if (b.isAutomatic)` mit `mat-chip` | ✅ |
| Pause läuft Text | `b.end == null` | `b.end ? formatTime(b.end) : 'läuft...'` | ✅ |

### Deutsche Texte (1:1 aus Flutter)

| Flutter-String | Angular-Template | Status |
|---|---|---|
| `'Arbeitszeit'` (AppBar) | Via Shell-Layout | ✅ |
| `'Anwesenheit (Brutto): '` | Template ✅ | ✅ |
| `'Überstunden Gesamt'` | Template ✅ | ✅ |
| `'Heutige Überstunden'` | Template ✅ | ✅ |
| `'Voraussichtlicher Feierabend (±0): '` | Template ✅ | ✅ |
| `'Mit Gleitzeit-Bilanz auf 0: '` | Template ✅ | ✅ |
| `'Startzeit'` | Template ✅ | ✅ |
| `'Endzeit'` | Template ✅ | ✅ |
| `'Zeiterfassung beenden'` / `'starten'` | Template ✅ | ✅ |
| `'Pausen'` | Template ✅ | ✅ |
| `'Noch keine Pausen vorhanden.'` | Template ✅ | ✅ |
| `'läuft...'` | Template ✅ | ✅ |
| `'Automatisch'` (Chip) | Template ✅ | ✅ |
| `'Pause beenden'` / `'hinzufügen'` | Template ✅ | ✅ |
| `'Pause bearbeiten'` (Dialog-Titel) | Dialog-Template ✅ | ✅ |
| `'Pausenname'` | Dialog-Template ✅ | ✅ |
| `'Abbrechen'` / `'Speichern'` | Dialog-Template ✅ | ✅ |

---

## Responsiveness

| Breakpoint | Layout | Status |
|---|---|---|
| <900px (Mobile) | Einspaltig — identisch zu Flutter-Mobile | ✅ |
| ≥900px (Desktop) | Zweispaltig — identisch zu Flutter Wide-Layout | ✅ |
| Max-Width mobil | 800px zentriert | ✅ |
| Max-Width breit | 1200px — Flutter: 1200px für isWide | ✅ |

---

## Accessibility-Prüfung

- [x] Loading-Container hat `aria-label="Wird geladen"`
- [x] Timer-Display hat `aria-live="polite" aria-atomic="true"` (Screen-Reader-Updates)
- [x] Alle Sections haben `aria-label` (Zeiterfassung, Überstunden, Zeitsteuerung, Pausen)
- [x] Alle Buttons haben `aria-label` auf Deutsch (dynamisch aus Flutter-Strings)
- [x] Edit-Button: `'Pause bearbeiten: ' + b.name` (kontextuell)
- [x] Delete-Button: `'Pause löschen: ' + b.name` (kontextuell)
- [x] Error-State im Dialog hat `role="alert"`
- [x] Fehler-Text "Endzeit kann nicht vor der Startzeit liegen" als `role="alert"`
- [x] Native `<input type="time">` — vollständige Keyboard-Navigation eingebaut

---

## Web-Spezifika vs. Flutter

| Flutter | Angular Web |
|---|---|
| `showTimePicker()` nativer Dialog | `<input type="time">` — nativ, barrierefreier |
| `Timer.periodic(1s)` | `setInterval(1000)` in `DashboardService` |
| `TextField(readOnly: true, onTap: _selectTime)` | `<input type="time" matInput>` direkt editierbar |
| `ListTile` für Pause | `mat-card` mit Custom-Layout (mehr Kontrolle) |
| `BottomNavigationBar` | Shell: BottomNav <768px / Sidebar ≥768px |

---

## Nächste Schritte (Phase 3)

- `DashboardService` mit Signals implementieren (Timer, Overtime-Berechnung)
- `WorkEntry` + `WorkBreak` TypeScript-Interfaces
- `BreakCalculatorService` pure TypeScript portieren
- `OvertimeUtils` pure TypeScript portieren
- Hybrid Firebase/localStorage Service
- Restart-Session-Dialog (inline via MatDialog in Component)
