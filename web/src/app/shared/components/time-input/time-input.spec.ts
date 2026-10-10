import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideTranslateService } from '@ngx-translate/core';
import { TimeInputComponent } from './time-input';

// Der Clear-Button (X) im Zeitfeld folgt dem `disabled`-Input (#426): während einer Schreibaktion im Dashboard darf
// „Endzeit löschen“ nicht bedienbar sein.
describe('TimeInputComponent Clear-Button (#426)', () => {
  let fixture: ComponentFixture<TimeInputComponent>;

  const clearButton = (): HTMLButtonElement => fixture.nativeElement.querySelector('button[matSuffix]') as HTMLButtonElement;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideTranslateService()] });
    fixture = TestBed.createComponent(TimeInputComponent);
    fixture.componentRef.setInput('label', 'Ende');
    fixture.componentRef.setInput('showClear', true);
    fixture.componentRef.setInput('value', new Date(2026, 9, 5, 12, 0));
    fixture.detectChanges();
  });

  it('ist aktiv und löst cleared aus, solange das Feld nicht deaktiviert ist', () => {
    const cleared = vi.fn();
    fixture.componentInstance.cleared.subscribe(cleared);
    expect(clearButton().disabled).toBe(false);
    clearButton().click();
    expect(cleared).toHaveBeenCalledTimes(1);
  });

  it('ist deaktiviert und löst nichts aus, wenn das Feld deaktiviert ist', () => {
    fixture.componentRef.setInput('disabled', true);
    fixture.detectChanges();
    const cleared = vi.fn();
    fixture.componentInstance.cleared.subscribe(cleared);
    expect(clearButton().disabled).toBe(true);
    clearButton().click();
    expect(cleared).not.toHaveBeenCalled();
  });

  it('wird nach dem Aufheben der Deaktivierung wieder aktiv', () => {
    fixture.componentRef.setInput('disabled', true);
    fixture.detectChanges();
    fixture.componentRef.setInput('disabled', false);
    fixture.detectChanges();
    expect(clearButton().disabled).toBe(false);
  });
});

// Entprellen + Flush beim Verlassen (Opt-in `settle`, Review-Fund zu #426): Das `change`-Event eines `<input type="time">`
// feuert in Chromium nach jeder gültigen Teiländerung (Tastatur „0930“: 09:00, 09:03, 09:30). Im Dashboard würde schon das
// erste Event einen Write starten und das Feld sperren. Festlegung (hier und in web/CLAUDE.md):
//  - Ohne `settle` (Default, Pausen-Dialog): jedes change wird sofort ausgegeben, wie bisher.
//  - Mit `settle`: letzter Wert gewinnt; Ausgabe nach 600 ms Ruhe ODER sofort beim Blur, je getipptem Wert genau einmal.
//  - Nie ein getippter Wert still verworfen, solange das Feld lebt: Läuft die Ruhezeit ab, während das Feld gesperrt ist,
//    bleibt der Wert vorgemerkt und wird beim Entsperren gesendet (blur kommt von einem gesperrten Feld nicht).
//  - Beim Zerstören der Komponente wird der Timer verworfen und nichts mehr ausgegeben.
describe('TimeInputComponent Entprellen (settle)', () => {
  let fixture: ComponentFixture<TimeInputComponent>;
  let emitted: string[];

  const input = (): HTMLInputElement => fixture.nativeElement.querySelector('input') as HTMLInputElement;
  const type = (value: string): void => {
    input().value = value;
    input().dispatchEvent(new Event('change'));
  };
  const blur = (): void => { input().dispatchEvent(new Event('blur')); };
  const setup = async (settle: boolean | undefined): Promise<void> => {
    TestBed.configureTestingModule({ providers: [provideTranslateService()] });
    fixture = TestBed.createComponent(TimeInputComponent);
    fixture.componentRef.setInput('label', 'Start');
    if (settle !== undefined) fixture.componentRef.setInput('settle', settle);
    fixture.detectChanges();
    // Einmalige Timer von Angular/Material ablaufen lassen, damit `vi.getTimerCount()` nur noch Timer der Komponente zählt.
    await vi.advanceTimersByTimeAsync(10_000);
    emitted = [];
    fixture.componentInstance.timeSelected.subscribe(v => emitted.push(v));
  };

  beforeEach(() => { vi.useFakeTimers(); });
  afterEach(() => {
    fixture.destroy();
    vi.useRealTimers();
    TestBed.resetTestingModule();
  });

  describe('ohne Opt-in (Default, Pausen-Dialog)', () => {
    beforeEach(async () => { await setup(undefined); });

    it('hat settle standardmäßig aus', () => {
      expect(fixture.componentInstance.settle()).toBe(false);
    });

    it('gibt jedes change sofort aus, ohne Timer', () => {
      type('09:00');
      type('09:03');
      type('09:30');
      expect(emitted).toEqual(['09:00', '09:03', '09:30']);
      expect(vi.getTimerCount()).toBe(0);
    });

    it('ignoriert leere Werte und gibt bei blur nichts aus', () => {
      type('');
      blur();
      expect(emitted).toEqual([]);
    });
  });

  describe('mit Opt-in', () => {
    beforeEach(async () => { await setup(true); });

    it('fasst drei schnelle Änderungen zu genau einem Emit mit dem letzten Wert nach der Ruhezeit zusammen', async () => {
      type('09:00');
      await vi.advanceTimersByTimeAsync(200);
      type('09:03');
      await vi.advanceTimersByTimeAsync(200);
      type('09:30');
      await vi.advanceTimersByTimeAsync(599);
      expect(emitted).toEqual([]);
      await vi.advanceTimersByTimeAsync(1);
      expect(emitted).toEqual(['09:30']);
      expect(vi.getTimerCount()).toBe(0);
    });

    it('die Ruhezeit beginnt mit jeder Änderung neu (nicht erst ab der ersten)', async () => {
      type('09:00');
      await vi.advanceTimersByTimeAsync(500);
      type('09:03');
      await vi.advanceTimersByTimeAsync(500);
      expect(emitted).toEqual([]);
      await vi.advanceTimersByTimeAsync(100);
      expect(emitted).toEqual(['09:03']);
    });

    it('gibt vor Ablauf der Ruhezeit nichts aus', async () => {
      type('09:30');
      await vi.advanceTimersByTimeAsync(300);
      expect(emitted).toEqual([]);
    });

    it('blur vor Ablauf gibt sofort einmal aus, der abgelaufene Timer sendet nicht ein zweites Mal', async () => {
      type('09:30');
      blur();
      expect(emitted).toEqual(['09:30']);
      expect(vi.getTimerCount()).toBe(0);
      await vi.advanceTimersByTimeAsync(5000);
      expect(emitted).toEqual(['09:30']);
    });

    it('blur nach dem Entprell-Emit sendet nicht noch einmal', async () => {
      type('09:30');
      await vi.advanceTimersByTimeAsync(600);
      blur();
      expect(emitted).toEqual(['09:30']);
    });

    it('blur ohne Änderung gibt nichts aus', () => {
      blur();
      expect(emitted).toEqual([]);
    });

    it('ein neuer Wert nach einem Emit wird wieder ausgegeben', async () => {
      type('09:30');
      await vi.advanceTimersByTimeAsync(600);
      type('10:15');
      blur();
      expect(emitted).toEqual(['09:30', '10:15']);
    });

    it('der gleiche Wert nach einem Emit wird erneut ausgegeben (Nutzer tippt bewusst neu)', async () => {
      type('09:30');
      await vi.advanceTimersByTimeAsync(600);
      type('09:30');
      blur();
      expect(emitted).toEqual(['09:30', '09:30']);
    });

    it('leerer Wert (Feld teilweise gelöscht) startet keinen Timer und ersetzt den vorgemerkten Wert nicht', async () => {
      type('09:30');
      type('');
      await vi.advanceTimersByTimeAsync(600);
      expect(emitted).toEqual(['09:30']);
    });

    it('Destroy mit offenem Timer: kein Emit, kein Timer-Leak', async () => {
      type('09:30');
      expect(vi.getTimerCount()).toBe(1);
      fixture.destroy();
      expect(vi.getTimerCount()).toBe(0);
      await vi.advanceTimersByTimeAsync(5000);
      expect(emitted).toEqual([]);
    });

    describe('Sperre (disabled) während der Ruhezeit', () => {
      const setDisabled = (v: boolean): void => {
        fixture.componentRef.setInput('disabled', v);
        fixture.detectChanges();
      };

      it('läuft die Ruhezeit im gesperrten Zustand ab, wird nicht gesendet, der Wert aber behalten und beim Entsperren gesendet', async () => {
        type('09:30');
        setDisabled(true);
        await vi.advanceTimersByTimeAsync(600);
        expect(emitted).toEqual([]);
        expect(vi.getTimerCount()).toBe(0);
        setDisabled(false);
        expect(emitted).toEqual(['09:30']);
        setDisabled(true);
        setDisabled(false);
        expect(emitted).toEqual(['09:30']);
      });

      it('Entsperren vor Ablauf der Ruhezeit lässt den Timer laufen (kein Vorziehen)', async () => {
        type('09:30');
        setDisabled(true);
        await vi.advanceTimersByTimeAsync(300);
        setDisabled(false);
        expect(emitted).toEqual([]);
        await vi.advanceTimersByTimeAsync(300);
        expect(emitted).toEqual(['09:30']);
      });

      it('blur im gesperrten Zustand sendet nicht, der Wert bleibt vorgemerkt', () => {
        type('09:30');
        setDisabled(true);
        blur();
        expect(emitted).toEqual([]);
        setDisabled(false);
        expect(emitted).toEqual(['09:30']);
      });
    });
  });
});
