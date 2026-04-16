# Agent 05 — Time Tracking Feature ⭐ Kritischer Pfad

## Rolle
Du implementierst das Herzstück der App: die Arbeitszeiterfassung. Alle Berechnungsformeln werden **exakt** aus `AGENT-00-flutter-analysis-report.md` übernommen — keine eigene Interpretation. Dies ist der kritischste Agent; Fehler hier propagieren in alle anderen Features.

## Input
- `AGENT-00-flutter-analysis-report.md` (Berechnungsformeln, WorkSession-Modell)
- Outputs von Agent 02, 03, 04

## Flutter → Angular Mapping

| Flutter | Angular |
|---|---|
| `StreamProvider` (Riverpod) | `collectionData()` Observable |
| `AsyncNotifier` | Angular Service + Signals |
| `flutter_local_notifications` Timer | `interval(1000)` + `Signal` |
| Riverpod `ref.watch()` | `toSignal()` in Components |

## Deine Aufgaben

### 5.1 Time Calculations Utility

Datei: `src/app/features/time-tracking/utils/time-calculations.util.ts`

**Alle Formeln aus Agent-00-Report, 1:1 ohne Abweichung:**

```typescript
// Nettoarbeitszeit (Kern-Algorithmus)
export function calculateNetMinutes(session: WorkSession): number {
  // end = session.endTime?.toDate() ?? new Date()  [laufende Session: jetzt]
  // gross = (end - startTime) in Minuten
  // currentPause = wenn isPaused && pauseStartTime: (jetzt - pauseStartTime) in Minuten, sonst 0
  // totalPause = session.pauseDuration + currentPause
  // return Math.max(0, gross - totalPause)   [niemals negativ]
}

export function calculateDailyTotal(sessions: WorkSession[]): number { ... }
export function calculateOvertimeMinutes(worked: number, target: number): number { ... }
export function formatDuration(totalMinutes: number): string { ... }  // "8h 30min" / "-1h 30min"
export function formatTimer(totalSeconds: number): string { ... }     // "HH:MM:SS"
export function getElapsedSeconds(session: WorkSession): number { ... }

// Datum-Hilfsfunktionen
export function startOfDay(date: Date): Date { ... }
export function endOfDay(date: Date): Date { ... }
export function startOfWeek(date: Date): Date { ... }  // Montag = Wochenstart!
export function endOfWeek(date: Date): Date { ... }
export function startOfMonth(date: Date): Date { ... }
export function endOfMonth(date: Date): Date { ... }
export function isSameDay(a: Date, b: Date): boolean { ... }

// Kategorie-Auswertung (Premium)
export function calculateCategoryBreakdown(sessions: WorkSession[]): CategoryBreakdown[] { ... }
```

### 5.2 WorkSessionService

Datei: `src/app/features/time-tracking/services/work-session.service.ts`

```typescript
@Injectable({ providedIn: 'root' })
export class WorkSessionService {

  // ── Echtzeit-Streams (Firestore) ─────────────────────────
  activeSession$: Observable<WorkSession | null>
  // query: isRunning == true, limit(1)

  getSessionsForDay(date: Date): Observable<WorkSession[]>
  // query: startTime >= startOfDay(date), startTime <= endOfDay(date), orderBy startTime desc

  getSessionsForWeek(date: Date): Observable<WorkSession[]>
  // query: startTime >= startOfWeek(date), startTime <= endOfWeek(date), orderBy startTime desc

  getSessionsInRange(start: Date, end: Date): Observable<WorkSession[]>
  // Für Reports (Agent 06)

  // ── CRUD ─────────────────────────────────────────────────
  startSession(options?: { note?: string; category?: string; profileId?: string }): Promise<string>
  // Erstellt neue Session mit isRunning: true, isPaused: false, pauseDuration: 0

  stopSession(sessionId: string): Promise<void>
  // Setzt endTime: now, isRunning: false, isPaused: false

  pauseSession(sessionId: string): Promise<void>
  // Setzt isPaused: true, pauseStartTime: now

  resumeSession(sessionId: string, pauseStartTime: Timestamp): Promise<void>
  // Berechnet vergangene Pausenzeit, addiert zu pauseDuration (Firestore increment)
  // Setzt isPaused: false, pauseStartTime: null

  updateSession(sessionId: string, updates: Partial<WorkSession>): Promise<void>
  // Für manuelle Bearbeitung (Zeit, Notiz, Kategorie)

  deleteSession(sessionId: string): Promise<void>
  // Bug #108 Fix: try/catch mit aussagekräftiger Fehlermeldung
}
```

**Alle Firestore-Operationen:** Immer `updatedAt: Timestamp.now()` setzen.

### 5.3 DashboardComponent

Datei: `src/app/features/time-tracking/components/dashboard/dashboard.component.ts`

**Layout (Desktop: 3-spaltig, Mobile: 1-spaltig):**

```
┌─────────────────────────────────────────────┐
│  LIVE-TIMER (falls Session läuft)            │
│  [Starten] [Pausieren] [Stoppen]             │
├──────────────┬──────────────┬───────────────┤
│  Heute       │  Diese Woche │  Überstunden  │
│  6h 30min    │  32h 15min   │  -7h 45min    │
├──────────────┴──────────────┴───────────────┤
│  Letzte Einträge (max. 5)                   │
│  [Liste mit Datum, Dauer, Kategorie]         │
└─────────────────────────────────────────────┘
```

Reactive Daten (alle als Signals):
```typescript
activeSession = toSignal(sessionService.activeSession$)
todaySessions = toSignal(sessionService.getSessionsForDay(new Date()))
weekSessions  = toSignal(sessionService.getSessionsForWeek(new Date()))

todayTotal    = computed(() => calculateDailyTotal(todaySessions() ?? []))
weekTotal     = computed(() => calculateDailyTotal(weekSessions() ?? []))
overtime      = computed(() => calculateOvertimeMinutes(weekTotal(), weekTargetMinutes()))
```

### 5.4 LiveTimerComponent (Shared, wird auch im Header genutzt)

Datei: `src/app/features/time-tracking/components/live-timer/live-timer.component.ts`

- Input: `session: WorkSession | null`
- Zeigt `HH:MM:SS` in Echtzeit
- Nutzt `interval(1000)` + `takeUntilDestroyed()`
- Bei `session = null`: Zeigt "00:00:00"
- Animierter Puls-Effekt wenn Session läuft
- Farbe: Grün (läuft), Orange (pausiert), Grau (inaktiv)

### 5.5 SessionListComponent

Datei: `src/app/features/time-tracking/components/session-list/session-list.component.ts`

**Features:**
- `MatTable` mit Spalten: Datum, Startzeit, Endzeit, Pause, Nettozeit, Kategorie, Notiz, Aktionen
- MatDateRangePicker für Zeitraum-Filter (Standard: aktuelle Woche)
- Sortierung per `MatSort`
- Inline-Delete mit `ConfirmDialogService` (Bug #108 Fix)
- Inline-Edit: Klick auf Zeile → `SessionDetailComponent` öffnen
- CSV-Export Button (ruft `PremiumGuard` ab → nur für Premium)
- Pagination via `MatPaginator` (25 pro Seite)
- Responsive: Auf Mobile reduzierte Spalten (Datum, Nettozeit, Aktionen)

### 5.6 SessionDetailComponent

Datei: `src/app/features/time-tracking/components/session-detail/session-detail.component.ts`

Route: `/time-tracking/:id`

Formular:
```
Startzeit       [MatDatepicker + Zeitfeld, required]
Endzeit         [MatDatepicker + Zeitfeld, optional wenn noch läuft]
Pause (Min.)    [number input, min: 0]
Kategorie       [MatSelect mit eigenen Kategorien aus bisherigen Sessions]
Notiz           [MatTextarea, max. 500 Zeichen]
[Speichern] [Verwerfen] [Löschen]
```

Validierung: `endTime > startTime` wenn endTime gesetzt.

## Tests

`time-calculations.util.spec.ts` — vollständige Test-Suite:
- `calculateNetMinutes`: ohne Pause, mit Pause, laufende Session, laufende Pause, Kantenfälle (negativ → 0)
- `calculateDailyTotal`: mehrere Sessions, leere Liste
- `calculateOvertimeMinutes`: positiv, negativ, exakt Soll
- `formatDuration`: alle Fälle inkl. negative Werte
- `startOfWeek`: Montag als Wochenstart (nicht Sonntag!)
- `calculateCategoryBreakdown`: Gruppierung, Prozentwerte

## Output
- `src/app/features/time-tracking/utils/time-calculations.util.ts`
- `src/app/features/time-tracking/utils/time-calculations.util.spec.ts`
- `src/app/features/time-tracking/services/work-session.service.ts`
- `src/app/features/time-tracking/components/dashboard/`
- `src/app/features/time-tracking/components/live-timer/`
- `src/app/features/time-tracking/components/session-list/`
- `src/app/features/time-tracking/components/session-detail/`

## Übergabe
`WorkSessionService` und `time-calculations.util.ts` werden von Agent 06 (Reports) importiert.
