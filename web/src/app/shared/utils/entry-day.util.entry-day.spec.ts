import { entryDay, entryDayKey } from './entry-day.util';

/**
 * Zonenunabhängig (#407, Block B): `date` wird hier nur über lokale Konstruktoren gebaut und über lokale Felder gelesen.
 * Inkonsistente Einträge (`id` meint einen anderen Tag als `date`) simulieren eine Lesegrenze, die den Vortag geliefert hat.
 */
const fields = (d: Date) => [d.getFullYear(), d.getMonth() + 1, d.getDate(), d.getHours(), d.getMinutes()];

describe('entryDay', () => {
  it('gültige id und abweichendes date: die id gewinnt', () => {
    const e = { id: '2026-10-05', date: new Date(2026, 9, 4) };
    expect(fields(entryDay(e))).toEqual([2026, 10, 5, 0, 0]);
  });

  it('gültige id und passendes date: lokale Mitternacht', () => {
    expect(fields(entryDay({ id: '2026-10-05', date: new Date(2026, 9, 5) }))).toEqual([2026, 10, 5, 0, 0]);
  });

  it('die Uhrzeit in date wird bei gültiger id verworfen', () => {
    expect(fields(entryDay({ id: '2026-10-05', date: new Date(2026, 9, 5, 23, 30) }))).toEqual([2026, 10, 5, 0, 0]);
  });

  it.each(['x', '1', '2026-3-2', '2026-13-45', '2026-02-30', '2026-10-05T00:00:00.000Z', '', crypto.randomUUID()])(
    'ungültige id %j: lokale Felder von date',
    id => {
      expect(fields(entryDay({ id, date: new Date(2026, 9, 5) }))).toEqual([2026, 10, 5, 0, 0]);
    },
  );

  it('ungültige id: die Uhrzeit in date wird verworfen (lokal 23:30 bleibt am selben Tag)', () => {
    expect(fields(entryDay({ id: 'x', date: new Date(2026, 9, 5, 23, 30) }))).toEqual([2026, 10, 5, 0, 0]);
  });

  it('liefert ein neues Objekt und verändert den Eintrag nicht', () => {
    const date = new Date(2026, 9, 5, 12, 0);
    const before = date.getTime();
    const day = entryDay({ id: 'x', date });
    expect(day).not.toBe(date);
    expect(date.getTime()).toBe(before);
    const byId = entryDay({ id: '2026-10-05', date });
    expect(byId).not.toBe(date);
  });

  it('Monats- und Jahresgrenze aus der id', () => {
    expect(fields(entryDay({ id: '2026-11-01', date: new Date(2026, 9, 31) }))).toEqual([2026, 11, 1, 0, 0]);
    expect(fields(entryDay({ id: '2026-01-01', date: new Date(2025, 11, 31) }))).toEqual([2026, 1, 1, 0, 0]);
  });
});

describe('entryDayKey', () => {
  it('Nullauffüllung', () => {
    expect(entryDayKey({ id: '2026-03-02', date: new Date(2026, 2, 2) })).toBe('2026-03-02');
  });

  it('gültige id und abweichendes date: Schlüssel der id', () => {
    expect(entryDayKey({ id: '2026-10-05', date: new Date(2026, 9, 4) })).toBe('2026-10-05');
    expect(entryDayKey({ id: '2026-11-01', date: new Date(2026, 9, 31) })).toBe('2026-11-01');
    expect(entryDayKey({ id: '2026-01-01', date: new Date(2025, 11, 31) })).toBe('2026-01-01');
  });

  it.each(['x', '1', '2026-3-2'])('ungültige id %j: Schlüssel aus den lokalen Feldern von date', id => {
    expect(entryDayKey({ id, date: new Date(2026, 9, 5, 23, 30) })).toBe('2026-10-05');
  });
});
