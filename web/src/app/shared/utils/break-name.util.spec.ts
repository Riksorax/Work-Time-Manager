import { breakNameToStore, localizedBreakName, parseDefaultBreakName } from './break-name.util';

const EN: Record<string, string> = {
  'shared.breakPlainName': 'Break',
  'shared.breakDefaultName': 'Break {{number}}',
  'shared.breakAutomaticName': 'Automatic break',
  'shared.breakLunchName': 'Lunch break',
  'shared.breakShortName': 'Short break',
};

const translateEn = (key: string, params?: Record<string, unknown>): string =>
  (EN[key] ?? key).replace('{{number}}', String(params?.['number']));

describe('break-name.util', () => {
  describe('parseDefaultBreakName', () => {
    it('erkennt die Standardnamen aller Plattformen', () => {
      expect(parseDefaultBreakName('Pause')).toEqual({ kind: 'plain' });
      expect(parseDefaultBreakName('Automatische Pause')).toEqual({ kind: 'automatic' });
      expect(parseDefaultBreakName('Mittagspause')).toEqual({ kind: 'lunch' });
      expect(parseDefaultBreakName('Kurzpause')).toEqual({ kind: 'short' });
    });

    it('erkennt nummerierte Namen mit und ohne Raute sowie die englische Form', () => {
      expect(parseDefaultBreakName('Pause 2')).toEqual({ kind: 'numbered', number: 2 });
      expect(parseDefaultBreakName('Pause #13')).toEqual({ kind: 'numbered', number: 13 });
      expect(parseDefaultBreakName('Break 3')).toEqual({ kind: 'numbered', number: 3 });
    });

    it('lässt frei vergebene Namen unberührt', () => {
      for (const name of ['Kaffee', 'Laufende Pause', 'Pause mit Kollegen', 'Pause 2 lang', 'pause', 'Break', '']) {
        expect(parseDefaultBreakName(name)).toBeNull();
      }
    });
  });

  describe('localizedBreakName', () => {
    it('übersetzt Standardnamen über den übergebenen Übersetzer', () => {
      expect(localizedBreakName('Pause', translateEn)).toBe('Break');
      expect(localizedBreakName('Pause 2', translateEn)).toBe('Break 2');
      expect(localizedBreakName('Pause #3', translateEn)).toBe('Break 3');
      expect(localizedBreakName('Automatische Pause', translateEn)).toBe('Automatic break');
      expect(localizedBreakName('Mittagspause', translateEn)).toBe('Lunch break');
      expect(localizedBreakName('Kurzpause', translateEn)).toBe('Short break');
    });

    it('lässt frei vergebene Namen unverändert', () => {
      expect(localizedBreakName('Kaffee mit Anna', translateEn)).toBe('Kaffee mit Anna');
    });
  });

  describe('breakNameToStore', () => {
    it('behält den Originalnamen, wenn die Anzeige unverändert blieb', () => {
      expect(breakNameToStore('Break 2', 'Pause 2', translateEn)).toBe('Pause 2');
    });

    it('speichert einen vom Nutzer geänderten Namen', () => {
      expect(breakNameToStore('Coffee with Anna', 'Pause 2', translateEn)).toBe('Coffee with Anna');
    });

    it('speichert einen frei vergebenen Namen unverändert', () => {
      expect(breakNameToStore('Kaffee', 'Kaffee', translateEn)).toBe('Kaffee');
    });
  });
});
