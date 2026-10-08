import { calculateYearlyLeave } from './leave-calculator';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';

function entry(date: Date, type: WorkEntryType): WorkEntry {
  return { id: date.toISOString(), date, breaks: [], isManuallyEntered: true, type };
}

describe('calculateYearlyLeave', () => {
  it('liefert bei leerer Liste 0/0 und reicht Jahr/Anspruch durch', () => {
    expect(calculateYearlyLeave([], 2026, 25)).toEqual({
      year: 2026, vacationDaysPerYear: 25, vacationDaysTaken: 0, vacationDaysRemaining: 25, sickDays: 0,
    });
  });

  it('trennt Jahre an der Silvester-/Neujahrsgrenze', () => {
    const entries = [
      entry(new Date(2025, 11, 31), WorkEntryType.Vacation),
      entry(new Date(2026, 0, 1), WorkEntryType.Vacation),
    ];
    expect(calculateYearlyLeave(entries, 2025, 30).vacationDaysTaken).toBe(1);
    expect(calculateYearlyLeave(entries, 2026, 30).vacationDaysTaken).toBe(1);
    expect(calculateYearlyLeave(entries, 2027, 30).vacationDaysTaken).toBe(0);
  });

  it('zählt nur vacation und sick', () => {
    const entries = [
      entry(new Date(2026, 2, 2), WorkEntryType.Vacation),
      entry(new Date(2026, 2, 3), WorkEntryType.Sick),
      entry(new Date(2026, 2, 4), WorkEntryType.Work),
      entry(new Date(2026, 2, 5), WorkEntryType.Holiday),
    ];
    const r = calculateYearlyLeave(entries, 2026, 30);
    expect(r.vacationDaysTaken).toBe(1);
    expect(r.sickDays).toBe(1);
    expect(r.vacationDaysRemaining).toBe(29);
  });

  it('zählt Wochenend-Einträge', () => {
    const entries = [
      entry(new Date(2026, 2, 7), WorkEntryType.Vacation), // Samstag
      entry(new Date(2026, 2, 8), WorkEntryType.Vacation), // Sonntag
    ];
    expect(calculateYearlyLeave(entries, 2026, 30).vacationDaysTaken).toBe(2);
  });

  it('lässt den Rest negativ werden', () => {
    const entries = [
      entry(new Date(2026, 2, 2), WorkEntryType.Vacation),
      entry(new Date(2026, 2, 3), WorkEntryType.Vacation),
    ];
    expect(calculateYearlyLeave(entries, 2026, 1).vacationDaysRemaining).toBe(-1);
    expect(calculateYearlyLeave(entries, 2026, 0).vacationDaysRemaining).toBe(-2);
  });
});
