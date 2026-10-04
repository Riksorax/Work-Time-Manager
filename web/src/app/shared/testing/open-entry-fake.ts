import { signal } from '@angular/core';
import type { OpenEntryCandidate } from '../../features/dashboard/open-entry-close';
import type { OpenEntryEndData, OpenEntrySaveError } from '../../features/dashboard/open-entry';
import { WorkEntry } from '../models';

/**
 * Test-Fake für `OpenEntryService` (#385), steuerbar über Signale. Bewusst OHNE `vi`/Vitest-Import:
 * `tsconfig.app.json` kompiliert alle Nicht-Spec-Dateien unter `src/` ohne Test-Typen mit.
 */
export interface FakeOpenEntry {
  readonly current: ReturnType<typeof signal<OpenEntryCandidate | null>>;
  readonly moreCount: ReturnType<typeof signal<number>>;
  readonly busy: ReturnType<typeof signal<boolean>>;
  readonly saveError: ReturnType<typeof signal<OpenEntrySaveError | null>>;
  readonly closedCount: ReturnType<typeof signal<number>>;
  /** Einträge für `entryOf`/`prepareEnd` (Schlüssel = id). */
  readonly entries: ReturnType<typeof signal<Record<string, WorkEntry>>>;
  /** Ergebnis von `prepareEnd` (`undefined` = aus `entries` ableiten, `null` = nicht verfügbar). */
  prepareResult: OpenEntryEndData | null | undefined;
  readonly endCalls: { candidate: OpenEntryCandidate; end: Date }[];
  laterCalls: number;
  entryOf(id: string): WorkEntry | undefined;
  prepareEnd(c: OpenEntryCandidate): Promise<OpenEntryEndData | null>;
  endEntry(c: OpenEntryCandidate, end: Date): Promise<string>;
  later(): void;
}

export function createFakeOpenEntry(): FakeOpenEntry {
  const entries = signal<Record<string, WorkEntry>>({});
  const fake: FakeOpenEntry = {
    current: signal<OpenEntryCandidate | null>(null),
    moreCount: signal(0),
    busy: signal(false),
    saveError: signal<OpenEntrySaveError | null>(null),
    closedCount: signal(0),
    entries,
    prepareResult: undefined,
    endCalls: [],
    laterCalls: 0,
    entryOf: (id: string) => entries()[id],
    prepareEnd: async (c: OpenEntryCandidate) => {
      if (fake.prepareResult !== undefined) return fake.prepareResult;
      const entry = entries()[c.id];
      return entry ? { entry, targetMs: 0 } : null;
    },
    endEntry: async (candidate: OpenEntryCandidate, end: Date) => {
      fake.endCalls.push({ candidate, end });
      return 'closed';
    },
    later: () => { fake.laterCalls++; },
  };
  return fake;
}
