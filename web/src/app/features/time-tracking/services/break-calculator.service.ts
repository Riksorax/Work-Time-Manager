import { Injectable } from '@angular/core';
import { Timestamp } from '@angular/fire/firestore';
import { WorkSession, SessionBreak } from '../../../shared/models';

export interface BreakSuggestion {
  requiredMinutes: number;
  currentMinutes: number;
  missingMinutes: number;
  isRequired: boolean;
}

@Injectable({ providedIn: 'root' })
export class BreakCalculatorService {
  // Gesetzliche Pausenregelung (§ 4 ArbZG)
  // ab 6h Arbeitszeit: 30 Minuten Pause
  // ab 9h Arbeitszeit: 45 Minuten Pause

  requiredBreakMinutes(workedMinutes: number): number {
    if (workedMinutes >= 9 * 60) return 45;
    if (workedMinutes >= 6 * 60) return 30;
    return 0;
  }

  getSuggestion(workedMinutes: number, pausedMinutes: number): BreakSuggestion {
    const required = this.requiredBreakMinutes(workedMinutes);
    const missing = Math.max(0, required - pausedMinutes);
    return {
      requiredMinutes: required,
      currentMinutes: pausedMinutes,
      missingMinutes: missing,
      isRequired: missing > 0,
    };
  }

  expectedEndTime(sessionStartDate: Date, dailyTargetMinutes: number, pauseMinutes: number): Date {
    const requiredBreak = this.requiredBreakMinutes(dailyTargetMinutes);
    const totalNeededMinutes = dailyTargetMinutes + Math.max(requiredBreak, pauseMinutes);
    const end = new Date(sessionStartDate.getTime() + totalNeededMinutes * 60_000);
    return end;
  }

  // Erzeugt Auto-Pausen gemäß ArbZG §4, falls manuell nicht genug erfasst.
  // Wird beim Stoppen der Session aufgerufen.
  calculateAutoBreaks(session: WorkSession): SessionBreak[] {
    const now = new Date();
    const start = session.startTime.toDate();
    const end = session.endTime ? session.endTime.toDate() : now;
    const grossMinutes = Math.floor((end.getTime() - start.getTime()) / 60_000);

    const required = this.requiredBreakMinutes(grossMinutes);
    const existing = session.breaks
      .filter(b => b.endTime)
      .reduce((sum, b) => sum + Math.floor((b.endTime!.toMillis() - b.startTime.toMillis()) / 60_000), 0);

    const missing = required - existing;
    if (missing <= 0) return [];

    const autoBreaks: SessionBreak[] = [];
    const pad = (n: number) => n.toString().padStart(2, '0');

    // First auto-break: 30min at 4h after start
    const break1Start = new Date(start.getTime() + 4 * 60 * 60_000);
    const break1End = new Date(break1Start.getTime() + 30 * 60_000);
    if (break1Start < end) {
      const t = `${pad(break1Start.getHours())}:${pad(break1Start.getMinutes())}`;
      autoBreaks.push({
        id: crypto.randomUUID(),
        name: `Auto-Pause (${t})`,
        startTime: Timestamp.fromDate(break1Start),
        endTime: Timestamp.fromDate(break1End < end ? break1End : end),
        isAutomatic: true,
      });
    }

    // Second auto-break: 15min at 6h after start (only for >9h sessions)
    if (grossMinutes >= 9 * 60 && missing > 30) {
      const break2Start = new Date(start.getTime() + 6 * 60 * 60_000);
      const break2End = new Date(break2Start.getTime() + 15 * 60_000);
      if (break2Start < end) {
        const t = `${pad(break2Start.getHours())}:${pad(break2Start.getMinutes())}`;
        autoBreaks.push({
          id: crypto.randomUUID(),
          name: `Auto-Pause (${t})`,
          startTime: Timestamp.fromDate(break2Start),
          endTime: Timestamp.fromDate(break2End < end ? break2End : end),
          isAutomatic: true,
        });
      }
    }

    return autoBreaks;
  }
}
