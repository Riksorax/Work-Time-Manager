import { registerLocaleData } from '@angular/common';
import localeDe from '@angular/common/locales/de';
import { LOCALE_ID } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { CalendarComponent } from './calendar';
import { TodayService } from '../../../core/services/today';

registerLocaleData(localeDe);

describe('CalendarComponent - Tastatur und ARIA (#377)', () => {
  let fixture: ComponentFixture<CalendarComponent>;
  let translate: TranslateService;
  let el: HTMLElement;

  const cell = (key: string): HTMLElement => el.querySelector(`[data-date="${key}"]`) as HTMLElement;
  const dayCells = (): HTMLElement[] => Array.from(el.querySelectorAll('[data-date]'));
  const grid = (): HTMLElement => el.querySelector('.calendar-grid') as HTMLElement;

  async function setup(selected = new Date(2026, 9, 15)): Promise<void> {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 15, 12));
    await TestBed.configureTestingModule({
      imports: [CalendarComponent],
      providers: [provideTranslateService({ fallbackLang: 'de' }), { provide: LOCALE_ID, useValue: 'de-DE' }],
    }).compileComponents();
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', {
      common: { weekdaysShort: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'] },
      shared: {
        calendarPrevMonthAria: 'Vorheriger Monat',
        calendarNextMonthAria: 'Nächster Monat',
        calendarHolidayAria: '{{date}}, Feiertag: {{name}}',
        calendarHasEntryAria: '{{label}}, Eintrag vorhanden',
      },
      holidays: { germanUnityDay: 'Tag der Deutschen Einheit' },
    });
    translate.setTranslation('en', {
      shared: {
        calendarHolidayAria: '{{date}}, public holiday: {{name}}',
        calendarHasEntryAria: '{{label}}, entry available',
      },
      holidays: { germanUnityDay: 'German Unity Day' },
    });
    translate.use('de');
    fixture = TestBed.createComponent(CalendarComponent);
    fixture.componentRef.setInput('selectedDate', selected);
    fixture.detectChanges();
    el = fixture.nativeElement as HTMLElement;
  }

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  describe('ARIA-Struktur', () => {
    beforeEach(() => setup());

    it('Grid hat nur role=row als direkte Kinder, Kopfzeile mit 7 columnheader', () => {
      expect(grid().getAttribute('role')).toBe('grid');
      const children = Array.from(grid().children);
      expect(children.length).toBeGreaterThan(0);
      for (const c of children) expect(c.getAttribute('role')).toBe('row');
      expect(children[0].querySelectorAll('[role=columnheader]')).toHaveLength(7);
      expect(children[0].children).toHaveLength(7);
    });

    it('Oktober 2026: 5 Datenzeilen mit je 7 gridcells', () => {
      const rows = Array.from(grid().children).slice(1);
      expect(rows).toHaveLength(5);
      for (const r of rows) {
        expect(r.children).toHaveLength(7);
        for (const c of Array.from(r.children)) expect(c.getAttribute('role')).toBe('gridcell');
      }
      expect(dayCells()).toHaveLength(31);
    });

    it('hat kein aria-pressed', () => {
      expect(el.querySelectorAll('[aria-pressed]')).toHaveLength(0);
    });

    it('aria-selected im Einzelmodus nur auf selectedDate, sonst explizit false', () => {
      for (const c of dayCells()) {
        expect(c.getAttribute('aria-selected')).toBe(c.dataset['date'] === '2026-10-15' ? 'true' : 'false');
      }
    });

    it('aria-selected im Mehrfachmodus konsistent zu multi-selected', () => {
      fixture.componentRef.setInput('multiSelectedDates', new Set(['2026-10-05', '2026-10-06']));
      fixture.detectChanges();
      const selected = dayCells().filter(c => c.getAttribute('aria-selected') === 'true').map(c => c.dataset['date']);
      expect(selected).toEqual(['2026-10-05', '2026-10-06']);
      expect(cell('2026-10-15').getAttribute('aria-selected')).toBe('false');
      expect(cell('2026-10-05').classList).toContain('multi-selected');
      expect(cell('2026-10-15').classList).not.toContain('selected');
    });

    it('aria-current=date nur auf heute und nach Mitternacht auf dem Folgetag', () => {
      const current = (): string[] => dayCells().filter(c => c.hasAttribute('aria-current')).map(c => c.dataset['date']!);
      expect(current()).toEqual(['2026-10-15']);
      expect(cell('2026-10-15').getAttribute('aria-current')).toBe('date');
      vi.setSystemTime(new Date(2026, 9, 16, 0, 0, 5));
      TestBed.inject(TodayService).refresh();
      fixture.detectChanges();
      expect(current()).toEqual(['2026-10-16']);
    });

    it('Label enthält Wochentag und Datum', () => {
      expect(cell('2026-10-15').getAttribute('aria-label')).toBe('Donnerstag, 15. Oktober 2026');
    });

    it('Label: Datum, Feiertag, Eintrag in dieser Reihenfolge', () => {
      fixture.componentRef.setInput('bundesland', 'bayern');
      fixture.componentRef.setInput('daysWithEntries', [3, 15]);
      fixture.detectChanges();
      expect(cell('2026-10-03').getAttribute('aria-label'))
        .toBe('Samstag, 3. Oktober 2026, Feiertag: Tag der Deutschen Einheit, Eintrag vorhanden');
      expect(cell('2026-10-15').getAttribute('aria-label')).toBe('Donnerstag, 15. Oktober 2026, Eintrag vorhanden');
      expect(cell('2026-10-14').getAttribute('aria-label')).toBe('Mittwoch, 14. Oktober 2026');
    });

    it('Eintragshinweis in Englisch', () => {
      fixture.componentRef.setInput('daysWithEntries', [15]);
      translate.use('en');
      fixture.detectChanges();
      expect(cell('2026-10-15').getAttribute('aria-label')).toContain(', entry available');
    });

    it('leere Zellen (3 vor Monatsbeginn, 1 nach Monatsende) sind aria-hidden ohne tabindex und data-date', () => {
      const empties = Array.from(el.querySelectorAll('.calendar-day.empty'));
      expect(empties).toHaveLength(4);
      for (const e of empties) {
        expect(e.getAttribute('aria-hidden')).toBe('true');
        expect(e.hasAttribute('tabindex')).toBe(false);
        expect(e.hasAttribute('data-date')).toBe(false);
      }
    });
  });

  describe('Roving tabindex', () => {
    const stops = (): string[] =>
      Array.from(grid().querySelectorAll('[tabindex="0"]')).map(c => (c as HTMLElement).dataset['date'] ?? '?');

    beforeEach(() => setup());

    it('hat initial genau einen Tab-Stopp auf selectedDate, übrige -1, leere ohne tabindex', () => {
      expect(stops()).toEqual(['2026-10-15']);
      for (const c of dayCells()) {
        if (c.dataset['date'] !== '2026-10-15') expect(c.getAttribute('tabindex')).toBe('-1');
      }
      for (const e of Array.from(el.querySelectorAll('.calendar-day.empty'))) {
        expect(e.hasAttribute('tabindex')).toBe(false);
      }
    });

    it('Fallback nach dem Blättern: Tag 1, zurück: selectedDate', () => {
      fixture.componentInstance.changeMonth(1);
      fixture.detectChanges();
      expect(stops()).toEqual(['2026-11-01']);
      fixture.componentInstance.changeMonth(-1);
      fixture.detectChanges();
      expect(stops()).toEqual(['2026-10-15']);
    });

    it('selectedDate hat Vorrang vor heute, heute vor Tag 1', () => {
      fixture.componentRef.setInput('selectedDate', new Date(2026, 9, 8));
      fixture.detectChanges();
      expect(stops()).toEqual(['2026-10-08']);
      // selectedDate im Oktober, Ansicht November, heute in November
      vi.setSystemTime(new Date(2026, 10, 20, 12));
      TestBed.inject(TodayService).refresh();
      fixture.componentInstance.changeMonth(1);
      fixture.detectChanges();
      expect(stops()).toEqual(['2026-11-20']);
      fixture.componentInstance.changeMonth(1);
      fixture.detectChanges();
      expect(stops()).toEqual(['2026-12-01']);
    });

    it('hat beim Blättern immer genau einen Tab-Stopp im Grid', () => {
      for (const delta of [1, 1, 1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1]) {
        fixture.componentInstance.changeMonth(delta);
        fixture.detectChanges();
        expect(stops()).toHaveLength(1);
        expect(grid().querySelectorAll('[tabindex]:not([tabindex="-1"])')).toHaveLength(1);
      }
    });
  });

  describe('Tastatursteuerung im Monat', () => {
    let selected: Date[];
    let dragged: Date[][];
    let months: { year: number; month: number }[];

    const press = (
      key: string,
      init: KeyboardEventInit = {},
      target: HTMLElement = document.activeElement as HTMLElement,
    ): KeyboardEvent => {
      const ev = new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true, ...init });
      target.dispatchEvent(ev);
      fixture.detectChanges();
      return ev;
    };
    const focusedKey = (): string | undefined => (document.activeElement as HTMLElement | null)?.dataset['date'];

    // setzt Ansicht und Roving-Stand zurück (neue Date-Instanz triggert den selectedDate-Effekt)
    const resetToOctober = (): void => {
      fixture.componentRef.setInput('selectedDate', new Date(2026, 9, 15));
      fixture.detectChanges();
      cell('2026-10-15').focus();
    };

    beforeEach(async () => {
      await setup();
      selected = [];
      dragged = [];
      months = [];
      fixture.componentInstance.dateSelected.subscribe(d => selected.push(d));
      fixture.componentInstance.dragSelected.subscribe(r => dragged.push(r));
      fixture.componentInstance.monthChanged.subscribe(m => months.push(m));
      cell('2026-10-15').focus();
    });

    it('Pfeile bewegen den Fokus und den Tab-Stopp', () => {
      const cases: [string, string][] = [
        ['ArrowRight', '2026-10-16'], ['ArrowLeft', '2026-10-14'],
        ['ArrowDown', '2026-10-22'], ['ArrowUp', '2026-10-08'],
      ];
      for (const [key, expected] of cases) {
        resetToOctober();
        press(key);
        expect(focusedKey()).toBe(expected);
        expect(cell(expected).getAttribute('tabindex')).toBe('0');
        expect(grid().querySelectorAll('[tabindex="0"]')).toHaveLength(1);
      }
    });

    it('setzt den Tab-Stopp bei geänderter Auswahl von außen auf selectedDate zurück', () => {
      press('ArrowRight');
      expect(cell('2026-10-16').getAttribute('tabindex')).toBe('0');
      fixture.componentRef.setInput('selectedDate', new Date(2026, 9, 8));
      fixture.detectChanges();
      expect(cell('2026-10-08').getAttribute('tabindex')).toBe('0');
      expect(grid().querySelectorAll('[tabindex="0"]')).toHaveLength(1);
    });

    it('Pfeile emittieren weder dateSelected noch dragSelected noch monthChanged', () => {
      press('ArrowRight');
      press('ArrowDown');
      expect(selected).toHaveLength(0);
      expect(dragged).toHaveLength(0);
      expect(months).toHaveLength(0);
    });

    it('Home/End/Strg+Home/Strg+End', () => {
      cell('2026-10-14').focus();
      press('Home');
      expect(focusedKey()).toBe('2026-10-12');
      press('End');
      expect(focusedKey()).toBe('2026-10-18');
      press('Home', { ctrlKey: true });
      expect(focusedKey()).toBe('2026-10-01');
      press('End', { ctrlKey: true });
      expect(focusedKey()).toBe('2026-10-31');
    });

    it('Enter und Leertaste emittieren dateSelected genau einmal, Fokus bleibt', () => {
      cell('2026-10-22').focus();
      const enter = press('Enter');
      expect(selected).toHaveLength(1);
      expect(selected[0].getTime()).toBe(new Date(2026, 9, 22).getTime());
      // preventDefault bei Enter: verhindert synthetischen Click / Doppelauslösung
      expect(enter.defaultPrevented).toBe(true);
      const space = press(' ');
      expect(selected).toHaveLength(2);
      expect(selected[1].getTime()).toBe(new Date(2026, 9, 22).getTime());
      expect(space.defaultPrevented).toBe(true);
      expect(focusedKey()).toBe('2026-10-22');
    });

    it('ignoriert Enter/Leertaste bei event.repeat (kein Toggeln per Tastenwiederholung)', () => {
      const enter = press('Enter', { repeat: true });
      const space = press(' ', { repeat: true });
      expect(selected).toHaveLength(0);
      // Wiederholung wird trotzdem abgefangen, damit Space nicht scrollt
      expect(enter.defaultPrevented).toBe(true);
      expect(space.defaultPrevented).toBe(true);
    });

    it('verhindert den Standard bei Navigationstasten', () => {
      for (const key of ['ArrowRight', 'ArrowLeft', 'ArrowDown', 'ArrowUp', 'Home', 'End', 'PageUp', 'PageDown']) {
        resetToOctober();
        expect(press(key).defaultPrevented).toBe(true);
      }
    });

    it('lässt Ctrl/Alt/Meta/Shift+Pfeil, Tab und andere Tasten unbehandelt', () => {
      const variants: [string, KeyboardEventInit][] = [
        ['ArrowRight', { ctrlKey: true }], ['ArrowRight', { altKey: true }],
        ['ArrowRight', { metaKey: true }], ['Enter', { shiftKey: true }], [' ', { shiftKey: true }],
        ['ArrowRight', { ctrlKey: true, shiftKey: true }], ['ArrowRight', { altKey: true, shiftKey: true }],
        ['ArrowRight', { metaKey: true, shiftKey: true }],
        ['PageDown', { ctrlKey: true }], ['Enter', { ctrlKey: true }],
        ['Tab', {}], ['a', {}],
      ];
      for (const [key, init] of variants) {
        const ev = press(key, init);
        expect(ev.defaultPrevented, `${key} ${JSON.stringify(init)}`).toBe(false);
        expect(focusedKey()).toBe('2026-10-15');
      }
      expect(selected).toHaveLength(0);
      expect(months).toHaveLength(0);
    });

    it('ignoriert Keydown mit Target außerhalb einer Zelle', () => {
      const ev = press('ArrowRight', {}, grid());
      expect(ev.defaultPrevented).toBe(false);
      expect(focusedKey()).toBe('2026-10-15');
    });

    it('Keydown auf Header-Buttons erreicht den Grid-Handler nicht', () => {
      const btn = el.querySelector('.calendar-header button') as HTMLElement;
      btn.focus();
      const ev = press('ArrowRight', {}, btn);
      expect(ev.defaultPrevented).toBe(false);
      expect(document.activeElement).toBe(btn);
    });
  });

  describe('Monatswechsel per Tastatur', () => {
    let months: { year: number; month: number }[];
    let selected: Date[];

    const press = (key: string, init: KeyboardEventInit = {}): KeyboardEvent => {
      const ev = new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true, ...init });
      (document.activeElement as HTMLElement).dispatchEvent(ev);
      fixture.detectChanges();
      // afterNextRender-Hooks laufen nicht in fixture.detectChanges(), sondern im ApplicationRef-Tick (ohne Timer)
      TestBed.tick();
      return ev;
    };
    const focusedKey = (): string | undefined => (document.activeElement as HTMLElement | null)?.dataset['date'];
    const heading = (): string => el.querySelector('.current-month')!.textContent!.trim();
    const start = async (date: Date, focusKey: string): Promise<void> => {
      await setup(date);
      months = [];
      selected = [];
      fixture.componentInstance.monthChanged.subscribe(m => months.push(m));
      fixture.componentInstance.dateSelected.subscribe(d => selected.push(d));
      cell(focusKey).focus();
    };

    it('ArrowRight auf dem 31.10. wechselt in den November und fokussiert den 1.11.', async () => {
      await start(new Date(2026, 9, 15), '2026-10-31');
      press('ArrowRight');
      expect(months).toEqual([{ year: 2026, month: 11 }]);
      expect(heading()).toBe('November 2026');
      expect(grid().getAttribute('aria-label')).toBe('November 2026');
      expect(focusedKey()).toBe('2026-11-01');
      expect(cell('2026-11-01').getAttribute('tabindex')).toBe('0');
      expect(grid().querySelectorAll('[tabindex="0"]')).toHaveLength(1);
      expect(selected).toHaveLength(0);
    });

    it('ArrowLeft/Down/Up über die Monatsgrenze', async () => {
      await start(new Date(2026, 9, 15), '2026-10-01');
      press('ArrowLeft');
      expect(months.at(-1)).toEqual({ year: 2026, month: 9 });
      expect(focusedKey()).toBe('2026-09-30');
      fixture.componentInstance.changeMonth(1);
      fixture.detectChanges();
      cell('2026-10-28').focus();
      press('ArrowDown');
      expect(focusedKey()).toBe('2026-11-04');
      cell('2026-11-05').focus();
      press('ArrowUp');
      expect(focusedKey()).toBe('2026-10-29');
      expect(heading()).toBe('Oktober 2026');
    });

    it('Jahreswechsel vorwärts und zurück', async () => {
      await start(new Date(2026, 11, 31), '2026-12-31');
      press('ArrowRight');
      expect(months).toEqual([{ year: 2027, month: 1 }]);
      expect(focusedKey()).toBe('2027-01-01');
      press('ArrowLeft');
      expect(months.at(-1)).toEqual({ year: 2026, month: 12 });
      expect(focusedKey()).toBe('2026-12-31');
    });

    it('PageDown klemmt auf den 28.02., PageUp wechselt in den Vormonat', async () => {
      await start(new Date(2026, 0, 31), '2026-01-31');
      press('PageDown');
      expect(months).toEqual([{ year: 2026, month: 2 }]);
      expect(focusedKey()).toBe('2026-02-28');
      expect(grid().querySelectorAll('[tabindex="0"]')).toHaveLength(1);
      expect(cell('2026-02-28').getAttribute('tabindex')).toBe('0');
    });

    it('PageUp aus dem 15.10. fokussiert den 15.09.', async () => {
      await start(new Date(2026, 9, 15), '2026-10-15');
      press('PageUp');
      expect(months).toEqual([{ year: 2026, month: 9 }]);
      expect(focusedKey()).toBe('2026-09-15');
    });

    it('emittiert monthChanged bei Tastatur-Monatswechsel genau einmal', async () => {
      await start(new Date(2026, 9, 15), '2026-10-31');
      press('ArrowRight');
      fixture.detectChanges();
      expect(months).toHaveLength(1);
    });

    describe('kein Fokusdiebstahl', () => {
      let outside: HTMLButtonElement;
      beforeEach(async () => {
        await setup();
        outside = document.createElement('button');
        document.body.appendChild(outside);
        outside.focus();
      });
      afterEach(() => outside.remove());

      it('Input-Änderungen, Mitternacht und Button-Monatswechsel lassen den Fokus unberührt', () => {
        fixture.componentRef.setInput('daysWithEntries', [1, 2]);
        fixture.detectChanges();
        fixture.componentRef.setInput('selectedDate', new Date(2026, 10, 3));
        fixture.detectChanges();
        vi.setSystemTime(new Date(2026, 10, 4, 0, 0, 5));
        TestBed.inject(TodayService).refresh();
        fixture.detectChanges();
        fixture.componentInstance.changeMonth(1);
        fixture.detectChanges();
        TestBed.tick();
        expect(document.activeElement).toBe(outside);
      });

      it('Klick auf den Header-Button setzt den Fokus nicht ins Grid', () => {
        const next = el.querySelectorAll<HTMLElement>('.calendar-header button')[1];
        next.focus();
        next.click();
        fixture.detectChanges();
        expect(heading()).toBe('November 2026');
        expect(document.activeElement).toBe(next);
      });
    });
  });

  describe('Tap setzt den Roving-Stand', () => {
    let selected: Date[];
    let dragged: Date[][];
    let elementFromPoint: ReturnType<typeof vi.fn>;
    let original: typeof document.elementFromPoint | undefined;

    const pointer = (type: string, x: number): PointerEvent =>
      Object.assign(new Event(type, { cancelable: true }), { clientX: x, clientY: 0, pointerId: 1 }) as unknown as PointerEvent;

    beforeEach(async () => {
      await setup();
      selected = [];
      dragged = [];
      original = document.elementFromPoint;
      elementFromPoint = vi.fn();
      document.elementFromPoint = elementFromPoint as unknown as typeof document.elementFromPoint;
      fixture.componentInstance.dateSelected.subscribe(d => selected.push(d));
      fixture.componentInstance.dragSelected.subscribe(r => dragged.push(r));
      const card = el.querySelector('.calendar-card') as HTMLElement;
      card.setPointerCapture = vi.fn();
      card.releasePointerCapture = vi.fn();
      card.hasPointerCapture = vi.fn().mockReturnValue(false);
    });

    afterEach(() => {
      if (original) document.elementFromPoint = original;
      else delete (document as unknown as Record<string, unknown>)['elementFromPoint'];
    });

    it('Tap auf den 20.10. wählt wie bisher und setzt tabindex und Fokus dorthin', () => {
      elementFromPoint.mockReturnValue(cell('2026-10-20').querySelector('.day-number'));
      fixture.componentInstance.onCardPointerDown(pointer('pointerdown', 1));
      fixture.componentInstance.onCardPointerUp(pointer('pointerup', 1));
      fixture.detectChanges();
      expect(selected).toHaveLength(1);
      expect(selected[0].getTime()).toBe(new Date(2026, 9, 20).getTime());
      expect(cell('2026-10-20').getAttribute('tabindex')).toBe('0');
      expect(grid().querySelectorAll('[tabindex="0"]')).toHaveLength(1);
      expect(document.activeElement).toBe(cell('2026-10-20'));
    });

    it('Drag [3,4,5] emittiert dragSelected unverändert und lässt den Roving-Stand stehen', () => {
      elementFromPoint.mockReturnValue(cell('2026-10-03'));
      fixture.componentInstance.onCardPointerDown(pointer('pointerdown', 1));
      elementFromPoint.mockReturnValue(cell('2026-10-05'));
      fixture.componentInstance.onCardPointerMove(pointer('pointermove', 2));
      fixture.componentInstance.onCardPointerUp(pointer('pointerup', 2));
      fixture.detectChanges();
      expect(dragged.at(-1)!.map(d => d.getDate())).toEqual([3, 4, 5]);
      expect(selected).toHaveLength(0);
      expect(cell('2026-10-15').getAttribute('tabindex')).toBe('0');
    });
  });
});
