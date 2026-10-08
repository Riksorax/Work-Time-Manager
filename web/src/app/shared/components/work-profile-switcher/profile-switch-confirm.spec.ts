import { TestBed } from '@angular/core/testing';
import { OverlayContainer } from '@angular/cdk/overlay';
import { signal } from '@angular/core';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import { TranslateService, provideTranslateService } from '@ngx-translate/core';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ProfileSwitchConfirmService } from './profile-switch-confirm';
import { WorkProfileService } from '../../../core/services/work-profile';
import de from '../../../../../public/i18n/de.json';
import en from '../../../../../public/i18n/en.json';

const NEW_KEYS = ['switchWhileRunningTitle', 'switchWhileRunningText', 'stopAndSwitchButton', 'switchSaveFailed'];

describe('ProfileSwitchConfirmService (#380)', () => {
  let svc: ProfileSwitchConfirmService;
  let translate: TranslateService;
  let overlay: HTMLElement;

  const flush = async (): Promise<void> => {
    // Nur Microtasks, kein `setTimeout`: im Vollauf steht dort teils ein fremder Fake-Timer (Ursache offen, #392).
    for (let i = 0; i < 20; i++) { await Promise.resolve(); TestBed.tick(); }
  };
  const buttons = (): HTMLButtonElement[] => Array.from(overlay.querySelectorAll('button'));
  const button = (text: string): HTMLButtonElement =>
    buttons().find(b => b.textContent!.includes(text))!;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [NoopAnimationsModule],
      providers: [
        provideTranslateService({ fallbackLang: 'de' }),
        { provide: WorkProfileService, useValue: {
          profiles: signal([{ id: 'default', name: 'Standard' }, { id: 'B', name: 'Firma B' }]) } },
      ],
    });
    translate = TestBed.inject(TranslateService);
    translate.setTranslation('de', de);
    translate.setTranslation('en', en);
    translate.use('de');
    svc = TestBed.inject(ProfileSwitchConfirmService);
    overlay = TestBed.inject(OverlayContainer).getContainerElement();
  });

  afterEach(() => TestBed.resetTestingModule());

  it('zeigt Titel, Profilnamen (nicht IDs) und beide Buttons auf Deutsch', async () => {
    const p = svc.confirmStopAndSwitch({ from: 'default', to: 'B' });
    await flush();
    expect(overlay.textContent).toContain('Zeiterfassung läuft');
    expect(overlay.textContent).toContain('Im Profil "Standard" läuft noch eine Zeiterfassung');
    expect(overlay.textContent).toContain('in das Profil "Firma B" wechselst');
    expect(button('Abbrechen')).toBeTruthy();
    expect(button('Beenden und wechseln')).toBeTruthy();
    button('Abbrechen').click();
    await p;
  });

  it('zeigt die englische Variante', async () => {
    translate.use('en');
    const p = svc.confirmStopAndSwitch({ from: 'default', to: 'B' });
    await flush();
    expect(overlay.textContent).toContain('Time tracking is running');
    expect(overlay.textContent).toContain('profile "Standard"');
    expect(button('Stop and switch')).toBeTruthy();
    expect(button('Cancel')).toBeTruthy();
    button('Cancel').click();
    await p;
  });

  it('„Beenden und wechseln" liefert true', async () => {
    const p = svc.confirmStopAndSwitch({ from: 'default', to: 'B' });
    await flush();
    button('Beenden und wechseln').click();
    expect(await p).toBe(true);
  });

  it('„Abbrechen" liefert false', async () => {
    const p = svc.confirmStopAndSwitch({ from: 'default', to: 'B' });
    await flush();
    button('Abbrechen').click();
    expect(await p).toBe(false);
  });

  it('Esc liefert false', async () => {
    const p = svc.confirmStopAndSwitch({ from: 'default', to: 'B' });
    await flush();
    overlay.querySelector('mat-dialog-container')!.dispatchEvent(
      new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', keyCode: 27, bubbles: true }));
    expect(await p).toBe(false);
  });

  it('Backdrop-Klick liefert false', async () => {
    const p = svc.confirmStopAndSwitch({ from: 'default', to: 'B' });
    await flush();
    (overlay.querySelector('.cdk-overlay-backdrop') as HTMLElement).click();
    expect(await p).toBe(false);
  });

  it('Fokus liegt initial auf „Abbrechen"; Dialog hat role und aria-labelledby auf den Titel', async () => {
    const p = svc.confirmStopAndSwitch({ from: 'default', to: 'B' });
    await flush();
    // jsdom kennt kein Layout (alle Elemente „unsichtbar"), der echte Fokus-Trap fokussiert dort nicht zuverlässig:
    // geprüft wird daher, dass NUR „Abbrechen" als Initialfokus markiert ist (Material fokussiert `cdkFocusInitial`).
    expect(button('Abbrechen').hasAttribute('cdkfocusinitial')).toBe(true);
    expect(button('Beenden und wechseln').hasAttribute('cdkfocusinitial')).toBe(false);
    const container = overlay.querySelector('mat-dialog-container')!;
    expect(container.getAttribute('role')).toBe('dialog');
    const labelId = container.getAttribute('aria-labelledby')!;
    expect(labelId).toBeTruthy();
    expect(overlay.querySelector(`#${labelId}`)!.textContent).toContain('Zeiterfassung läuft');
    button('Abbrechen').click();
    await p;
  });

  it('unbekannte Profil-ID fällt auf die ID zurück, ohne zu werfen', async () => {
    const p = svc.confirmStopAndSwitch({ from: 'gone', to: 'B' });
    await flush();
    expect(overlay.textContent).toContain('Im Profil "gone"');
    button('Abbrechen').click();
    expect(await p).toBe(false);
  });

  it('neues Profil (to = null): zeigt den geplanten Namen', async () => {
    const p = svc.confirmStopAndSwitch({ from: 'default', to: null, toName: 'Neu' });
    await flush();
    expect(overlay.textContent).toContain('in das Profil "Neu" wechselst');
    button('Abbrechen').click();
    await p;
  });

  it('notifySaveFailed öffnet eine Snackbar mit dem übersetzten Text', () => {
    const open = vi.spyOn(TestBed.inject(MatSnackBar), 'open');
    svc.notifySaveFailed();
    expect(open).toHaveBeenCalledWith(
      'Wechsel abgebrochen: Die Zeiterfassung konnte nicht gespeichert werden.', 'OK', { duration: 5000 });
  });

  it('i18n-Parität: die neuen shared-Keys existieren in de und en und sind nicht leer', () => {
    const d = de.shared as Record<string, string>;
    const e = en.shared as Record<string, string>;
    for (const k of NEW_KEYS) {
      expect(d[k]?.length).toBeGreaterThan(0);
      expect(e[k]?.length).toBeGreaterThan(0);
    }
    expect(Object.keys(d).sort()).toEqual(Object.keys(e).sort());
  });
});
