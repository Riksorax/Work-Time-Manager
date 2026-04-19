# Web-Plan: dashboard — Dashboard-Screen

Erstellt: 2026-04-19
Research: web/thoughts/dashboard-research.md
UI-Report: web/thoughts/dashboard-ui-report.md

---

## Ziel

Den Flutter-DashboardScreen 1:1 als Angular-Standalone-Component portieren:
laufender Timer mit Pausen, Überstundenberechnung und manuelle Zeiteingabe —
vollständig mit dem selben Firebase/localStorage Hybrid-Pattern wie die Flutter-App.

---

## Architektur-Entscheidungen

| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service? | ✅ Ja | Identisch zu Flutter: Firebase wenn eingeloggt, localStorage sonst |
| State-Management? | Angular Signals (`signal` + `computed` + `effect`) | 1:1 Äquivalent zu Riverpod Notifier |
| Timer-Mechanismus? | `interval(1000)` (RxJS) + `takeUntilDestroyed` | Browser-kompatibel, kein Drift |
| Overtime async? | `async/await` in `_init()` | Exakt wie Flutter `Future.microtask(() => _init())` |
| Premium-Gate? | ❌ Nicht benötigt im Dashboard | Kein Premium-Feature im Flutter-Dashboard |
| Routing? | Route `/dashboard` | Eingebunden in Shell-Router |
| localStorage Format? | Identisch zu Flutter's `LocalWorkRepositoryImpl` | Kompatibilität bei späterem Plattformwechsel |
| Page Visibility API? | ✅ Ja implementieren | Verhindert Timer-Drift wenn Tab im Hintergrund |

---

## Alle neuen/geänderten Dateien

### Domain Layer
```
web/src/app/domain/
├── models/
│   ├── work-entry.model.ts          # WorkEntry, WorkBreak, WorkEntryType interfaces
│   └── dashboard-state.model.ts     # DashboardState interface
├── services/
│   └── break-calculator.service.ts  # Pure TS — BreakCalculatorService (keine Angular-Deps)
└── utils/
    └── overtime.utils.ts            # Pure TS — getEffectiveDailyTarget, getWeekEntriesForDate, etc.
```

### Data Layer
```
web/src/app/data/services/
├── work-entry.service.ts            # Hybrid Firebase/localStorage — CRUD + getToday
├── overtime.service.ts              # Hybrid Firebase/localStorage — getOvertime, saveOvertime
└── settings.service.ts              # Hybrid — getTargetWeeklyHours, getWorkdaysPerWeek
```

### Core Layer
```
web/src/app/core/
├── auth/
│   ├── auth.service.ts              # Firebase Auth — user() Signal
│   └── auth.guard.ts                # Route Guard — redirect zu /login
└── firebase/
    └── firebase.config.ts           # Firebase App Init (environment.ts Werte)
```

### Feature Layer
```
web/src/app/features/dashboard/
├── dashboard.component.ts           # Standalone, OnPush — Haupt-Component
├── dashboard.component.html         # ✅ bereits erstellt (Phase 2)
├── dashboard.component.scss         # ✅ bereits erstellt (Phase 2)
├── dashboard.service.ts             # Injectable — Timer, State, Flows
└── components/
    ├── edit-break-dialog/
    │   ├── edit-break-dialog.component.ts    # MatDialog-Component
    │   ├── edit-break-dialog.component.html  # ✅ bereits erstellt (Phase 2)
    │   └── edit-break-dialog.component.scss  # ✅ bereits erstellt (Phase 2)
    └── restart-session-dialog/
        ├── restart-session-dialog.component.ts
        └── restart-session-dialog.component.html
```

### Shared Layer
```
web/src/app/shared/components/time-input/
├── time-input.component.ts          # Standalone Component
├── time-input.component.html        # ✅ bereits erstellt (Phase 2)
└── time-input.component.scss        # ✅ bereits erstellt (Phase 2)
```

### Routing
```
web/src/app/app.routes.ts            # Route /dashboard hinzufügen
```

### Tests
```
web/src/app/domain/services/break-calculator.service.spec.ts
web/src/app/domain/utils/overtime.utils.spec.ts
web/src/app/data/services/work-entry.service.spec.ts
web/src/app/data/services/overtime.service.spec.ts
web/src/app/features/dashboard/dashboard.service.spec.ts
web/src/app/features/dashboard/dashboard.component.spec.ts
web/src/app/shared/components/time-input/time-input.component.spec.ts
```

---

## Vollständige App-Flows (alle aus Flutter portieren)

### Flow 1: App-Start / Dashboard-Initialisierung
```
DashboardService._init() aufgerufen bei:
  → Component erstellt (effect() auf auth state)

1. WorkEntryService.getTodayEntry() — Firebase oder localStorage
2. OvertimeService.getOvertime() + getLastUpdateDate()
3. WorkEntryService.getEntriesForMonth(jetzt) → _weekEntries laden
   + Falls Woche in Vormonat reicht: auch Vormonat laden
4. SettingsService.getTargetWeeklyHours() + getWorkdaysPerWeek()
5. _getEffectiveDailyTarget() — Zusatztag-Check
6. Overtime-Initialisierung:
   - Falls lastUpdateDate == heute:
       initialOvertime = storedOvertime − initialDailyOvertime
   - Sonst:
       initialOvertime = storedOvertime
7. totalOvertime = initialOvertime + dailyOvertime
8. state.set({ status: 'ready', workEntry, totalOvertime, ... })
9. _startTimerIfNeeded() — falls workStart gesetzt und workEnd null
```

### Flow 2: Timer starten ("Zeiterfassung starten")
```
onTimerButtonClick() → DashboardService.startOrStopTimer()

Falls workStart == null:
  → workEntry = { ...workEntry, workStart: new Date() }
  → _recalculateAndSave(updatedEntry)
  → _startTimer()

Falls workStart != null && workEnd == null:
  → STOP (siehe Flow 3)

Falls workStart != null && workEnd != null:
  → Restart-Dialog öffnen (siehe Flow 5)
```

### Flow 3: Timer stoppen ("Zeiterfassung beenden")
```
DashboardService._stop()

1. _timer clearInterval / unsubscribe
2. workEntry = { ...workEntry, workEnd: new Date() }
3. Falls kein laufendes Break UND type === 'work':
   → BreakCalculatorService.calculateAndApplyBreaks(updatedEntry)
   → Automatische Pausen werden gesetzt
4. _recalculateAndSave(updatedEntry) mit save: true
5. OvertimeService.saveOvertime(newTotalOvertime)
6. OvertimeService.saveLastUpdateDate(new Date())
```

### Flow 4: Timer läuft — 1s Tick
```
setInterval(1000):
  1. elapsed = Date.now() − workEntry.workStart − totalBreakDuration
  2. gross = Date.now() − workEntry.workStart
  3. dailyOvertime = elapsed − targetDailyHours
  4. totalOvertime = initialOvertime + dailyOvertime
  5. expectedEndTime = _calculateExpectedEndTime(targetDailyHours)
  6. expectedEndTotalZero = _calculateExpectedEndTime(max(0, targetDailyHours − initialOvertime))
  7. state.update(...)
  8. _autoSaveCounter++ → alle 30 Ticks: WorkEntryService.save(workEntry)

Page Visibility API (Tab-Wechsel):
  document.addEventListener('visibilitychange'):
    Falls visible: elapsed direkt aus Date.now() − workStart neu berechnen
    (kein Drift durch pausierte setInterval)
```

### Flow 5: Restart-Dialog (Arbeit war bereits beendet)
```
onTimerButtonClick() → workStart && workEnd gesetzt
→ RestartSessionDialogComponent öffnen via MatDialog

Dialog-Ergebnis:
  'keep-breaks':
    workEntry = { workStart: new Date(), workEnd: null, breaks: existing }
    → _recalculateAndSave + _startTimer

  'full-reset':
    workEntry = { workStart: new Date(), workEnd: null, breaks: [] }
    → _recalculateAndSave + _startTimer

  null (Abbrechen):
    nichts tun
```

### Flow 6: Pause starten/stoppen
```
onBreakButtonClick() → DashboardService.startOrStopBreak()

Falls kein laufendes Break (breaks.every(b => b.end !== null)):
  → neues BreakEntity: { id: uuid(), name: 'Pause', start: now, end: null }
  → breaks = [...breaks, newBreak]

Falls laufendes Break:
  → letztes Break mit end: now abschließen
  → breaks = breaks.map(b => b.end ? b : { ...b, end: now })

→ _recalculateAndSave(updatedEntry)
```

### Flow 7: Manuelle Startzeit setzen
```
onStartTimeSelected(timeString: string)
  → newStart = heute + HH:MM aus timeString
  → workEntry = { ...workEntry, workStart: newStart }
  → Falls workStart && workEnd && kein laufendes Break && type === 'work':
      → BreakCalculatorService.calculateAndApplyBreaks()
  → _recalculateAndSave()
  → Falls workEnd == null: _startTimerIfNeeded()
```

### Flow 8: Manuelle Endzeit setzen / entfernen
```
onEndTimeSelected(timeString: string)
  → newEnd = heute + HH:MM aus timeString
  → workEntry = { ...workEntry, workEnd: newEnd }
  → Auto-Breaks berechnen (wie Flow 7)
  → _recalculateAndSave()

onEndTimeCleared()
  → workEntry = { ...workEntry, workEnd: null }
  → _recalculateAndSave()
  → _startTimerIfNeeded() → Timer läuft wieder
```

### Flow 9: Pause bearbeiten (EditBreakDialog)
```
onEditBreak(break: WorkBreak)
  → MatDialog.open(EditBreakDialogComponent, { data: break })

Dialog-Ergebnis (updatedBreak):
  → breaks = breaks.map(b => b.id === updated.id ? updated : b)
  → _recalculateAndSave()

Validierung im Dialog:
  → end !== null && end < start → "Endzeit kann nicht vor Startzeit liegen"
  → Start-Verschiebung: End mitverschieben (Dauer erhalten, wie Flutter)
```

### Flow 10: Pause löschen
```
onDeleteBreak(id: string)
  → breaks = breaks.filter(b => b.id !== id)
  → _recalculateAndSave()
```

### Flow 11: Auth-State-Wechsel (Login/Logout)
```
effect() auf AuthService.user():
  User vorhanden → loadFromFirebase(uid)
  User null     → loadFromLocalStorage()
  → Komplette Neuinitialisierung des Dashboard-State
  → Laufender Timer wird gestoppt und neu gestartet falls nötig
```

---

## Signal-Design: DashboardService

```typescript
// State-Interface
interface DashboardState {
  status: 'loading' | 'ready';
  workEntry: WorkEntry;
  elapsedMs: number;           // Netto-Zeit in ms (wie Flutter elapsedTime)
  grossMs: number;             // Brutto-Zeit in ms
  actualWorkMs: number | null; // Wenn gestoppt: exakte Netto-Zeit
  totalOvertime: number | null;   // ms, null = nicht geladen
  initialOvertime: number | null; // ms, Basis (Vortage)
  dailyOvertime: number | null;   // ms, heute
  expectedEndTime: Date | null;
  expectedEndTotalZero: Date | null;
  isExtraDay: boolean;
}

@Injectable({ providedIn: 'root' })
export class DashboardService {
  private readonly _state = signal<DashboardState>(initialDashboardState());

  // Public readonly signals (identisch zu Flutter DashboardState)
  readonly state = this._state.asReadonly();
  readonly isLoading      = computed(() => this._state().status === 'loading');
  readonly workEntry      = computed(() => this._state().workEntry);
  readonly isTimerRunning = computed(() => {
    const e = this._state().workEntry;
    return e.workStart !== null && e.workEnd === null;
  });
  readonly isBreakRunning = computed(() => {
    const breaks = this._state().workEntry.breaks;
    return breaks.length > 0 && breaks[breaks.length - 1].end === null;
  });
  readonly netDuration = computed(() => {
    // Wenn gestoppt: actualWorkMs; sonst: elapsedMs (Live)
    return this._state().actualWorkMs ?? this._state().elapsedMs;
  });
  readonly grossDuration      = computed(() => this._state().grossMs);
  readonly totalOvertime      = computed(() => this._state().totalOvertime);
  readonly dailyOvertime      = computed(() => this._state().dailyOvertime);
  readonly expectedEndTime    = computed(() => this._state().expectedEndTime);
  readonly expectedEndTotalZero = computed(() => this._state().expectedEndTotalZero);
  readonly breaks             = computed(() => this._state().workEntry.breaks);

  // Private services
  private readonly workEntryService = inject(WorkEntryService);
  private readonly overtimeService  = inject(OvertimeService);
  private readonly settingsService  = inject(SettingsService);
  private readonly authService      = inject(AuthService);
  private readonly destroyRef       = inject(DestroyRef);

  // Private timer state
  private _timerSub: Subscription | null = null;
  private _tickCounter = 0;
  private _weekEntries: WorkEntry[] = [];
}
```

---

## Signal-Design: DashboardComponent

```typescript
@Component({
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [
    MatProgressSpinnerModule, MatCardModule, MatButtonModule,
    MatIconModule, MatChipsModule, MatTooltipModule,
    TimeInputComponent,
  ]
})
export class DashboardComponent {
  protected readonly svc = inject(DashboardService);

  // Alle Signals direkt aus Service — keine lokalen Signals
  protected readonly isLoading      = this.svc.isLoading;
  protected readonly netDuration    = this.svc.netDuration;
  protected readonly grossDuration  = this.svc.grossDuration;
  protected readonly workEntry      = this.svc.workEntry;
  protected readonly isTimerRunning = this.svc.isTimerRunning;
  protected readonly isBreakRunning = this.svc.isBreakRunning;
  protected readonly breaks         = this.svc.breaks;
  protected readonly totalOvertime  = this.svc.totalOvertime;
  protected readonly dailyOvertime  = this.svc.dailyOvertime;
  protected readonly expectedEndTime       = this.svc.expectedEndTime;
  protected readonly expectedEndTotalZero  = this.svc.expectedEndTotalZero;

  // MatDialog für Restart + Edit-Break
  private readonly dialog = inject(MatDialog);

  // Format-Helfer (pure, identisch zu Flutter)
  protected formatDuration(ms: number): string { ... }  // HH:MM:SS
  protected formatOvertime(ms: number): { value: string; negative: boolean } { ... }  // ±HH:MM
  protected formatTime(date: Date): string { ... }  // HH:MM

  // Event-Handler → delegieren an Service
  protected onTimerButtonClick() { ... }
  protected onBreakButtonClick() { ... }
  protected onStartTimeSelected(time: string) { ... }
  protected onEndTimeSelected(time: string) { ... }
  protected onEndTimeCleared() { ... }
  protected onEditBreak(b: WorkBreak) { ... }
  protected onDeleteBreak(id: string) { ... }
}
```

---

## Hybrid-Service-Logik (WorkEntryService)

```typescript
@Injectable({ providedIn: 'root' })
export class WorkEntryService {
  private readonly auth      = inject(AuthService);
  private readonly firestore = inject(Firestore);
  private readonly destroyRef = inject(DestroyRef);

  // Firestore Pfade (identisch zur Flutter-App)
  private entryPath(uid: string, date: Date) {
    const key = formatDateKey(date); // 'YYYY-MM-DD'
    return `users/${uid}/workEntries/${key}`;
  }

  async getTodayEntry(): Promise<WorkEntry> {
    const user = this.auth.user();
    return user
      ? this._getFromFirebase(user.uid, new Date())
      : this._getFromLocalStorage(new Date());
  }

  async save(entry: WorkEntry): Promise<void> {
    const user = this.auth.user();
    return user
      ? this._saveToFirebase(user.uid, entry)
      : this._saveToLocalStorage(entry);
  }

  // localStorage Format identisch zu Flutter LocalWorkRepositoryImpl:
  // Key: 'local_work_entries_YYYY_MM'
  // Value: JSON { days: { '1': {...}, '15': {...} } }
}
```

---

## localStorage Schlüssel (identisch zu Flutter)

| Flutter Key | Web Key | Inhalt |
|---|---|---|
| `local_work_entries_YYYY_MM` | identisch | JSON Monatseinträge |
| `local_monthly_keys` | identisch | Liste aller Monatsschlüssel |
| `overtime_value` | identisch | Gespeicherte Überstunden (Minuten) |
| `overtime_last_update` | identisch | ISO-Datum letztes Overtime-Update |

---

## Implementierungsschritte (TDD-Reihenfolge)

### Schritt 1: Domain Models
- [ ] `work-entry.model.ts` — `WorkEntry`, `WorkBreak`, `WorkEntryType`
- [ ] `dashboard-state.model.ts` — `DashboardState`
- [ ] Kein Test nötig (nur Interfaces)

### Schritt 2: BreakCalculatorService (Pure TypeScript)
- [ ] **Test zuerst:** `break-calculator.service.spec.ts`
  - `< 6h → keine Pause`
  - `≥ 6h → 30 Min Mittagspause nach 4h`
  - `≥ 9h → 30 Min + 15 Min Kurzpause`
  - `Manuelle Pausen bleiben erhalten`
  - `Nur automatische Pausen werden ergänzt`
- [ ] **Impl:** `break-calculator.service.ts`

### Schritt 3: OvertimeUtils (Pure TypeScript)
- [ ] **Test zuerst:** `overtime.utils.spec.ts`
  - `getEffectiveDailyTarget: Zusatztag liefert 0`
  - `getEffectiveDailyTarget: regulärer Tag liefert regularDailyTarget`
  - `getWeekEntriesForDate: filtert korrekt`
- [ ] **Impl:** `overtime.utils.ts`

### Schritt 4: AuthService + Firebase Config
- [ ] `firebase.config.ts` — Firebase App init mit `environment.ts`
- [ ] `auth.service.ts` — `user = signal<User | null>(null)`, Google Sign-In
- [ ] `auth.guard.ts` — redirect zu `/login` wenn kein User

### Schritt 5: WorkEntryService (Hybrid)
- [ ] **Test zuerst:** `work-entry.service.spec.ts`
  - `getTodayEntry: nicht eingeloggt → localStorage`
  - `getTodayEntry: eingeloggt → Firebase`
  - `save: nicht eingeloggt → localStorage mit korrektem Key-Format`
  - `getEntriesForMonth: liefert sortierte Liste`
- [ ] **Impl:** `work-entry.service.ts`

### Schritt 6: OvertimeService (Hybrid)
- [ ] **Test zuerst:** `overtime.service.spec.ts`
  - `getOvertime: Fallback 0 wenn kein Eintrag`
  - `saveOvertime / getLastUpdateDate Round-trip`
- [ ] **Impl:** `overtime.service.ts`

### Schritt 7: SettingsService
- [ ] **Impl:** `settings.service.ts` — `getTargetWeeklyHours()`, `getWorkdaysPerWeek()`
- [ ] Defaults: 40h/Woche, 5 Tage

### Schritt 8: TimeInputComponent
- [ ] **Test:** `time-input.component.spec.ts` — Rendering, Event-Emission, Clear-Button
- [ ] **Impl:** `time-input.component.ts` (Template + SCSS ✅ Phase 2)

### Schritt 9: DashboardService
- [ ] **Test zuerst:** `dashboard.service.spec.ts`
  - Flow 1: `_init lädt Eintrag und setzt Status auf ready`
  - Flow 2: `startOrStopTimer setzt workStart`
  - Flow 3: `stop setzt workEnd, berechnet Auto-Breaks`
  - Flow 4: `Tick erhöht elapsedMs`
  - Flow 6: `startOrStopBreak erstellt/beendet Break`
  - Flow 7/8: `setManualStartTime / setManualEndTime`
  - Flow 9: `updateBreak ersetzt Break korrekt`
  - Flow 10: `deleteBreak entfernt Break`
  - Flow 11: `Auth-Wechsel triggert Neu-Init`
  - `Page Visibility: elapsed wird bei Tab-Aktivierung neu berechnet`
- [ ] **Impl:** `dashboard.service.ts` — alle Flows aus diesem Plan

### Schritt 10: RestartSessionDialogComponent
- [ ] **Impl:** `restart-session-dialog.component.ts` + `.html`
  - Gibt `'keep-breaks'`, `'full-reset'` oder `null` zurück
  - Identischer Text zu Flutter-Dialog

### Schritt 11: EditBreakDialogComponent
- [ ] **Test:** `edit-break-dialog.component.spec.ts`
  - `Validierung: end < start → Fehlermeldung`
  - `Start verschieben verschiebt End mit (Dauer erhalten)`
- [ ] **Impl:** `edit-break-dialog.component.ts` (Template + SCSS ✅ Phase 2)

### Schritt 12: DashboardComponent
- [ ] **Test:** `dashboard.component.spec.ts`
  - `Loading-State zeigt Spinner`
  - `isTimerRunning: Button-Text "beenden"`
  - `isBreakRunning: Break-Button-Text "Pause beenden"`
  - `Breaks leer: Empty-State sichtbar`
  - `onTimerButtonClick delegiert an Service`
- [ ] **Impl:** `dashboard.component.ts` (Template + SCSS ✅ Phase 2)

### Schritt 13: Routing
- [ ] `app.routes.ts` — Route `/dashboard` + `AuthGuard`
- [ ] Shell-Layout mit Navigation (BottomNav Mobile / Sidebar Desktop)

---

## Offene Risiken & Lösungen

| Risiko | Lösung |
|---|---|
| `setInterval` pausiert wenn Tab im Hintergrund (Chrome >1 Min) | `document.addEventListener('visibilitychange')` → bei `visible` elapsed aus `Date.now() - workStart` neu berechnen |
| Overtime-Berechnung: `lastUpdateDate == heute` Logik komplex | Als eigene pure Funktion `calculateInitialOvertime()` extrahieren + Unit-Test |
| Firebase-Pfade müssen identisch zu Flutter sein | Firestore-Pfad: `users/{uid}/workEntries/{YYYY-MM-DD}` — aus Flutter `work_repository_impl.dart` verifizieren |
| localStorage Keys müssen identisch zu Flutter sein | Exakt: `local_work_entries_YYYY_MM` (mit führenden Nullen für Monat) |
