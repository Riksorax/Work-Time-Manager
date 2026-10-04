import de from '../../../public/i18n/de.json';
import en from '../../../public/i18n/en.json';

/** i18n-Parität der Texte für offene Einträge vor heute (#385). */
const KEYS = [
  'openEntryBannerTitle',
  'openEntryBannerMoreOne',
  'openEntryBannerMoreOther',
  'openEntryEnd',
  'openEntryLater',
  'openEntryEndDialogTitle',
  'openEntryEndDialogBody',
  'openEntryEndSuggestionExpected',
  'openEntryEndSuggestionNow',
  'openEntryEndDateLabel',
  'openEntryEndTimeLabel',
  'openEntryEndTimeRequired',
  'openEntryEndInvalid',
  'openEntryEndLongWarning',
  'openEntryEndDialogConfirm',
  'openEntrySaveError',
] as const;

const PLACEHOLDERS: Record<string, string[]> = {
  openEntryBannerTitle: ['date', 'time'],
  openEntryBannerMoreOther: ['count'],
  openEntryEndDialogBody: ['date'],
  openEntryEndSuggestionExpected: ['time'],
};

type Dict = Record<string, string>;
const deDash = de.dashboard as unknown as Dict;
const enDash = en.dashboard as unknown as Dict;

function placeholders(text: string): string[] {
  return [...text.matchAll(/\{\{\s*(\w+)\s*\}\}/g)].map(m => m[1]).sort();
}

describe('i18n dashboard.openEntry* (#385)', () => {
  it.each(KEYS)('%s ist in de und en vorhanden und nicht leer', key => {
    expect(typeof deDash[key]).toBe('string');
    expect(typeof enDash[key]).toBe('string');
    expect(deDash[key].trim()).not.toBe('');
    expect(enDash[key].trim()).not.toBe('');
  });

  it.each(KEYS)('%s hat in de und en dieselben Platzhalter', key => {
    expect(placeholders(deDash[key])).toEqual(placeholders(enDash[key]));
    expect(placeholders(deDash[key])).toEqual([...(PLACEHOLDERS[key] ?? [])].sort());
  });

  it('es gibt keine weiteren openEntry*-Keys ohne Gegenstück (kein Fortsetzen, keine Semantics-Keys)', () => {
    const deKeys = Object.keys(deDash).filter(k => k.startsWith('openEntry')).sort();
    const enKeys = Object.keys(enDash).filter(k => k.startsWith('openEntry')).sort();
    expect(deKeys).toEqual([...KEYS].sort());
    expect(enKeys).toEqual([...KEYS].sort());
  });

  it('der Plural liegt als zwei Keys vor (ohne ICU)', () => {
    expect(deDash['openEntryBannerMoreOne']).not.toContain('{{count}}');
    expect(deDash['openEntryBannerMoreOther']).toContain('{{count}}');
    expect(deDash['openEntryBannerMoreOne']).not.toMatch(/plural|select/);
  });

  it('Abbrechen nutzt den vorhandenen Key common.cancel', () => {
    expect((de.common as unknown as Dict)['cancel']).toBeTruthy();
    expect((en.common as unknown as Dict)['cancel']).toBeTruthy();
  });
});
