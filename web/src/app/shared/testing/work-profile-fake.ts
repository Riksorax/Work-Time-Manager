import { ReplaySubject, Observable } from 'rxjs';
import { Signal, signal } from '@angular/core';
import { DEFAULT_WORK_PROFILE_ID } from '../models';

/**
 * Test-Fake für `WorkProfileService` (#380). Bewusst OHNE `vi`/Vitest-Import: `tsconfig.app.json` kompiliert alle
 * Nicht-Spec-Dateien unter `src/` ohne Test-Typen mit.
 *
 * Signal und Observable sind getrennt steuerbar (`setSignalOnly` / `emitObservable`), um das Hinterherhinken von
 * `toObservable` gegenüber dem Signal nachzustellen. Das Observable ist ein `ReplaySubject(1)` (wie `toObservable`).
 */
export interface FakeWorkProfile {
  readonly activeProfileId: Signal<string>;
  readonly activeProfileId$: Observable<string>;
  readonly activeProfileIdForApi: string | undefined;
  setSignalOnly(id: string): void;
  emitObservable(id: string): void;
  /** Beides, Signal zuerst. */
  set(id: string): void;
  setActiveProfile(id: string): void;
}

export function createFakeWorkProfile(initial: string = DEFAULT_WORK_PROFILE_ID): FakeWorkProfile {
  const id = signal<string>(initial);
  const subject = new ReplaySubject<string>(1);
  subject.next(initial);
  const fake: FakeWorkProfile = {
    activeProfileId: id.asReadonly(),
    activeProfileId$: subject.asObservable(),
    get activeProfileIdForApi(): string | undefined {
      const v = id();
      return v === DEFAULT_WORK_PROFILE_ID ? undefined : v;
    },
    setSignalOnly: (v: string) => id.set(v),
    emitObservable: (v: string) => subject.next(v),
    set: (v: string) => { id.set(v); subject.next(v); },
    setActiveProfile: (v: string) => fake.set(v),
  };
  return fake;
}
