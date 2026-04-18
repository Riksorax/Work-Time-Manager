# Agent 05 — Time Tracking & Dashboard ⭐ Kritischer Pfad

> **WICHTIGE VORGABE:** Die Angular Web-App muss 1:1 exakt dieselben Funktionen bieten wie die Flutter App. Das UI soll an das Web (Desktop/Browser) angepasst werden, aber alle Funktionen und Features müssen lückenlos vorhanden sein.


## Rolle
Du implementierst das Herzstück der App: das Dashboard und die Arbeitszeiterfassung. Alle Berechnungsformeln und die Datenstruktur werden **exakt** aus `AGENT-00-flutter-analysis-report.md` (aktualisierte Version) übernommen.

## Input
- `AGENT-00-flutter-analysis-report.md` (WorkEntry Struktur, Logik)
- Outputs von Agent 02, 03, 04

## Deine Aufgaben

### 5.1 Time Calculations Utility

Datei: `src/app/features/time-tracking/utils/time-calculations.util.ts`

**Logik 1:1 aus der Flutter App:**

```typescript
// Nettoarbeitszeit berechnen
export function calculateNetDuration(entry: WorkEntry): number {
  if (!entry.workStart) return 0;
  const end = entry.workEnd || new Date();
  const grossMinutes = (end.getTime() - entry.workStart.getTime()) / 60000;
  const totalBreakMinutes = entry.breaks.reduce((total, b) => {
    const bEnd = b.end || new Date();
    return total + (bEnd.getTime() - b.start.getTime()) / 60000;
  }, 0);
  return Math.max(0, grossMinutes - totalBreakMinutes);
}

// Überstunden berechnen (Minuten)
export function calculateOvertime(netMinutes: number, targetMinutes: number): number {
  return netMinutes - targetMinutes;
}

// Voraussichtlicher Feierabend (±0)
export function calculateExpectedEnd(entry: WorkEntry, targetMinutes: number): Date {
  if (!entry.workStart) return new Date();
  const totalBreakMinutes = entry.breaks.reduce((total, b) => {
    const bEnd = b.end || new Date();
    return total + (bEnd.getTime() - b.start.getTime()) / 60000;
  }, 0);
  return new Date(entry.workStart.getTime() + (targetMinutes + totalBreakMinutes) * 60000);
}
```

### 5.2 WorkEntryService

Datei: `src/app/features/time-tracking/services/work-entry.service.ts`

**Wichtig: Monatsbasierte Firestore-Struktur!**

```typescript
@Injectable({ providedIn: 'root' })
export class WorkEntryService {
  // Lädt einen Tag aus dem Monats-Dokument
  getWorkEntry(date: Date): Observable<WorkEntry | null>

  // Speichert einen Tag (merge: true in days.[dayKey])
  saveWorkEntry(entry: WorkEntry): Promise<void>

  // Timer-Logik
  startTimer(): Promise<void>
  stopTimer(): Promise<void>
  
  // Pausen-Logik
  toggleBreak(): Promise<void>
  addManualBreak(b: Break): Promise<void>
  deleteBreak(breakId: string): Promise<void>
}
```

### 5.3 OvertimeService (Neu)

Datei: `src/app/features/time-tracking/services/overtime.service.ts`

Verwaltet die `users/{uid}/overtime/balance`.
- `getBalance(): Observable<OvertimeBalance>`
- `updateBalance(minutes: number): Promise<void>`

### 5.4 DashboardComponent (Web-Optimiert)

Datei: `src/app/features/time-tracking/components/dashboard/dashboard.component.ts`

**Layout (Web: 2-spaltig):**
- **Links**: 
  - Große Netto-Zeit Anzeige (HH:MM:SS)
  - Brutto-Zeit Anzeige
  - Überstunden-Statistiken (Gesamt-Bilanz, Heutige Überstunden)
  - Voraussichtlicher Feierabend (±0 und inkl. Bilanz)
- **Rechts**:
  - Time-Picker für Startzeit und Endzeit
  - Buttons: "Zeiterfassung starten/beenden"
  - Pausen-Management (Liste der heutigen Pausen mit Edit/Delete)
  - Button: "Pause hinzufügen/beenden"

**Features:**
- Echtzeit-Update des Timers (Sekunden-Takt)
- Automatische Pausen-Berechnung (BreakCalculatorService)
- Warnung bei unrealistischen Zeiten

## Output
- `src/app/features/time-tracking/utils/time-calculations.util.ts`
- `src/app/features/time-tracking/services/work-entry.service.ts`
- `src/app/features/time-tracking/services/overtime.service.ts`
- `src/app/features/time-tracking/components/dashboard/`
- `src/app/features/time-tracking/components/break-list/`

## Übergabe
Das Dashboard ist der zentrale Einstiegspunkt der App. Es nutzt den `OvertimeService` für die Saldo-Anzeige und den `WorkEntryService` für die Datenpersistenz.
