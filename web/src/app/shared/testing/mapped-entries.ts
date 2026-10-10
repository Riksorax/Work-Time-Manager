import { HttpClient } from '@angular/common/http';
import { Injector, runInInjectionContext } from '@angular/core';
import { of } from 'rxjs';
import { ApiClient } from '../../core/services/api-client';
import { WorkEntry } from '../models';

/**
 * Backend-Form eines Arbeitseintrags (JSON der API, ISO-8601-Daten), nur für Tests (#407).
 * Ohne `vi`/`describe`: `tsconfig.app.json` kompiliert `shared/testing` mit `types: []` mit.
 */
export interface EntryDtoFixture {
  id: string;
  date: string;
  workStart?: string | null;
  workEnd?: string | null;
  type?: string;
  isManuallyEntered?: boolean;
  manualOvertimeMinutes?: number | null;
  description?: string | null;
  breaks?: { id: string; name: string; isAutomatic: boolean; start: string; end: string | null }[];
}

/** Ein Eintrags-DTO mit Standardwerten; `date` wie vom Backend: UTC-Mitternacht des Kalendertags. */
export function entryDto(
  id: string,
  date: string = `${id}T00:00:00Z`,
  extra: Partial<EntryDtoFixture> = {},
): EntryDtoFixture {
  return {
    id,
    date,
    workStart: null,
    workEnd: null,
    type: 'work',
    isManuallyEntered: false,
    manualOvertimeMinutes: null,
    description: null,
    breaks: [],
    ...extra,
  };
}

/**
 * Schickt DTOs durch den echten `ApiClient.getWorkEntriesForMonth`-Mapper (`fromDto`), ohne TestBed:
 * ein Fake-`HttpClient` liefert die Antwort. Der Helfer kennt keine Zeitzone, das Ergebnis hängt von `TZ` des Laufs ab.
 */
export async function mapWorkEntryDtos(dtos: EntryDtoFixture[]): Promise<WorkEntry[]> {
  const injector = Injector.create({
    providers: [{ provide: HttpClient, useValue: { get: () => of(dtos) } }],
  });
  const api = runInInjectionContext(injector, () => new ApiClient());
  return api.getWorkEntriesForMonth(2026, 10);
}
