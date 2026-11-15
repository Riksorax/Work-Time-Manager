import { TestBed } from '@angular/core/testing';
import { WorkLocationHistoryService } from './work-location-history';
import { WorkEntryType } from '../../shared/models';

const e = (id: string, locs?: string[], type = WorkEntryType.Work) => {
  const [y, m, d] = id.split('-').map(Number);
  return { id, date: new Date(y, m - 1, d), type, workLocations: locs };
};

describe('WorkLocationHistoryService (#526)', () => {
  beforeEach(() => localStorage.clear());
  afterEach(() => { TestBed.resetTestingModule(); localStorage.clear(); });

  const create = () => { TestBed.resetTestingModule(); return TestBed.inject(WorkLocationHistoryService); };

  it('merkt Orte je Scope, zuletzt verwendete zuerst', () => {
    const svc = create();
    svc.record('u1|default', [e('2026-06-01', ['Alt']), e('2026-06-03', ['Neu'])]);
    expect(svc.suggestions('u1|default', [])).toEqual(['Neu', 'Alt']);
    expect(svc.suggestions('u1|andere', [])).toEqual([]);
  });

  it('überlebt einen Neustart des Dienstes (lokal gespeichert)', () => {
    create().record('u1|default', [e('2026-06-01', ['Büro'])]);
    expect(create().suggestions('u1|default', [])).toEqual(['Büro']);
  });

  it('ein Tag, der später ohne Orte geladen wird, verschwindet', () => {
    const svc = create();
    svc.record('s', [e('2026-06-01', ['Büro'])]);
    svc.record('s', [e('2026-06-01', [])]);
    expect(svc.suggestions('s', [])).toEqual([]);
  });

  it('Nicht-Arbeitstage und Platzhalter-Ids zählen nicht', () => {
    const svc = create();
    svc.record('s', [e('2026-06-01', ['Urlaub'], WorkEntryType.Vacation), { ...e('2026-06-02', ['X']), id: 'x' }]);
    expect(svc.suggestions('s', [])).toEqual([]);
  });

  it('merkt höchstens die letzten 40 Tage', () => {
    const svc = create();
    const days = Array.from({ length: 50 }, (_, i) => e(`2026-${String(1 + Math.floor(i / 28)).padStart(2, '0')}-${String(1 + (i % 28)).padStart(2, '0')}`, [`Ort${i}`]));
    svc.record('s', days);
    const stored = JSON.parse(localStorage.getItem('work_location_history_v1')!) as Record<string, unknown[]>;
    expect(stored['s']).toHaveLength(40);
  });

  it('zusätzliche, schon geladene Einträge fließen in die Vorschläge ein', () => {
    const svc = create();
    expect(svc.suggestions('s', [], [e('2026-06-05', ['Live'])])).toEqual(['Live']);
  });

  it('kaputter Speicher wird ignoriert', () => {
    localStorage.setItem('work_location_history_v1', '{kaputt');
    expect(create().suggestions('s', [])).toEqual([]);
  });
});
