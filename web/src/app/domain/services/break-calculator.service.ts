import { Break, WorkEntry, WorkEntryType } from '../../shared/models';

export interface BreakComplianceResult {
  isCompliant: boolean;
  requiredBreakMs: number;
  actualBreakMs: number;
  missingBreakMs: number;
}

// Schwellwerte identisch zu Flutter BreakCalculatorService
const MIN_WORK_MS_FIRST_BREAK  = 6 * 60 * 60 * 1000;  // 6h
const MIN_WORK_MS_SECOND_BREAK = 9 * 60 * 60 * 1000;  // 9h
const FIRST_BREAK_MS  = 30 * 60 * 1000;  // 30 Min
const SECOND_BREAK_MS = 15 * 60 * 1000;  // 15 Min
const REQUIRED_LONG_DAY_MS = 45 * 60 * 1000; // 45 Min gesamt

function totalBreakMs(breaks: Break[]): number {
  return breaks.reduce((sum, b) => {
    if (!b.end) return sum;
    return sum + (b.end.getTime() - b.start.getTime());
  }, 0);
}

function effectiveWorkMs(entry: WorkEntry): number {
  if (!entry.workStart || !entry.workEnd) return 0;
  const gross = entry.workEnd.getTime() - entry.workStart.getTime();
  return Math.max(0, gross - totalBreakMs(entry.breaks));
}

export function validateBreakCompliance(entry: WorkEntry): BreakComplianceResult {
  const actual = totalBreakMs(entry.breaks);
  const netWork = effectiveWorkMs(entry);
  let required = 0;
  if (netWork >= MIN_WORK_MS_SECOND_BREAK) required = REQUIRED_LONG_DAY_MS;
  else if (netWork >= MIN_WORK_MS_FIRST_BREAK) required = FIRST_BREAK_MS;

  const missing = Math.max(0, required - actual);
  return { isCompliant: missing === 0, requiredBreakMs: required, actualBreakMs: actual, missingBreakMs: missing };
}

export function calculateAndApplyBreaks(entry: WorkEntry): WorkEntry {
  if (!entry.workStart || !entry.workEnd) return entry;

  const totalWork = entry.workEnd.getTime() - entry.workStart.getTime();
  const existing = entry.breaks;

  if (existing.length === 0) {
    return { ...entry, breaks: _calculateBreaks(entry.workStart, entry.workEnd, totalWork) };
  }
  return { ...entry, breaks: _adjustExistingBreaks(entry.workStart, entry.workEnd, totalWork, existing) };
}

function _calculateBreaks(workStart: Date, workEnd: Date, totalWorkMs: number): Break[] {
  const breaks: Break[] = [];

  if (totalWorkMs >= MIN_WORK_MS_SECOND_BREAK) {
    // 30 Min Mittagspause nach 4h
    const s1 = new Date(workStart.getTime() + 4 * 60 * 60 * 1000);
    const e1 = new Date(s1.getTime() + FIRST_BREAK_MS);
    if (e1 < workEnd) {
      breaks.push({ id: crypto.randomUUID(), name: 'Mittagspause', start: s1, end: e1, isAutomatic: true });
      // 15 Min Kurzpause 2h später
      const s2 = new Date(e1.getTime() + 2 * 60 * 60 * 1000);
      const e2 = new Date(s2.getTime() + SECOND_BREAK_MS);
      if (e2 < workEnd) {
        breaks.push({ id: crypto.randomUUID(), name: 'Kurzpause', start: s2, end: e2, isAutomatic: true });
      }
    }
  } else if (totalWorkMs >= MIN_WORK_MS_FIRST_BREAK) {
    const s = new Date(workStart.getTime() + 4 * 60 * 60 * 1000);
    const e = new Date(s.getTime() + FIRST_BREAK_MS);
    if (e < workEnd) {
      breaks.push({ id: crypto.randomUUID(), name: 'Mittagspause', start: s, end: e, isAutomatic: true });
    }
  }
  return breaks;
}

function _adjustExistingBreaks(workStart: Date, workEnd: Date, totalWorkMs: number, existing: Break[]): Break[] {
  const manualBreaks = existing.filter(b => !b.isAutomatic);
  let required = 0;
  if (totalWorkMs >= MIN_WORK_MS_SECOND_BREAK) required = REQUIRED_LONG_DAY_MS;
  else if (totalWorkMs >= MIN_WORK_MS_FIRST_BREAK) required = FIRST_BREAK_MS;

  const actual = totalBreakMs(existing);
  if (actual >= required) return existing;

  const missing = required - actual;
  const result = [...manualBreaks];

  const lastEnd = existing.filter(b => b.end).sort((a, b) => b.end!.getTime() - a.end!.getTime())[0]?.end;
  const autoStart = lastEnd
    ? new Date(lastEnd.getTime() + 60 * 60 * 1000)
    : new Date(workStart.getTime() + 4 * 60 * 60 * 1000);
  const autoEnd = new Date(autoStart.getTime() + missing);

  if (autoEnd < workEnd) {
    result.push({ id: crypto.randomUUID(), name: 'Automatische Pause', start: autoStart, end: autoEnd, isAutomatic: true });
  }
  return result;
}
