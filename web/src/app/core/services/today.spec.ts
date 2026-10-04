import { TestBed } from '@angular/core/testing';
import { effect } from '@angular/core';
import { TodayService } from './today';
import { toDateKey } from '../../shared/utils/german-holidays.util';

function create(): TodayService {
  TestBed.resetTestingModule();
  return TestBed.inject(TodayService);
}

function setVisibility(state: 'visible' | 'hidden'): void {
  Object.defineProperty(document, 'visibilityState', { value: state, configurable: true });
}

describe('TodayService (#372)', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 3, 12, 0));
  });
  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
    vi.restoreAllMocks();
    setVisibility('visible');
  });

  it('startet mit dem lokalen Tages-Key', () => {
    expect(create().today()).toBe('2026-10-03');
  });

  it('wechselt zur lokalen Mitternacht und plant den Folgetag neu', () => {
    vi.setSystemTime(new Date(2026, 9, 3, 23, 59, 30));
    const svc = create();
    vi.advanceTimersByTime(29_999);
    expect(svc.today()).toBe('2026-10-03');
    vi.advanceTimersByTime(1);
    expect(svc.today()).toBe('2026-10-04');
    vi.advanceTimersByTime(new Date(2026, 9, 5).getTime() - Date.now());
    expect(svc.today()).toBe('2026-10-05');
  });

  it('wechselt 1 ms nach 23:59:59.999 (Mindestverzögerung 1 s, kein Spin)', () => {
    vi.setSystemTime(new Date(2026, 9, 3, 23, 59, 59, 999));
    const spy = vi.spyOn(globalThis, 'setTimeout');
    const svc = create();
    const delays = spy.mock.calls.map(c => c[1] as number);
    expect(delays).toContain(1000);
    expect(delays.filter(d => d > 0 && d < 1000)).toEqual([]);
    vi.advanceTimersByTime(1000);
    expect(svc.today()).toBe('2026-10-04');
  });

  it('spinnt bei 00:00:00.000 nicht (genau ein Timer)', () => {
    vi.setSystemTime(new Date(2026, 9, 4, 0, 0, 0, 0));
    create();
    expect(vi.getTimerCount()).toBe(1);
  });

  it('Jahreswechsel', () => {
    vi.setSystemTime(new Date(2026, 11, 31, 23, 59, 30));
    const svc = create();
    vi.advanceTimersByTime(31_000);
    expect(svc.today()).toBe('2027-01-01');
  });

  it('Schaltjahr 2028-02-28 -> 29 -> 03-01', () => {
    vi.setSystemTime(new Date(2028, 1, 28, 23, 59, 30));
    const svc = create();
    vi.advanceTimersByTime(31_000);
    expect(svc.today()).toBe('2028-02-29');
    vi.advanceTimersByTime(new Date(2028, 2, 1).getTime() - Date.now());
    expect(svc.today()).toBe('2028-03-01');
  });

  // Feste lokale Daten: Berlin 2026-03-29 (23 h) / 2026-10-25 (25 h), LA 2026-03-08 / 2026-11-01,
  // Auckland 2026-04-05 (25 h) / 2026-09-27 (23 h). Geprüft werden Invarianten, keine Dauer-Konstanten.
  it.each([
    [2026, 2, 28], [2026, 9, 24], [2026, 2, 7], [2026, 10, 31], [2026, 3, 4], [2026, 8, 26],
  ])('Tageswechsel über Zeitumstellung %i-%i-%i und Folgetag', (y, m, d) => {
    vi.setSystemTime(new Date(y, m, d, 23, 59, 30));
    const svc = create();
    const next = new Date(y, m, d + 1);
    vi.advanceTimersByTime(next.getTime() - Date.now() - 1);
    expect(svc.today()).toBe(toDateKey(new Date(y, m, d)));
    vi.advanceTimersByTime(1);
    expect(svc.today()).toBe(toDateKey(next));
    vi.advanceTimersByTime(new Date(y, m, d + 2).getTime() - Date.now());
    expect(svc.today()).toBe(toDateKey(new Date(y, m, d + 2)));
    vi.advanceTimersByTime(new Date(y, m, d + 3).getTime() - Date.now());
    expect(svc.today()).toBe(toDateKey(new Date(y, m, d + 3)));
  });

  it('visibilitychange visible nach Zeitsprung aktualisiert und plant neu; hidden nicht', () => {
    const svc = create();
    vi.setSystemTime(new Date(2026, 9, 4, 8, 0));
    setVisibility('hidden');
    document.dispatchEvent(new Event('visibilitychange'));
    expect(svc.today()).toBe('2026-10-03');
    setVisibility('visible');
    document.dispatchEvent(new Event('visibilitychange'));
    expect(svc.today()).toBe('2026-10-04');
    expect(vi.getTimerCount()).toBe(1);
    vi.advanceTimersByTime(new Date(2026, 9, 5).getTime() - Date.now());
    expect(svc.today()).toBe('2026-10-05');
  });

  it.each(['focus', 'pageshow'])('window-%s aktualisiert den Key (Standby)', evt => {
    const svc = create();
    vi.setSystemTime(new Date(2026, 9, 4, 8, 0));
    window.dispatchEvent(new Event(evt));
    expect(svc.today()).toBe('2026-10-04');
  });

  it('refresh() setzt den Key; Effect feuert pro Tageswechsel genau einmal', () => {
    const svc = create();
    const seen: string[] = [];
    TestBed.runInInjectionContext(() => effect(() => { seen.push(svc.today()); }));
    TestBed.tick();
    vi.setSystemTime(new Date(2026, 9, 4, 0, 0, 5));
    svc.refresh();
    svc.refresh();
    TestBed.tick();
    vi.advanceTimersByTime(24 * 3600 * 1000);
    TestBed.tick();
    expect(seen).toEqual(['2026-10-03', '2026-10-04', '2026-10-05']);
  });

  it('räumt Listener (gleiche Referenz) und Timer beim Destroy auf', () => {
    const docAdd = vi.spyOn(document, 'addEventListener');
    const docRemove = vi.spyOn(document, 'removeEventListener');
    const winAdd = vi.spyOn(window, 'addEventListener');
    const winRemove = vi.spyOn(window, 'removeEventListener');
    const svc = create();
    TestBed.resetTestingModule();

    const pairs: Array<[typeof docAdd, typeof docRemove, string]> = [
      [docAdd, docRemove, 'visibilitychange'], [winAdd, winRemove, 'focus'], [winAdd, winRemove, 'pageshow'],
    ];
    for (const [add, remove, name] of pairs) {
      const added = add.mock.calls.filter(c => c[0] === name).map(c => c[1]);
      const removed = remove.mock.calls.filter(c => c[0] === name).map(c => c[1]);
      expect(added.length).toBe(1);
      expect(removed).toContain(added[0]);
    }
    expect(vi.getTimerCount()).toBe(0);
    vi.setSystemTime(new Date(2026, 9, 7, 8, 0));
    document.dispatchEvent(new Event('visibilitychange'));
    window.dispatchEvent(new Event('focus'));
    window.dispatchEvent(new Event('pageshow'));
    expect(svc.today()).toBe('2026-10-03');
  });
});
