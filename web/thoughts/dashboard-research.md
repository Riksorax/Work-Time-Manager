# Web-Research: dashboard — Dashboard-Screen

Datum: 2026-04-19

## Flutter-Quelle

| Datei | Zweck |
|---|---|
| `mobile/lib/presentation/screens/dashboard_screen.dart` | Haupt-UI |
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | Business-Logic + State |
| `mobile/lib/presentation/state/dashboard_state.dart` | State-Klasse |
| `mobile/lib/domain/entities/work_entry_entity.dart` | Hauptentität |
| `mobile/lib/domain/entities/break_entity.dart` | Pausen-Entität |
| `mobile/lib/domain/services/break_calculator_service.dart` | Pflichtpausen-Logik |
| `mobile/lib/domain/utils/overtime_utils.dart` | Überstunden-Berechnungen |
| `mobile/lib/presentation/widgets/edit_break_modal.dart` | Pause-bearbeiten-Dialog |
| `mobile/lib/presentation/screens/home_screen.dart` | Shell / Navigation |
| `mobile/lib/core/theme/app_theme.dart` | Theme-Definitionen |

---

## Feature-Verständnis

Der Dashboard-Screen ist der Kern der App. Er zeigt die aktuelle Zeiterfassung des Tages:
- Netto-Arbeitszeit als laufende Stoppuhr (HH:MM:SS, 1s-Tick)
- Brutto-Anwesenheitszeit (inkl. Pausen)
- Überstunden gesamt + heutige Überstunden (mit +/- Vorzeichen und Farbe)
- Voraussichtlichen Feierabend (für ±0 heute und für ±0 Gesamtbilanz)
- Start-/Endzeit-Felder (manuell setzbar via TimePicker)
- Start/Stop-Button (mit Restart-Dialog wenn bereits gestoppt)
- Pausenliste mit Bearbeiten + Löschen pro Pause
- "Pause hinzufügen / Pause beenden"-Button

Automatische Pausen (nach deutschem ArbZG) werden beim Stoppen des Timers berechnet und
angezeigt (Chip "Automatisch"). Auto-Pausen können überschrieben, aber nicht gelöscht werden
wenn sie gesetzlich nötig sind.

Responsive Breakpoint bei 900px: unter 900px → einspaltig, über 900px → zweispaltig
(links: Timer + Overtime, rechts: Zeitfelder + Pausen).

---

## Domain-Mapping

| Flutter Entity / Service | Angular Äquivalent | Datei |
|---|---|---|
| `WorkEntryEntity` | `WorkEntry` (interface) | `domain/models/work-entry.model.ts` |
| `BreakEntity` | `WorkBreak` (interface) | `domain/models/work-entry.model.ts` |
| `WorkEntryType` | `WorkEntryType` (union type) | `domain/models/work-entry.model.ts` |
| `DashboardState` | `DashboardState` (interface) | `domain/models/dashboard-state.model.ts` |
| `BreakCalculatorService` | `BreakCalculatorService` (static class) | `domain/services/break-calculator.service.ts` |
| `BreakComplianceResult` | `BreakComplianceResult` (interface) | `domain/services/break-calculator.service.ts` |
| `getEffectiveDailyTarget()` | `getEffectiveDailyTarget()` (pure fn) | `domain/utils/overtime.utils.ts` |
| `getEffectiveWorkDays()` | `getEffectiveWorkDays()` (pure fn) | `domain/utils/overtime.utils.ts` |
| `getWeekEntriesForDate()` | `getWeekEntriesForDate()` (pure fn) | `domain/utils/overtime.utils.ts` |
| `DashboardViewModel` (Riverpod Notifier) | `DashboardService` (Angular injectable, signals) | `features/dashboard/dashboard.service.ts` |
| `Timer.periodic(1s)` | `setInterval(1000)` + `takeUntilDestroyed` | im `DashboardService` |
| Auto-Save (30 Ticks) | `setInterval(30000)` | im `DashboardService` |
| `WorkRepository` (Hybrid) | `WorkEntryService` (Hybrid Firebase/localStorage) | `data/services/work-entry.service.ts` |
| `OvertimeRepository` (Hybrid) | `OvertimeService` (Hybrid Firebase/localStorage) | `data/services/overtime.service.ts` |
| `SettingsRepository` | `SettingsService` | `data/services/settings.service.ts` |
| `getTodayWorkEntryUseCase` | Methode in `WorkEntryService` | `data/services/work-entry.service.ts` |
| `toggleBreakUseCase` | Methode in `DashboardService` | `features/dashboard/dashboard.service.ts` |
| `saveWorkEntryUseCase` | Methode in `WorkEntryService` | `data/services/work-entry.service.ts` |
| `HomeScreen` (BottomNav) | `ShellComponent` (Sidenav Desktop / BottomNav Mobile) | `layout/shell/shell.component.ts` |
| `EditBreakModal` (AlertDialog) | `EditBreakDialogComponent` (Angular Material Dialog) | `features/dashboard/components/edit-break-dialog/` |
| `_TimeInputField` | `TimeInputComponent` (mat-form-field + native time input) | `shared/components/time-input/` |
| `_showRestartDialog` | `RestartSessionDialogComponent` | inline im `DashboardComponent` via MatDialog |

---

## UI-States

| State | Beschreibung | Flutter-Trigger | Angular-Signal |
|---|---|---|---|
| **loading** | Initiales Laden (Firestore-Fetch) | `isLoading: true` | `isLoading = computed(() => state().status === 'loading')` |
| **idle** | Kein Timer gestartet, leerer Tag | `workStart == null` | `isIdle = computed(() => !entry().workStart)` |
| **running** | Timer läuft, Stoppuhr tickt | `workStart != null && workEnd == null` | `isRunning = computed(...)` |
| **break-running** | Pause läuft | `breaks.last.end == null` | `isBreakRunning = computed(...)` |
| **stopped** | Arbeit beendet, Endzeit gesetzt | `workStart != null && workEnd != null` | `isStopped = computed(...)` |
| **extra-day** | Zusatztag (kein Soll) | `isExtraDay: true` | Im State-Signal |

**Sub-States im stopped-State:**
- Überstunden positiv (grün) oder negativ (rot) → CSS-Klasse
- Feierabend-Prognose nur wenn Timer läuft (`workEnd == null`)

---

## Theme-Tokens (aus Flutter nach CSS/SCSS)

| Flutter | CSS / Angular Material |
|---|---|
| `Colors.blue` (seedColor) | `--mat-sys-primary: #1976D2` (M3 seed) |
| `CardTheme borderRadius: 12` | `border-radius: 12px` |
| `ElevatedButton borderRadius: 10` | `border-radius: 10px` |
| `ElevatedButton padding: H20/V12` | `padding: 12px 20px` |
| `AppBar: transparent, centerTitle` | `mat-toolbar` transparent, `text-align: center` |
| `Card elevation: 1` | `mat-elevation-z1` |
| `textTheme.displayLarge` | `mat-display-large` (M3) → ~57px |
| `textTheme.headlineMedium` | `mat-headline-medium` → ~28px |
| `textTheme.headlineSmall` | `mat-headline-small` → ~24px |
| `textTheme.titleMedium` | `mat-title-medium` → ~16px |
| `textTheme.bodySmall` | `mat-body-small` → ~12px |
| Overtime positiv | `color: var(--mat-sys-tertiary)` oder `#4CAF50` |
| Overtime negativ | `color: var(--mat-sys-error)` oder `#F44336` |
| Chip "Automatisch" | `mat-chip` sekundär-farbig |
| Light/Dark | Angular Material M3 theme mit `Colors.blue` als seedColor |
| Responsive Breakpoint 900px | `@media (min-width: 900px)` |

---

## Layout-Struktur

### Mobile / Schmal (<900px) — einspaltig
```
┌─────────────────────────┐
│  AppBar: "Arbeitszeit"  │
├─────────────────────────┤
│  Timer-Display          │  displayLarge: HH:MM:SS
│  Brutto-Zeit            │  titleMedium: "Anwesenheit (Brutto): HH:MM:SS"
├─────────────────────────┤
│  Überstunden Gesamt     │  headlineMedium ±HH:MM (grün/rot)
│  Heutige Überstunden    │  headlineMedium ±HH:MM (grün/rot)
│  Feierabend ±0 (heute)  │  bodySmall italic grau
│  Feierabend Bilanz ±0   │  bodySmall italic heller grau (kleiner)
├─────────────────────────┤
│  [Startzeit    ] [🕐]   │  OutlineInputBorder
│  [Endzeit      ] [✕]   │  OutlineInputBorder (nur wenn workEnd gesetzt)
│  [Zeiterfassung starten]│  ElevatedButton full-width
├─────────────────────────┤
│  Pausen                 │  headlineSmall
│  Card: Name + Chip      │  ListTile mit ✏️ 🗑️
│  [Pause hinzufügen]     │  ElevatedButton full-width
└─────────────────────────┘
```

### Desktop / Breit (≥900px) — zweispaltig
```
┌────────────────┬────────────────┐
│  Timer-Display │  Startzeit     │
│  Brutto-Zeit   │  Endzeit       │
│                │  [Start/Stop]  │
│  Überstunden   │                │
│  Gesamt        │  Pausen        │
│  Heute         │  Pause-Cards   │
│  Feierabend    │  [Pause add]   │
└────────────────┴────────────────┘
```

---

## Dialoge

### Restart-Dialog (wenn Timer bereits gestoppt und erneut Start gedrückt)
- Titel: "Neue Session starten"
- Text: Erklärung der zwei Optionen
- Buttons: "Abbrechen", "Pausen behalten", "Komplett neu" (FilledButton)

### Edit-Break-Dialog
- Felder: "Pausenname", "Startzeit" (TimePicker), "Endzeit" (TimePicker)
- Validierung: Endzeit nicht vor Startzeit
- Beim Verschieben der Startzeit: Endzeit mitverschieben (Dauer erhalten)
- Buttons: "Abbrechen", "Speichern"

---

## Kritische Business-Logic (identisch portieren)

### Timer-Logik
- 1-Sekunden-Tick → `setInterval(1000)`
- Netto-Zeit = Brutto − Pausen (inkl. laufender Pause bis `now`)
- Auto-Save alle 30 Sekunden

### Überstunden-Berechnung
- `initialOvertime` = Basis (Vortage) aus `OvertimeService`
- `dailyOvertime` = Netto-Arbeitszeit − Tages-Soll
- `totalOvertime` = `initialOvertime` + `dailyOvertime`
- Wenn `lastUpdateDate == heute`: `initialOvertime = storedOvertime − dailyOvertimeAtSaveTime`

### Feierabend-Prognose
- Iterative Berechnung (max 2 Iterationen) um Sprung über 6h/9h-Grenze zu berücksichtigen
- `expectedEndTime` = Start + TargetHours + PausenZeit (mit automatischen Pausen)
- `expectedEndTotalZero` = Start + max(0, TargetHours − initialOvertime) + Pausen

### Automatische Pausen (ArbZG)
- < 6h Netto: keine Pflichtpause
- ≥ 6h Netto: 30 Min (Mittagspause nach 4h, wenn vor Arbeitsende)
- ≥ 9h Netto: 45 Min gesamt (30 Min + 15 Min Kurzpause)
- Beim Stoppen wenn kein laufendes Break und Typ == `work`
- Beim manuellen Setzen von Start- oder Endzeit (wenn beide gesetzt)

### Zusatztag-Logik
- Wochentage (Mo-Fr) > `workdaysPerWeek` → `isExtraDay = true` → Soll = 0 → alles = Überstunden
- Wocheneinträge werden aus Repository geladen (auch vorheriger Monat wenn Woche überlappt)

---

## Web-Spezifika

### Kein RevenueCat
- Kein Premium-Gate im Dashboard identifiziert → kein Handlungsbedarf

### Navigation
- Flutter: `BottomNavigationBar` mit 3 Items (Dashboard / Berichte / Einstellungen)
- Angular Web:
  - Mobile (<768px): `BottomNavigationBar` beibehalten (identisch zu Flutter)
  - Desktop (≥768px): Sidebar / Top-Nav mit denselben Items und Icons

### TimePicker
- Flutter: `showTimePicker()` (native Material Dialog)
- Web: `<input type="time">` in `mat-form-field` oder `@angular/material` TimePicker
  → Empfehlung: `<input type="time" matInput>` — nativ, barrierefreifreundlich

### Timer-Tick
- Flutter: `Timer.periodic(Duration(seconds: 1), ...)`
- Angular: `interval(1000)` (RxJS) + `takeUntilDestroyed()`

### Auto-Save
- Flutter: alle 30 Ticks im Timer
- Angular: separates `setInterval(30_000)` oder `timer(30_000, 30_000)` RxJS

---

## Offene Fragen

1. **Offline-Support**: Die Flutter-App speichert lokal via SharedPreferences wenn nicht eingeloggt. Soll das Web dasselbe via `localStorage` machen? → Annahme: Ja, identisches Hybrid-Pattern.
2. **Version-Check-Dialog** (`UpdateRequiredDialog`): Soll das im Web ebenfalls implementiert werden? → Wahrscheinlich nicht relevant (Web deployed immer aktuell).
3. **Datum des Eintrags**: Dashboard zeigt immer "heute". Soll der Nutzer im Web auch historische Tage bearbeiten können (wie in Reports)? → Nein, Dashboard ist immer "heute".

---

## Risiken

| Risiko | Lösungsvorschlag |
|---|---|
| Timer-Genauigkeit im Browser-Tab (Throttling wenn Tab im Hintergrund) | `Page Visibility API` — Timer pausieren und bei Reaktivierung nachberechnen |
| `setInterval` Drift über lange Laufzeiten | Zeit immer aus `Date.now()` berechnen, nicht akkumulieren |
| Feierabend-Prognose-Logik ist komplex (iterativ) | Pure TypeScript-Funktion identisch portieren, Unit-Tests mit gleichen Inputs wie Flutter |
| Überstunden-Initialisierung (`lastUpdateDate == heute`-Logik) | Exakt gleiche Logik in `DashboardService._init()` portieren |
