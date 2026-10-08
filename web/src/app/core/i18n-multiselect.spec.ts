import de from '../../../public/i18n/de.json';
import en from '../../../public/i18n/en.json';

/** i18n-Parität der Texte für die Mehrfachauswahl per Tastatur (#377). */
type Dict = Record<string, Record<string, string>>;
const KEYS: readonly [string, string, string[]][] = [
  ['reports', 'multiSelectButton', []],
  ['reports', 'multiSelectTooltip', []],
  ['shared', 'calendarMultiSelectOnAria', []],
  ['shared', 'calendarMultiSelectOffAria', []],
  ['shared', 'calendarSelectedCountAria', ['count']],
];

const placeholders = (text: string): string[] =>
  [...text.matchAll(/\{\{\s*(\w+)\s*\}\}/g)].map(m => m[1]).sort();

describe('i18n Mehrfachauswahl (#377)', () => {
  it.each(KEYS)('%s.%s ist in de und en vorhanden, nicht leer und hat dieselben Platzhalter', (ns, key, expected) => {
    const d = (de as unknown as Dict)[ns]?.[key];
    const e = (en as unknown as Dict)[ns]?.[key];
    expect(typeof d, `de ${ns}.${key}`).toBe('string');
    expect(typeof e, `en ${ns}.${key}`).toBe('string');
    expect(d.trim()).not.toBe('');
    expect(e.trim()).not.toBe('');
    expect(placeholders(d)).toEqual(expected);
    expect(placeholders(e)).toEqual(expected);
  });
});
