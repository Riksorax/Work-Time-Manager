import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { CalendarComponent } from './calendar';
import { Bundesland } from '../../models';

describe('CalendarComponent - Feiertage (#371)', () => {
  let fixture: ComponentFixture<CalendarComponent>;
  let translate: TranslateService;

  beforeEach(async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 15, 12));
    await TestBed.configureTestingModule({
      imports: [CalendarComponent],
      providers: [provideTranslateService({ fallbackLang: 'de' })],
    }).compileComponents();
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', {
      common: { weekdaysShort: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'] },
      shared: {
        calendarPrevMonthAria: 'Vorheriger Monat',
        calendarNextMonthAria: 'Nächster Monat',
        calendarHolidayAria: '{{date}}, Feiertag: {{name}}',
      },
      holidays: {
        germanUnityDay: 'Tag der Deutschen Einheit',
        reformationDay: 'Reformationstag',
        repentanceDay: 'Buß- und Bettag',
        newYear: 'Neujahr',
        epiphany: 'Heilige Drei Könige',
        christmasDay1: '1. Weihnachtsfeiertag',
      },
    });
    translate.setTranslation('en', {
      shared: { calendarHolidayAria: '{{date}}, public holiday: {{name}}' },
      holidays: { germanUnityDay: 'German Unity Day' },
    });
    translate.use('de');
    fixture = TestBed.createComponent(CalendarComponent);
    fixture.componentRef.setInput('selectedDate', new Date(2026, 9, 15));
    fixture.detectChanges();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  const cell = (key: string): HTMLElement =>
    fixture.nativeElement.querySelector(`[data-date="${key}"]`) as HTMLElement;
  const setBundesland = (b: Bundesland | null): void => {
    fixture.componentRef.setInput('bundesland', b);
    fixture.detectChanges();
  };
  const holidayCells = (): HTMLElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('.calendar-day.holiday'));

  it('markiert den Tag der Deutschen Einheit in Bayern mit Klasse und aria-label', () => {
    setBundesland('bayern');
    expect(cell('2026-10-03').classList).toContain('holiday');
    expect(cell('2026-10-03').getAttribute('aria-label')).toContain('Feiertag: Tag der Deutschen Einheit');
    expect(cell('2026-10-04').classList).not.toContain('holiday');
  });

  it('markiert den Reformationstag nur in Brandenburg', () => {
    setBundesland('brandenburg');
    expect(cell('2026-10-31').classList).toContain('holiday');
    setBundesland('bayern');
    expect(cell('2026-10-31').classList).not.toContain('holiday');
  });

  it('markiert ohne Bundesland nichts', () => {
    expect(holidayCells()).toHaveLength(0);
    setBundesland(null);
    expect(holidayCells()).toHaveLength(0);
  });

  it('markiert den Buß- und Bettag nur in Sachsen', () => {
    fixture.componentRef.setInput('selectedDate', new Date(2026, 10, 10));
    setBundesland('sachsen');
    expect(cell('2026-11-18').classList).toContain('holiday');
    setBundesland('bayern');
    expect(cell('2026-11-18').classList).not.toContain('holiday');
  });

  it('nimmt das Jahr aus dem angezeigten Monat (Jahreswechsel vorwärts)', () => {
    fixture.componentRef.setInput('selectedDate', new Date(2026, 11, 15));
    setBundesland('bayern');
    fixture.componentInstance.changeMonth(1);
    fixture.detectChanges();
    expect(cell('2027-01-01').classList).toContain('holiday');
    expect(cell('2027-01-06').classList).toContain('holiday');
    setBundesland('berlin');
    expect(cell('2027-01-01').classList).toContain('holiday');
    expect(cell('2027-01-06').classList).not.toContain('holiday');
  });

  it('nimmt das Jahr aus dem angezeigten Monat (Jahreswechsel rückwärts)', () => {
    fixture.componentRef.setInput('selectedDate', new Date(2027, 0, 15));
    setBundesland('bayern');
    fixture.componentInstance.changeMonth(-1);
    fixture.detectChanges();
    expect(cell('2026-12-25').classList).toContain('holiday');
  });

  it('übersetzt den Namen reaktiv bei Sprachwechsel', () => {
    setBundesland('bayern');
    translate.use('en');
    fixture.detectChanges();
    const label = cell('2026-10-03').getAttribute('aria-label')!;
    expect(label).toContain('public holiday: German Unity Day');
  });

  it('zeigt bei Feiertag mit Eintrag weiter den Eintragspunkt', () => {
    fixture.componentRef.setInput('daysWithEntries', [3]);
    setBundesland('bayern');
    expect(cell('2026-10-03').querySelector('.entry-dot')).not.toBeNull();
    expect(cell('2026-10-03').classList).toContain('holiday');
  });

  it('kombiniert selected und holiday', () => {
    fixture.componentRef.setInput('selectedDate', new Date(2026, 9, 3));
    setBundesland('bayern');
    expect(cell('2026-10-03').classList).toContain('selected');
    expect(cell('2026-10-03').classList).toContain('holiday');
  });

  it('kombiniert today und holiday', () => {
    fixture.componentRef.setInput('selectedDate', new Date(2026, 9, 3));
    vi.setSystemTime(new Date(2026, 9, 3, 12));
    setBundesland('bayern');
    expect(cell('2026-10-03').classList).toContain('today');
    expect(cell('2026-10-03').classList).toContain('holiday');
  });

  it('lässt das aria-label normaler Tage unverändert (nur Datum)', () => {
    setBundesland('bayern');
    const label = cell('2026-10-05').getAttribute('aria-label')!;
    expect(label).not.toContain('Feiertag');
    expect(label).toContain('5.');
  });

  describe('Pointer-Regression (Tap und Drag über [data-date])', () => {
    let selected: Date[];
    let dragged: Date[][];
    let elementFromPoint: ReturnType<typeof vi.fn>;
    let original: typeof document.elementFromPoint | undefined;

    beforeEach(() => {
      selected = [];
      dragged = [];
      // jsdom kennt elementFromPoint nicht -> manuell definieren und danach zurücksetzen
      original = document.elementFromPoint;
      elementFromPoint = vi.fn();
      document.elementFromPoint = elementFromPoint as unknown as typeof document.elementFromPoint;
      fixture.componentInstance.dateSelected.subscribe(d => selected.push(d));
      fixture.componentInstance.dragSelected.subscribe(r => dragged.push(r));
      setBundesland('bayern');
      const card = fixture.nativeElement.querySelector('.calendar-card') as HTMLElement;
      card.setPointerCapture = vi.fn();
      card.releasePointerCapture = vi.fn();
      card.hasPointerCapture = vi.fn().mockReturnValue(false);
    });

    afterEach(() => {
      if (original) document.elementFromPoint = original;
      else delete (document as unknown as Record<string, unknown>)['elementFromPoint'];
    });

    const pointer = (type: string, x: number): PointerEvent =>
      Object.assign(new Event(type, { cancelable: true }), { clientX: x, clientY: 0, pointerId: 1 }) as unknown as PointerEvent;

    it('Tap auf Feiertagszelle wählt den Tag', () => {
      const target = cell('2026-10-03');
      elementFromPoint.mockReturnValue(target.querySelector('.day-number'));
      fixture.componentInstance.onCardPointerDown(pointer('pointerdown', 1));
      fixture.componentInstance.onCardPointerUp(pointer('pointerup', 1));
      expect(selected).toHaveLength(1);
      expect(selected[0].getTime()).toBe(new Date(2026, 9, 3).getTime());
    });

    it('Drag von Feiertag zu Folgetag liefert den Bereich', () => {
      const spy = elementFromPoint;
      spy.mockReturnValue(cell('2026-10-03'));
      fixture.componentInstance.onCardPointerDown(pointer('pointerdown', 1));
      spy.mockReturnValue(cell('2026-10-05'));
      fixture.componentInstance.onCardPointerMove(pointer('pointermove', 2));
      fixture.componentInstance.onCardPointerUp(pointer('pointerup', 2));
      expect(dragged.at(-1)!.map(d => d.getDate())).toEqual([3, 4, 5]);
      expect(selected).toHaveLength(0);
    });
  });
});
