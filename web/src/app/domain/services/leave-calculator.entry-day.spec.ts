import { calculateYearlyLeave } from './leave-calculator';
import { WorkEntry, WorkEntryType } from '../../shared/models/index';

/**
 * Zonenunabhängig (#407, Block B): die Jahresgrenze beim Urlaub richtet sich nach dem Kalendertag aus der `id`.
 * Fixture: `id` 2026-01-01, `date` 2025-12-31 (wie nach einer Lesegrenze, die den Vortag geliefert hat).
 */
describe('calculateYearlyLeave: Jahr aus der id (#407)', () => {
  const vacation = (id: string, date: Date): WorkEntry => ({
    id, date, breaks: [], isManuallyEntered: true, type: WorkEntryType.Vacation,
  });

  it('id 2026-01-01 mit date 2025-12-31 zählt für 2026', () => {
    const e = vacation('2026-01-01', new Date(2025, 11, 31));
    expect(calculateYearlyLeave([e], 2026, 30).vacationDaysTaken).toBe(1);
  });

  it('id 2026-01-01 mit date 2025-12-31 zählt nicht für 2025', () => {
    const e = vacation('2026-01-01', new Date(2025, 11, 31));
    expect(calculateYearlyLeave([e], 2025, 30).vacationDaysTaken).toBe(0);
  });

  it('Krankheitstag am Jahresende: id 2025-12-31 zählt für 2025', () => {
    const e: WorkEntry = { ...vacation('2025-12-31', new Date(2026, 0, 1)), type: WorkEntryType.Sick };
    expect(calculateYearlyLeave([e], 2025, 30).sickDays).toBe(1);
    expect(calculateYearlyLeave([e], 2026, 30).sickDays).toBe(0);
  });
});
