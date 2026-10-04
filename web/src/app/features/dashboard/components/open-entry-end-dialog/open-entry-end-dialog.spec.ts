import { TestBed } from '@angular/core/testing';
import { OverlayContainer } from '@angular/cdk/overlay';
import { MatDialog } from '@angular/material/dialog';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { firstValueFrom } from 'rxjs';
import { OpenEntryEndDialogComponent, OpenEntryEndDialogData } from './open-entry-end-dialog';
import { Break, WorkEntry, WorkEntryType } from '../../../../shared/models';
import de from '../../../../../../public/i18n/de.json';
import en from '../../../../../../public/i18n/en.json';

function at(y: number, m: number, d: number, h = 0, min = 0): Date {
  return new Date(y, m - 1, d, h, min);
}

function entry(start: Date, breaks: Break[] = [], id = '2026-10-02'): WorkEntry {
  return { id, date: new Date(Date.UTC(2026, 9, 2)), workStart: start, breaks, isManuallyEntered: false, type: WorkEntryType.Work };
}

describe('OpenEntryEndDialogComponent (#385)', () => {
  let overlay: HTMLElement;
  let dialog: MatDialog;
  let translate: TranslateService;

  // Nur Microtasks, kein `setTimeout`: im Vollauf steht teils ein fremder Fake-Timer (#392).
  const flush = async (): Promise<void> => {
    for (let i = 0; i < 25; i++) { await Promise.resolve(); TestBed.tick(); }
  };

  beforeEach(() => {
    // Nur Date faken: Timer und Microtasks bleiben echt (Dialog/Overlay brauchen sie).
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date(2026, 9, 3, 9, 0)); // Sa 2026-10-03 09:00
    TestBed.configureTestingModule({
      imports: [NoopAnimationsModule],
      providers: [provideTranslateService({ fallbackLang: 'de' })],
    });
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use('de');
    dialog = TestBed.inject(MatDialog);
    overlay = TestBed.inject(OverlayContainer).getContainerElement();
  });

  afterEach(() => {
    TestBed.resetTestingModule();
    vi.useRealTimers();
  });

  async function openWith(data: OpenEntryEndDialogData) {
    const ref = dialog.open<OpenEntryEndDialogComponent, OpenEntryEndDialogData, Date>(
      OpenEntryEndDialogComponent, { data });
    await flush();
    return ref;
  }

  const q = <T extends HTMLElement>(sel: string): T | null => overlay.querySelector<T>(sel);
  const dateInput = (): HTMLInputElement => q<HTMLInputElement>('input[type="date"]')!;
  const timeInput = (): HTMLInputElement => q<HTMLInputElement>('input[type="time"]')!;
  const buttons = (): HTMLButtonElement[] => Array.from(overlay.querySelectorAll('button'));
  const button = (text: string): HTMLButtonElement | undefined => buttons().find(b => b.textContent!.includes(text));
  const confirm = (): HTMLButtonElement => button('Eintrag beenden')!;

  async function type(input: HTMLInputElement, value: string): Promise<void> {
    input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    await flush();
  }

  // Start Fr 10:00, Soll 8 h -> Soll-Ende 18:00; jetzt Sa 09:00 = 23 h alt -> "Jetzt" erlaubt
  const standard = (): OpenEntryEndDialogData => ({ entry: entry(at(2026, 10, 2, 10, 0)), targetMs: 8 * 3600000 });

  it('zeigt Titel und Text mit dem lokalisierten Tag, Vorbelegung = Soll-Ende', async () => {
    await openWith(standard());
    expect(overlay.textContent).toContain('Ende des Eintrags festlegen');
    expect(overlay.textContent).toMatch(/Wann hast du am Fr\.?,? 2\.\s*10\.? aufgehört\?/);
    expect(dateInput().value).toBe('2026-10-02');
    expect(timeInput().value).toBe('18:00');
    expect(button('Soll-Ende (18:00)')).toBeTruthy();
    expect(confirm().disabled).toBe(false);
  });

  it('englische Variante', async () => {
    translate.use('en');
    await openWith(standard());
    expect(overlay.textContent).toContain('Set the end of the entry');
    expect(overlay.textContent).toContain('When did you stop on Fri');
    expect(button('End entry')).toBeTruthy();
    expect(button('Cancel')).toBeTruthy();
    expect(button('Now')).toBeTruthy();
  });

  it('„Jetzt" nur bei Alter <= 24 h', async () => {
    await openWith(standard());
    expect(button('Jetzt')).toBeTruthy();
  });

  it('„Jetzt" fehlt bei einem Eintrag, der älter als 24 h ist (Soll-Ende bleibt)', async () => {
    await openWith({ entry: entry(at(2026, 10, 2, 8, 0)), targetMs: 8 * 3600000 }); // 25 h alt
    expect(button('Jetzt')).toBeUndefined();
    expect(button('Soll-Ende (16:00)')).toBeTruthy();
  });

  it('Vorschlags-Buttons setzen Datum und Zeit', async () => {
    await openWith(standard());
    button('Jetzt')!.click();
    await flush();
    expect(dateInput().value).toBe('2026-10-03');
    expect(timeInput().value).toBe('09:00');
    button('Soll-Ende (18:00)')!.click();
    await flush();
    expect(dateInput().value).toBe('2026-10-02');
    expect(timeInput().value).toBe('18:00');
  });

  it('ohne Vorschlag (Soll 0, älter als 24 h): leere Zeit, Pflichtfeld-Hinweis, Bestätigen gesperrt', async () => {
    await openWith({ entry: entry(at(2026, 10, 1, 8, 0), [], '2026-10-01'), targetMs: 0 });
    expect(timeInput().value).toBe('');
    expect(dateInput().value).toBe('2026-10-01');
    expect(button('Jetzt')).toBeUndefined();
    expect(overlay.textContent).toContain('Bitte wähle eine Uhrzeit.');
    expect(confirm().disabled).toBe(true);
    await type(timeInput(), '17:00');
    expect(confirm().disabled).toBe(false);
    expect(overlay.textContent).not.toContain('Bitte wähle eine Uhrzeit.');
  });

  it('das Datumsfeld hat min = Starttag und max = heute', async () => {
    await openWith(standard());
    expect(dateInput().min).toBe('2026-10-02');
    expect(dateInput().max).toBe('2026-10-03');
  });

  describe('Validierung', () => {
    it.each([
      ['Ende gleich Start', '2026-10-02', '10:00'],
      ['Ende vor Start', '2026-10-02', '09:00'],
      ['Ende nach jetzt', '2026-10-03', '09:01'],
    ])('%s: Fehlertext mit role="alert", Bestätigen gesperrt', async (_l, date, time) => {
      await openWith(standard());
      await type(dateInput(), date);
      await type(timeInput(), time);
      const alert = q('[role="alert"]')!;
      expect(alert.textContent).toContain('Das Ende muss nach dem Start und vor jetzt liegen.');
      expect(alert.querySelector('mat-icon')).toBeTruthy();
      expect(confirm().disabled).toBe(true);
    });

    it('Ende vor dem Ende einer geschlossenen Pause ist ungültig, = Pausenende gültig', async () => {
      const e = entry(at(2026, 10, 2, 8, 0), [
        { id: 'b', name: 'Pause', start: at(2026, 10, 2, 12, 0), end: at(2026, 10, 2, 12, 30), isAutomatic: false },
      ]);
      await openWith({ entry: e, targetMs: 8 * 3600000 });
      await type(timeInput(), '12:10');
      expect(q('[role="alert"]')).not.toBeNull();
      expect(confirm().disabled).toBe(true);
      await type(timeInput(), '12:30');
      expect(q('[role="alert"]')).toBeNull();
      expect(confirm().disabled).toBe(false);
    });

    it('Datum über Mitternacht (Ende am Folgetag) ist gültig und wird als lokales Date geliefert', async () => {
      const ref = await openWith({ entry: entry(at(2026, 10, 2, 22, 0)), targetMs: 8 * 3600000 });
      await type(dateInput(), '2026-10-03');
      await type(timeInput(), '02:00');
      expect(q('[role="alert"]')).toBeNull();
      const closed = firstValueFrom(ref.afterClosed());
      confirm().click();
      expect(await closed).toEqual(at(2026, 10, 3, 2, 0));
    });

    it('Hinweis ab 16 h Netto mit role="status" blockiert nicht', async () => {
      await openWith(standard());
      await type(dateInput(), '2026-10-03');
      await type(timeInput(), '08:00'); // 22 h brutto
      const status = q('.end-warning')!;
      expect(status.getAttribute('role')).toBe('status');
      expect(status.textContent).toContain('mehr als 16 Stunden');
      expect(confirm().disabled).toBe(false);
    });

    it('kein Hinweis bei kurzer Dauer', async () => {
      await openWith(standard());
      expect(q('.end-warning')).toBeNull();
    });

    it('prüft beim Bestätigen mit frischer Uhr: war gültig, ist jetzt nicht mehr -> schließt nicht, zeigt Fehler', async () => {
      const ref = await openWith(standard());
      await type(dateInput(), '2026-10-03');
      await type(timeInput(), '09:00');
      expect(confirm().disabled).toBe(false);
      vi.setSystemTime(new Date(2026, 9, 3, 8, 30)); // Uhr springt zurück
      const closeSpy = vi.fn();
      ref.afterClosed().subscribe(closeSpy);
      confirm().click();
      await flush();
      expect(closeSpy).not.toHaveBeenCalled();
      expect(q('[role="alert"]')).not.toBeNull();
    });
  });

  describe('Ergebnis', () => {
    it('Bestätigen liefert das lokale Date (Minuten)', async () => {
      const ref = await openWith(standard());
      const closed = firstValueFrom(ref.afterClosed());
      confirm().click();
      expect(await closed).toEqual(at(2026, 10, 2, 18, 0));
    });

    it('Abbrechen liefert undefined', async () => {
      const ref = await openWith(standard());
      const closed = firstValueFrom(ref.afterClosed());
      button('Abbrechen')!.click();
      expect(await closed).toBeUndefined();
    });

    it('Esc liefert undefined', async () => {
      const ref = await openWith(standard());
      const closed = firstValueFrom(ref.afterClosed());
      q('mat-dialog-container')!.dispatchEvent(
        new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, bubbles: true }));
      expect(await closed).toBeUndefined();
    });
  });

  it('Dialog-Semantik: role, aria-labelledby auf den Titel, Initialfokus am Zeitfeld', async () => {
    await openWith(standard());
    const container = q('mat-dialog-container')!;
    expect(container.getAttribute('role')).toBe('dialog');
    const labelId = container.getAttribute('aria-labelledby')!;
    expect(q(`#${labelId}`)!.textContent).toContain('Ende des Eintrags festlegen');
    // jsdom kennt kein Layout: geprüft wird die Markierung des Initialfokus (Material fokussiert `cdkFocusInitial`)
    expect(timeInput().hasAttribute('cdkfocusinitial')).toBe(true);
  });

  it('die Felder haben sichtbare Beschriftungen', async () => {
    await openWith(standard());
    expect(overlay.textContent).toContain('Datum');
    expect(overlay.textContent).toContain('Uhrzeit');
  });
});
