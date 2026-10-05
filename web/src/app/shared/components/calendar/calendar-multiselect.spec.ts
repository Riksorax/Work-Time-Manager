import { registerLocaleData } from '@angular/common';
import localeDe from '@angular/common/locales/de';
import { ChangeDetectionStrategy, Component, LOCALE_ID, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { CalendarComponent } from './calendar';

registerLocaleData(localeDe);

const key = (d: Date): string =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

/**
 * Spiegelt den Parent (ReportsComponent + ReportsService) ohne Service: dragSelected additiv mit
 * Arbeitstage-Filter Mo-Fr, daysDeselected entfernt, multiSelectEnded beendet Modus und Auswahl.
 */
@Component({
  selector: 'app-calendar-host',
  imports: [CalendarComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-calendar
      [selectedDate]="selectedDate()"
      [multiSelectActive]="active()"
      [multiSelectedDates]="selected()"
      (dateSelected)="onDate($event)"
      (dragSelected)="onDrag($event)"
      (daysDeselected)="onDeselect($event)"
      (multiSelectEnded)="onEnd()"
      (monthChanged)="months.push($event)" />
  `,
})
class HostComponent {
  readonly selectedDate = signal(new Date(2026, 9, 15));
  readonly active = signal(false);
  readonly selected = signal<Set<string>>(new Set());
  readonly drags: string[][] = [];
  readonly deselects: string[][] = [];
  readonly taps: string[] = [];
  readonly months: { year: number; month: number }[] = [];
  ends = 0;

  onDate(d: Date): void {
    this.taps.push(key(d));
    if (!this.active()) {
      this.selectedDate.set(d);
      return;
    }
    this.selected.update(prev => {
      const next = new Set(prev);
      if (next.has(key(d))) next.delete(key(d));
      else next.add(key(d));
      return next;
    });
  }

  onDrag(dates: Date[]): void {
    this.drags.push(dates.map(key));
    this.active.set(true);
    const workdays = dates.filter(d => d.getDay() >= 1 && d.getDay() <= 5);
    this.selected.update(prev => new Set([...prev, ...workdays.map(key)]));
  }

  onDeselect(dates: Date[]): void {
    this.deselects.push(dates.map(key));
    this.selected.update(prev => {
      const next = new Set(prev);
      dates.forEach(d => next.delete(key(d)));
      return next;
    });
  }

  onEnd(): void {
    this.ends++;
    this.active.set(false);
    this.selected.set(new Set());
  }
}

describe('CalendarComponent - Mehrfachauswahl per Tastatur (#377)', () => {
  let fixture: ComponentFixture<HostComponent>;
  let host: HostComponent;
  let el: HTMLElement;

  const cell = (k: string): HTMLElement => el.querySelector(`[data-date="${k}"]`) as HTMLElement;
  const grid = (): HTMLElement => el.querySelector('.calendar-grid') as HTMLElement;
  const focusedKey = (): string | undefined => (document.activeElement as HTMLElement | null)?.dataset['date'];
  const selectedKeys = (): string[] => [...host.selected()].sort();

  const press = (k: string, init: KeyboardEventInit = {}): KeyboardEvent => {
    const ev = new KeyboardEvent('keydown', { key: k, bubbles: true, cancelable: true, ...init });
    (document.activeElement as HTMLElement).dispatchEvent(ev);
    fixture.detectChanges();
    // afterNextRender (Fokus nach Monatswechsel) und Effects laufen im ApplicationRef-Tick, ohne Timer
    TestBed.tick();
    return ev;
  };
  const shift = (k: string, init: KeyboardEventInit = {}): KeyboardEvent =>
    press(k, { shiftKey: true, ...init });
  const lastDrag = (): string[] => host.drags[host.drags.length - 1];
  const range = (from: string, to: string): string[] => {
    const [y, m, d1] = from.split('-').map(Number);
    const [, , d2] = to.split('-').map(Number);
    return Array.from({ length: d2 - d1 + 1 }, (_, i) => key(new Date(y, m - 1, d1 + i)));
  };

  async function setup(date = new Date(2026, 9, 15), focus?: string): Promise<void> {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 15, 12));
    await TestBed.configureTestingModule({
      imports: [HostComponent],
      providers: [provideTranslateService({ fallbackLang: 'de' }), { provide: LOCALE_ID, useValue: 'de-DE' }],
    }).compileComponents();
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', {
      common: { weekdaysShort: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'] },
      shared: {
        calendarPrevMonthAria: 'Vorheriger Monat',
        calendarNextMonthAria: 'Nächster Monat',
        calendarHolidayAria: '{{date}}, Feiertag: {{name}}',
        calendarHasEntryAria: '{{label}}, Eintrag vorhanden',
      },
    });
    translate.use('de');
    fixture = TestBed.createComponent(HostComponent);
    host = fixture.componentInstance;
    host.selectedDate.set(date);
    fixture.detectChanges();
    el = fixture.nativeElement as HTMLElement;
    cell(focus ?? key(date)).focus();
  }

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  describe('Shift+Pfeil aus dem Ruhezustand', () => {
    beforeEach(() => setup());

    it('schaltet den Modus ein: Anker = fokussierter Tag, Bereich 15.-16.10., Fokus wandert', () => {
      const ev = shift('ArrowRight');
      expect(ev.defaultPrevented).toBe(true);
      expect(host.drags).toEqual([['2026-10-15', '2026-10-16']]);
      expect(host.deselects).toEqual([]);
      expect(host.taps).toEqual([]);
      expect(focusedKey()).toBe('2026-10-16');
      expect(host.active()).toBe(true);
      expect(selectedKeys()).toEqual(['2026-10-15', '2026-10-16']);
    });

    it('Shift+Pfeil rechts x3 ergibt 15.-18.10.; der Host filtert Sa/So (17./18.)', () => {
      shift('ArrowRight'); shift('ArrowRight'); shift('ArrowRight');
      expect(lastDrag()).toEqual(range('2026-10-15', '2026-10-18'));
      expect(focusedKey()).toBe('2026-10-18');
      expect(selectedKeys()).toEqual(['2026-10-15', '2026-10-16']);
    });

    it('Gegenrichtung verkleinert und meldet den abgewählten Tag', () => {
      shift('ArrowRight'); shift('ArrowRight'); shift('ArrowRight');
      host.deselects.length = 0;
      shift('ArrowLeft');
      expect(lastDrag()).toEqual(range('2026-10-15', '2026-10-17'));
      expect(host.deselects).toEqual([['2026-10-18']]);
      expect(focusedKey()).toBe('2026-10-17');
    });

    it('Umkehr über den Anker: 15.-17. -> 15.-16. -> 15. -> 14.-15. (abgewählt: 17., 16.)', () => {
      shift('ArrowRight'); shift('ArrowRight'); shift('ArrowRight');
      shift('ArrowLeft'); // 15.-17.
      host.deselects.length = 0;
      shift('ArrowLeft'); // 15.-16.
      shift('ArrowLeft'); // 15.
      shift('ArrowLeft'); // 14.-15.
      expect(host.deselects).toEqual([['2026-10-17'], ['2026-10-16']]);
      expect(lastDrag()).toEqual(['2026-10-14', '2026-10-15']);
      expect(focusedKey()).toBe('2026-10-14');
      expect(selectedKeys()).toEqual(['2026-10-14', '2026-10-15']);
    });

    it('Shift+Pfeil runter/hoch bewegt um +-7 Tage', () => {
      shift('ArrowDown');
      expect(lastDrag()).toEqual(range('2026-10-15', '2026-10-22'));
      expect(focusedKey()).toBe('2026-10-22');
      shift('ArrowUp'); shift('ArrowUp');
      expect(lastDrag()).toEqual(range('2026-10-08', '2026-10-15'));
      expect(focusedKey()).toBe('2026-10-08');
    });

    it('Shift+Home/End: Montag/Sonntag der Zeile, auf den Monat geklemmt', () => {
      shift('Home');
      expect(lastDrag()).toEqual(range('2026-10-12', '2026-10-15'));
      expect(focusedKey()).toBe('2026-10-12');
      shift('End');
      expect(lastDrag()).toEqual(range('2026-10-15', '2026-10-18'));
      expect(focusedKey()).toBe('2026-10-18');
    });

    it('Shift+End am Monatsende wird auf den 31.10. geklemmt', () => {
      cell('2026-10-29').focus();
      shift('End');
      expect(lastDrag()).toEqual(range('2026-10-29', '2026-10-31'));
      expect(focusedKey()).toBe('2026-10-31');
    });

    it('Shift+Home auf einem Montag: idempotenter Bereich mit dem Montag, nichts abgewählt', () => {
      cell('2026-10-12').focus();
      shift('Home');
      expect(host.drags).toEqual([['2026-10-12']]);
      expect(host.deselects).toEqual([]);
      expect(focusedKey()).toBe('2026-10-12');
    });

    it('gehaltene Taste (repeat) erweitert weiter', () => {
      shift('ArrowRight', { repeat: true });
      shift('ArrowRight', { repeat: true });
      expect(lastDrag()).toEqual(range('2026-10-15', '2026-10-17'));
      expect(host.drags).toHaveLength(2);
    });
  });

  describe('vorher gewählte Tage (Base)', () => {
    beforeEach(() => setup());

    it('werden beim Verkleinern/Umkehren nie abgewählt', () => {
      host.active.set(true);
      host.selected.set(new Set(['2026-10-13', '2026-10-14']));
      fixture.detectChanges();
      shift('ArrowLeft'); shift('ArrowLeft'); // Bereich 13.-15., reicht in die Base
      shift('ArrowRight'); shift('ArrowRight'); shift('ArrowRight'); // 15.-16. (Umkehr)
      const removed = host.deselects.flat();
      expect(removed).not.toContain('2026-10-13');
      expect(removed).not.toContain('2026-10-14');
      expect(selectedKeys()).toEqual(['2026-10-13', '2026-10-14', '2026-10-15', '2026-10-16']);
    });
  });

  describe('Monats-, Jahres- und Schaltjahrgrenzen', () => {
    it('Shift+PageDown/PageUp: monthChanged je Wechsel, Fokus nach dem Render, Anker bleibt', async () => {
      await setup();
      shift('PageDown');
      expect(host.months).toEqual([{ year: 2026, month: 11 }]);
      expect(focusedKey()).toBe('2026-11-15');
      expect(selectedKeys()).toContain('2026-10-30');
      expect(selectedKeys()).toContain('2026-11-02');
      expect(selectedKeys()).toContain('2026-11-13');
      expect(selectedKeys()).not.toContain('2026-10-31');
      shift('PageUp');
      expect(host.months).toEqual([{ year: 2026, month: 11 }, { year: 2026, month: 10 }]);
      expect(focusedKey()).toBe('2026-10-15');
      expect(selectedKeys()).toEqual(['2026-10-15']);
    });

    it('Jahreswechsel: Shift+Pfeil rechts vom 31.12. in den 01.01.2027', async () => {
      await setup(new Date(2026, 11, 31));
      shift('ArrowRight');
      expect(host.months).toEqual([{ year: 2027, month: 1 }]);
      expect(lastDrag()).toEqual(['2026-12-31', '2027-01-01']);
      expect(focusedKey()).toBe('2027-01-01');
      expect(selectedKeys()).toEqual(['2026-12-31', '2027-01-01']); // Do und Fr
    });

    it('Schaltjahr 2028: Bereich enthält den 29.02.', async () => {
      await setup(new Date(2028, 1, 28));
      shift('ArrowRight');
      expect(lastDrag()).toEqual(['2028-02-28', '2028-02-29']);
      expect(focusedKey()).toBe('2028-02-29');
      shift('ArrowRight');
      expect(lastDrag()).toEqual(['2028-02-28', '2028-02-29', '2028-03-01']);
    });
  });

  describe('Anker verwerfen', () => {
    beforeEach(() => setup());

    it('Pfeil ohne Shift im Modus: Fokus bewegt, keine Emission, nächster Bereich startet am neuen Fokus', () => {
      shift('ArrowRight'); // Anker 15., Fokus 16.
      const drags = host.drags.length;
      const ev = press('ArrowRight'); // Fokus 17.
      expect(ev.defaultPrevented).toBe(true);
      expect(focusedKey()).toBe('2026-10-17');
      expect(host.drags).toHaveLength(drags);
      expect(host.deselects).toEqual([]);
      expect(host.taps).toEqual([]);
      shift('ArrowRight'); // neuer Anker 17.
      expect(lastDrag()).toEqual(['2026-10-17', '2026-10-18']);
      shift('ArrowLeft');
      expect(lastDrag()).toEqual(['2026-10-17']);
      expect(host.deselects).toEqual([['2026-10-18']]);
      expect(selectedKeys()).toEqual(['2026-10-15', '2026-10-16']);
    });

    for (const [k, expectedFocus] of [
      ['Home', '2026-10-12'], ['End', '2026-10-18'], ['PageUp', '2026-09-16'], ['PageDown', '2026-11-16'],
    ] as const) {
      it(`${k} ohne Shift verwirft den Anker`, () => {
        shift('ArrowRight'); // Anker 15., Fokus 16.
        press(k);
        expect(focusedKey()).toBe(expectedFocus);
        shift('ArrowRight');
        const [y, m, d] = expectedFocus.split('-').map(Number);
        expect(lastDrag()).toEqual([expectedFocus, key(new Date(y, m - 1, d + 1))]);
      });
    }

    it('Enter/Space im Modus: dateSelected genau einmal, Anker verworfen, repeat ignoriert', () => {
      shift('ArrowRight'); // Anker 15., Fokus 16.
      const enter = press('Enter');
      expect(enter.defaultPrevented).toBe(true);
      expect(host.taps).toEqual(['2026-10-16']);
      const space = press(' ');
      expect(space.defaultPrevented).toBe(true);
      expect(host.taps).toEqual(['2026-10-16', '2026-10-16']);
      const rep = press(' ', { repeat: true });
      expect(rep.defaultPrevented).toBe(true);
      expect(host.taps).toHaveLength(2);
      shift('ArrowRight');
      expect(lastDrag()).toEqual(['2026-10-16', '2026-10-17']);
    });

    it('Enter ohne Modus bleibt die Einzelauswahl aus Teil 1', () => {
      press('Enter');
      expect(host.taps).toEqual(['2026-10-15']);
      expect(host.drags).toEqual([]);
    });

    it('pointerdown (Tap im Kalender) verwirft den Anker', () => {
      const efp = vi.fn();
      Object.defineProperty(document, 'elementFromPoint', { value: efp, configurable: true });
      try {
        const card = el.querySelector('.calendar-card') as HTMLElement;
        card.setPointerCapture = vi.fn();
        card.releasePointerCapture = vi.fn();
        card.hasPointerCapture = vi.fn().mockReturnValue(false);
        const ptr = (type: string): PointerEvent =>
          Object.assign(new Event(type, { cancelable: true, bubbles: true }), { clientX: 1, clientY: 1, pointerId: 1 }) as unknown as PointerEvent;
        shift('ArrowRight'); // Anker 15.
        efp.mockReturnValue(cell('2026-10-20').querySelector('.day-number'));
        card.dispatchEvent(ptr('pointerdown'));
        card.dispatchEvent(ptr('pointerup'));
        fixture.detectChanges();
        expect(focusedKey()).toBe('2026-10-20');
        shift('ArrowRight');
        expect(lastDrag()).toEqual(['2026-10-20', '2026-10-21']);
      } finally {
        delete (document as unknown as Record<string, unknown>)['elementFromPoint'];
      }
    });

    it('focusout nach außen verwirft den Anker, focusout in eine andere Zelle nicht', () => {
      shift('ArrowRight'); // Anker 15., Fokus 16.
      const outside = document.createElement('button');
      document.body.appendChild(outside);
      try {
        const out = (related: Element): void => {
          (document.activeElement as HTMLElement).dispatchEvent(
            new FocusEvent('focusout', { bubbles: true, relatedTarget: related }),
          );
        };
        out(cell('2026-10-20'));
        shift('ArrowRight');
        expect(lastDrag()).toEqual(range('2026-10-15', '2026-10-17')); // Anker blieb 15.
        out(outside);
        shift('ArrowRight'); // Fokus stand auf 17., neuer Anker 17.
        expect(lastDrag()).toEqual(['2026-10-17', '2026-10-18']);
      } finally {
        outside.remove();
      }
    });

    it('externes Ausschalten verwirft den Anker, ohne den Fokus zu ändern', () => {
      shift('ArrowRight'); // Anker 15., Fokus 16.
      host.active.set(false);
      fixture.detectChanges();
      TestBed.tick();
      expect(focusedKey()).toBe('2026-10-16');
      host.active.set(true);
      fixture.detectChanges();
      TestBed.tick();
      shift('ArrowRight');
      expect(lastDrag()).toEqual(['2026-10-16', '2026-10-17']);
    });

    it('Maus-Drag emittiert dragSelected unverändert und ändert den Anker-Zustand nicht', () => {
      const efp = vi.fn();
      Object.defineProperty(document, 'elementFromPoint', { value: efp, configurable: true });
      try {
        const card = el.querySelector('.calendar-card') as HTMLElement;
        card.setPointerCapture = vi.fn();
        card.releasePointerCapture = vi.fn();
        card.hasPointerCapture = vi.fn().mockReturnValue(false);
        const ptr = (type: string): PointerEvent =>
          Object.assign(new Event(type, { cancelable: true, bubbles: true }), { clientX: 1, clientY: 1, pointerId: 1 }) as unknown as PointerEvent;
        efp.mockReturnValue(cell('2026-10-20').querySelector('.day-number'));
        card.dispatchEvent(ptr('pointerdown'));
        efp.mockReturnValue(cell('2026-10-22').querySelector('.day-number'));
        card.dispatchEvent(ptr('pointermove'));
        card.dispatchEvent(ptr('pointerup'));
        fixture.detectChanges();
        expect(lastDrag()).toEqual(['2026-10-20', '2026-10-21', '2026-10-22']);
        expect(host.deselects).toEqual([]);
        expect(focusedKey()).toBe('2026-10-15');
        shift('ArrowRight');
        expect(lastDrag()).toEqual(['2026-10-15', '2026-10-16']);
      } finally {
        delete (document as unknown as Record<string, unknown>)['elementFromPoint'];
      }
    });
  });

  describe('Escape', () => {
    beforeEach(() => setup());

    it('beendet im aktiven Modus genau einmal; Fokus bleibt, Anker verworfen', () => {
      shift('ArrowRight'); // Modus an, Fokus 16.
      const ev = press('Escape');
      expect(ev.defaultPrevented).toBe(true);
      expect(host.ends).toBe(1);
      expect(host.active()).toBe(false);
      expect(focusedKey()).toBe('2026-10-16');
      shift('ArrowRight');
      expect(lastDrag()).toEqual(['2026-10-16', '2026-10-17']);
    });

    it('ist ohne aktiven Modus unbehandelt', () => {
      const ev = press('Escape');
      expect(ev.defaultPrevented).toBe(false);
      expect(host.ends).toBe(0);
    });

    it('ist mit Modifikator unbehandelt', () => {
      host.active.set(true);
      fixture.detectChanges();
      for (const init of [{ ctrlKey: true }, { altKey: true }, { metaKey: true }, { shiftKey: true }]) {
        const ev = press('Escape', init);
        expect(ev.defaultPrevented, JSON.stringify(init)).toBe(false);
      }
      expect(host.ends).toBe(0);
    });
  });

  describe('unbehandelte Kombinationen im aktiven Modus', () => {
    beforeEach(() => setup());

    it('Ctrl+Space, Shift+Space, Shift+Enter, Ctrl/Alt/Meta+Shift+Pfeil, Ctrl+Shift+Home/PageDown', () => {
      host.active.set(true);
      fixture.detectChanges();
      const variants: [string, KeyboardEventInit][] = [
        [' ', { ctrlKey: true }], [' ', { shiftKey: true }], ['Enter', { shiftKey: true }],
        ['ArrowRight', { ctrlKey: true, shiftKey: true }], ['ArrowRight', { altKey: true, shiftKey: true }],
        ['ArrowRight', { metaKey: true, shiftKey: true }],
        ['Home', { ctrlKey: true, shiftKey: true }], ['PageDown', { ctrlKey: true, shiftKey: true }],
      ];
      for (const [k, init] of variants) {
        const ev = press(k, init);
        expect(ev.defaultPrevented, `${k} ${JSON.stringify(init)}`).toBe(false);
        expect(focusedKey()).toBe('2026-10-15');
      }
      expect(host.drags).toEqual([]);
      expect(host.deselects).toEqual([]);
      expect(host.taps).toEqual([]);
      expect(host.months).toEqual([]);
    });
  });

  describe('ARIA', () => {
    beforeEach(() => setup());

    it('aria-multiselectable="true" nur bei aktivem Modus, sonst fehlt das Attribut', () => {
      expect(grid().hasAttribute('aria-multiselectable')).toBe(false);
      host.active.set(true);
      fixture.detectChanges();
      expect(grid().getAttribute('aria-multiselectable')).toBe('true');
      host.active.set(false);
      fixture.detectChanges();
      expect(grid().hasAttribute('aria-multiselectable')).toBe(false);
    });

    it('aktiver Modus mit leerer Menge: alle Zellen aria-selected=false, keine .selected-Zelle', () => {
      expect(cell('2026-10-15').getAttribute('aria-selected')).toBe('true');
      host.active.set(true);
      fixture.detectChanges();
      for (const c of Array.from(el.querySelectorAll('[data-date]'))) {
        expect(c.getAttribute('aria-selected')).toBe('false');
      }
      expect(el.querySelectorAll('.calendar-day.selected')).toHaveLength(0);
      host.active.set(false);
      fixture.detectChanges();
      expect(cell('2026-10-15').getAttribute('aria-selected')).toBe('true');
      expect(cell('2026-10-15').classList.contains('selected')).toBe(true);
    });

    it('Modus- und Mengenänderung per Input stehlen keinen Fokus', () => {
      const outside = document.createElement('button');
      document.body.appendChild(outside);
      try {
        outside.focus();
        host.active.set(true);
        host.selected.set(new Set(['2026-10-12']));
        fixture.detectChanges();
        TestBed.tick();
        expect(document.activeElement).toBe(outside);
      } finally {
        outside.remove();
      }
    });
  });
});
