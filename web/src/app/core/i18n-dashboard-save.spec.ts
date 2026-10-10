import de from '../../../public/i18n/de.json';
import en from '../../../public/i18n/en.json';

/** i18n-Parität der Fehlermeldung beim Speichern im Dashboard (#426, Wortlaut wie Mobile `dashboardSaveError`). */
type Dict = Record<string, string>;
const deDash = de.dashboard as unknown as Dict;
const enDash = en.dashboard as unknown as Dict;

describe('i18n dashboard.saveError (#426)', () => {
  it('ist in de und en ein nicht leerer String', () => {
    expect(typeof deDash['saveError']).toBe('string');
    expect(typeof enDash['saveError']).toBe('string');
    expect(deDash['saveError'].trim()).not.toBe('');
    expect(enDash['saveError'].trim()).not.toBe('');
  });

  it('enthält keine Platzhalter', () => {
    expect(deDash['saveError']).not.toMatch(/\{\{/);
    expect(enDash['saveError']).not.toMatch(/\{\{/);
  });

  it('de und en unterscheiden sich (keine unübersetzte Kopie)', () => {
    expect(deDash['saveError']).not.toBe(enDash['saveError']);
  });

  it('es gibt in dashboard keinen zweiten Key mit Präfix saveError', () => {
    expect(Object.keys(deDash).filter(k => k.startsWith('saveError'))).toEqual(['saveError']);
    expect(Object.keys(enDash).filter(k => k.startsWith('saveError'))).toEqual(['saveError']);
  });
});
