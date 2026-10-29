import { TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { provideTranslateService } from '@ngx-translate/core';
import { HomeOfficeCardComponent } from './home-office-card';
import { WorkEntryService } from '../../../core/services/work-entry';
import { WorkProfileService } from '../../../core/services/work-profile';
import { WorkEntry, WorkEntryType } from '../../models/index';

function entry(day: string, isHomeOffice: boolean): WorkEntry {
  const [y, m, d] = day.split('-').map(Number);
  return {
    id: day, date: new Date(y, m - 1, d), workStart: new Date(y, m - 1, d, 8), workEnd: new Date(y, m - 1, d, 16),
    breaks: [], isManuallyEntered: false, type: WorkEntryType.Work, isHomeOffice,
  };
}

describe('HomeOfficeCardComponent (#283)', () => {
  function setup(getMonth: (year: number, month: number) => Promise<WorkEntry[]>) {
    const getEntriesForMonthOnce = vi.fn(getMonth);
    TestBed.configureTestingModule({
      providers: [
        provideTranslateService(),
        { provide: WorkEntryService, useValue: { getEntriesForMonthOnce } },
        { provide: WorkProfileService, useValue: { activeProfileId: signal('default') } },
      ],
    });
    const fixture = TestBed.createComponent(HomeOfficeCardComponent);
    fixture.componentRef.setInput('year', 2026);
    fixture.detectChanges();
    return { fixture, getEntriesForMonthOnce };
  }

  const settle = async (fixture: { whenStable: () => Promise<unknown>; detectChanges: () => void }) => {
    await fixture.whenStable();
    fixture.detectChanges();
  };

  it('lädt alle zwölf Monate des Jahres und zählt', async () => {
    const { fixture, getEntriesForMonthOnce } = setup(async (_y, m) =>
      m === 3 ? [entry('2026-03-02', true), entry('2026-03-03', false)] : []);
    await settle(fixture);

    expect(getEntriesForMonthOnce).toHaveBeenCalledTimes(12);
    expect(getEntriesForMonthOnce.mock.calls.map(c => c[1])).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
    expect(getEntriesForMonthOnce.mock.calls.every(c => c[0] === 2026)).toBe(true);
    const text = (fixture.nativeElement as HTMLElement).textContent ?? '';
    expect(text).toContain('1');
    expect((fixture.nativeElement as HTMLElement).querySelector('.ho-value')?.textContent?.trim()).toBe('1');
  });

  it('ein Lesefehler zeigt den Fehlerzustand mit Wiederholen-Button', async () => {
    const { fixture } = setup(async () => { throw new Error('offline'); });
    await settle(fixture);
    const el = fixture.nativeElement as HTMLElement;
    expect(el.querySelector('.ho-error')).not.toBeNull();
    expect(el.querySelector('button')).not.toBeNull();
  });

  it('ohne Arbeitstage: Leerhinweis statt Zahlen', async () => {
    const { fixture } = setup(async () => []);
    await settle(fixture);
    const el = fixture.nativeElement as HTMLElement;
    expect(el.querySelector('.ho-empty')).not.toBeNull();
    expect(el.querySelector('.ho-value')).toBeNull();
  });
});
