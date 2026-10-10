import { Signal, WritableSignal } from '@angular/core';
import { Observable, defer, from, map, of, switchMap } from 'rxjs';
import { WorkEntryService } from '../../core/services/work-entry';
import { OvertimeService } from '../../core/services/overtime';
import { SettingsService } from '../../core/services/settings';
import { AuthService } from '../../core/auth/auth';
import { toDateKey } from '../utils/german-holidays.util';
import { DEFAULT_SETTINGS, UserSettings, WorkEntry, WorkEntryType } from '../models';

/**
 * Test-Welt für das Dashboard (#426): zwei Arbeitszeit-Profile (`WORLD_A` = Standard, `WORLD_B`), alle Zugriffe der
 * Hybrid-Services werden protokolliert und können je Art (Write und Read) angehalten (Hold), freigegeben (Release)
 * oder zum Scheitern gebracht werden (Fail). Bewusst OHNE `vi`/Vitest-Globals: `tsconfig.app.json` kompiliert alle
 * Nicht-Spec-Dateien unter `src/` mit `types: []` mit. Datums-/Zeitzonen-unabhängig: Log-Zeiten sind lokale `HH:mm`.
 */
export const WORLD_A = 'default';
export const WORLD_B = 'B';

/** Zugriffsarten, die gehalten/freigegeben/zum Scheitern gebracht werden können. */
export type WorldKind =
  | 'saveEntry' | 'saveOvertime' | 'saveLastUpdate'
  | 'getTodayEntry' | 'getOvertime' | 'getLastUpdate' | 'getMonth';

export interface WorldProfData {
  entries: Map<string, WorkEntry>;
  overtimeMs: number;
  lastUpdate: Date | null;
  settings: UserSettings;
}

export interface WorldWriteRec {
  kind: 'entry' | 'overtime' | 'lastUpdate';
  /** Profil, in dem der Write landet (Roh-Argument oder aktives Profil). */
  pid: string;
  /** Roh-Argument: `undefined` = der Aufrufer hat KEIN Profil festgehalten. */
  rawPid: string | undefined;
  entry?: WorkEntry;
  ms?: number;
}

export interface WorldReadRec { kind: 'entry' | 'overtime' | 'lastUpdate' | 'month'; pid: string }

interface Pending {
  kind: WorldKind;
  settle: () => void;
  reject: (e: unknown) => void;
}

export interface ProfileSource {
  activeProfileId: Signal<string>;
  activeProfileId$: Observable<string>;
}

const hhmm = (d: Date | undefined): string =>
  d ? `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}` : '';

export function worldEntry(date: Date, extra: Partial<WorkEntry> = {}): WorkEntry {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  return { id: toDateKey(d), date: d, breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, ...extra };
}

export class DashboardWorld {
  readonly data: Record<string, WorldProfData>;
  readonly writes: WorldWriteRec[] = [];
  readonly reads: WorldReadRec[] = [];
  /**
   * Gemeinsames Protokoll in Aufrufreihenfolge: `entry:<pid>:<start>-<end>` (lokale HH:mm), `overtime:<pid>:<ms>`,
   * `lastUpdate:<pid>`, `switch:<id>` (vom Test selbst über `logSwitch` ergänzt).
   */
  readonly log: string[] = [];
  /** Aufrufzähler je Art (1-basiert zum Zeitpunkt des Aufrufs). */
  readonly calls: Record<WorldKind, number> = {
    saveEntry: 0, saveOvertime: 0, saveLastUpdate: 0, getTodayEntry: 0, getOvertime: 0, getLastUpdate: 0, getMonth: 0,
  };
  /** 1-basierte Aufrufnummern von `saveEntry`, die scheitern sollen (z. B. `{2}` = nur der zweite Eintrag-Write). */
  failSaveEntryCalls = new Set<number>();

  private readonly held = new Set<WorldKind>();
  private readonly failures = new Map<WorldKind, unknown>();
  private pendingList: Pending[] = [];

  constructor(over: {
    a?: Partial<WorldProfData>; b?: Partial<WorldProfData>;
    aEntry?: WorkEntry | null; bEntry?: WorkEntry | null;
  } = {}) {
    const mk = (e: WorkEntry | null | undefined, base: Omit<WorldProfData, 'entries'>, extra?: Partial<WorldProfData>): WorldProfData => ({
      entries: new Map(e ? [[toDateKey(e.date), e]] : []), ...base, ...extra,
    });
    this.data = {
      [WORLD_A]: mk(over.aEntry, { overtimeMs: 120 * 60000, lastUpdate: null, settings: { ...DEFAULT_SETTINGS } }, over.a),
      [WORLD_B]: mk(over.bEntry, {
        overtimeMs: 30 * 60000, lastUpdate: null,
        settings: { ...DEFAULT_SETTINGS, weeklyTargetHours: 18, workdays: [1, 2, 3] },
      }, over.b),
    };
  }

  // ─── Steuerung ────────────────────────────────────────────────────────────────────────────────────────
  /** Neue Aufrufe dieser Art parken, bis `release`/`releaseAll` sie freigibt. */
  hold(kind: WorldKind, on = true): void {
    if (on) this.held.add(kind); else this.held.delete(kind);
  }

  /** Alle künftigen Aufrufe dieser Art scheitern sofort mit `err` (`null` hebt auf). Gehaltene Aufrufe: `rejectPending`. */
  fail(kind: WorldKind, err: unknown | null): void {
    if (err === null) this.failures.delete(kind); else this.failures.set(kind, err);
  }

  /** Anzahl geparkter Aufrufe (optional je Art). */
  pending(kind?: WorldKind): number {
    return this.pendingList.filter(p => !kind || p.kind === kind).length;
  }

  /** Gibt den `i`-ten geparkten Aufruf der Art frei (Erfolg). Bleibt die Haltemarke gesetzt, parken Folgeaufrufe weiter. */
  release(kind: WorldKind, i = 0): void {
    const p = this.pendingList.filter(x => x.kind === kind)[i];
    if (!p) throw new Error(`kein geparkter ${kind}-Aufruf Nr. ${i}`);
    this.pendingList = this.pendingList.filter(x => x !== p);
    p.settle();
  }

  /** Lässt den `i`-ten geparkten Aufruf der Art scheitern. */
  rejectPending(kind: WorldKind, err: unknown, i = 0): void {
    const p = this.pendingList.filter(x => x.kind === kind)[i];
    if (!p) throw new Error(`kein geparkter ${kind}-Aufruf Nr. ${i}`);
    this.pendingList = this.pendingList.filter(x => x !== p);
    p.reject(err);
  }

  /** Hebt alle Haltemarken auf und gibt alle geparkten Aufrufe frei (Testende). */
  releaseAll(): void {
    this.held.clear();
    const all = this.pendingList;
    this.pendingList = [];
    for (const p of all) p.settle();
  }

  logSwitch(id: string): void { this.log.push(`switch:${id}`); }

  // ─── Auswertung ───────────────────────────────────────────────────────────────────────────────────────
  entryWrites(pid?: string): WorldWriteRec[] {
    return this.writes.filter(w => w.kind === 'entry' && (pid === undefined || w.pid === pid));
  }
  overtimeWrites(pid?: string): WorldWriteRec[] {
    return this.writes.filter(w => w.kind === 'overtime' && (pid === undefined || w.pid === pid));
  }
  lastUpdateWrites(): WorldWriteRec[] { return this.writes.filter(w => w.kind === 'lastUpdate'); }
  /** Gespeicherter Eintrag des Tages `date` im Profil `pid`. */
  stored(pid: string, date: Date): WorkEntry | undefined { return this.data[pid].entries.get(toDateKey(date)); }

  // ─── Für die Fakes ────────────────────────────────────────────────────────────────────────────────────
  /** Führt einen Zugriff aus: zählt, scheitert bei Bedarf, parkt bei Hold, sonst sofort. `land` wird beim Erfolg ausgeführt. */
  async gate<T>(kind: WorldKind, land: () => T, forceFailure?: unknown): Promise<T> {
    const failure = forceFailure ?? this.failures.get(kind);
    if (failure !== undefined) throw failure;
    if (this.held.has(kind)) {
      await new Promise<void>((resolve, reject) => {
        this.pendingList.push({ kind, settle: resolve, reject });
      });
    }
    return land();
  }

  /** Beobachtbare Variante für `getTodayEntry` (Parken/Scheitern wie bei `gate`). */
  gateObservable<T>(kind: WorldKind, land: () => T): Observable<T> {
    return defer(() => {
      const failure = this.failures.get(kind);
      if (failure !== undefined) throw failure;
      if (!this.held.has(kind)) return of(land());
      return from(this.gate(kind, land));
    });
  }

  fileEntry(pid: string, entry: WorkEntry): void { this.data[pid].entries.set(toDateKey(entry.date), entry); }

  entryLogLine(pid: string, e: WorkEntry): string { return `entry:${pid}:${hhmm(e.workStart)}-${hhmm(e.workEnd)}`; }
}

/** Provider-Fabrik für `WorkEntryService`, `OvertimeService`, `SettingsService` und `AuthService` auf Basis der Welt. */
export function dashboardWorldProviders(
  world: DashboardWorld,
  profile: () => ProfileSource,
  user: WritableSignal<{ uid: string } | null>,
) {
  return [
    { provide: WorkEntryService, useFactory: () => {
      const p = profile();
      const read = (id: string): Observable<WorkEntry | null> => {
        world.calls.getTodayEntry++;
        world.reads.push({ kind: 'entry', pid: id });
        return world.gateObservable('getTodayEntry', () => world.data[id].entries.get(toDateKey(new Date())) ?? null);
      };
      return {
        getTodayEntry: (pid?: string) => (pid !== undefined ? read(pid) : p.activeProfileId$.pipe(switchMap(read))),
        emptyEntry: (d: Date) => worldEntry(d),
        getEntriesForMonthOnce: async (year: number, month: number, pid?: string) => {
          const id = pid ?? p.activeProfileId();
          world.calls.getMonth++;
          world.reads.push({ kind: 'month', pid: id });
          return world.gate('getMonth', () =>
            [...world.data[id].entries.values()].filter(e => e.date.getFullYear() === year && e.date.getMonth() + 1 === month));
        },
        saveEntry: async (entry: WorkEntry, pid?: string) => {
          const resolved = pid ?? p.activeProfileId();
          const n = ++world.calls.saveEntry;
          world.writes.push({ kind: 'entry', pid: resolved, rawPid: pid, entry });
          world.log.push(world.entryLogLine(resolved, entry));
          await world.gate('saveEntry', () => world.fileEntry(resolved, entry),
            world.failSaveEntryCalls.has(n) ? new Error(`saveEntry #${n} fehlgeschlagen`) : undefined);
        },
      };
    } },
    { provide: OvertimeService, useFactory: () => {
      const p = profile();
      const readId = (kind: 'overtime' | 'lastUpdate', pid: string | undefined): string => {
        const id = pid ?? p.activeProfileId();
        world.reads.push({ kind, pid: id });
        return id;
      };
      return {
        getOvertime: async (pid?: string) => {
          world.calls.getOvertime++;
          const id = readId('overtime', pid);
          return world.gate('getOvertime', () => world.data[id].overtimeMs);
        },
        getLastUpdateDate: async (pid?: string) => {
          world.calls.getLastUpdate++;
          const id = readId('lastUpdate', pid);
          return world.gate('getLastUpdate', () => world.data[id].lastUpdate);
        },
        saveOvertime: async (ms: number, pid?: string) => {
          const resolved = pid ?? p.activeProfileId();
          world.calls.saveOvertime++;
          world.writes.push({ kind: 'overtime', pid: resolved, rawPid: pid, ms });
          world.log.push(`overtime:${resolved}:${ms}`);
          await world.gate('saveOvertime', () => { world.data[resolved].overtimeMs = ms; });
        },
        saveLastUpdateDate: async (date: Date) => {
          const resolved = p.activeProfileId();
          world.calls.saveLastUpdate++;
          world.writes.push({ kind: 'lastUpdate', pid: resolved, rawPid: undefined });
          world.log.push(`lastUpdate:${resolved}`);
          await world.gate('saveLastUpdate', () => { world.data[resolved].lastUpdate = date; });
        },
      };
    } },
    { provide: SettingsService, useFactory: () => {
      const p = profile();
      // Wie der echte SettingsService: folgt dem Observable (hinkt dem Signal hinterher).
      return {
        getSettings: () => p.activeProfileId$.pipe(map(id => world.data[id].settings)),
        saveSettings: () => undefined,
      };
    } },
    { provide: AuthService, useValue: { user, get uid() { return user()?.uid ?? null; } } },
  ];
}
