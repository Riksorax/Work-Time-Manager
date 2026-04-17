import { Injectable } from '@angular/core';

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

  // Berechnet den voraussichtlichen Feierabend
  // startTime: Sekunden seit Session-Start (laufend)
  // dailyTargetMinutes: Soll-Arbeitszeit in Minuten
  // pauseMinutes: bisherige Pausen
  // returns: voraussichtliche Feierabend-Zeit als Date
  expectedEndTime(sessionStartDate: Date, dailyTargetMinutes: number, pauseMinutes: number): Date {
    const requiredBreak = this.requiredBreakMinutes(dailyTargetMinutes);
    const totalNeededMinutes = dailyTargetMinutes + Math.max(requiredBreak, pauseMinutes);
    const end = new Date(sessionStartDate.getTime() + totalNeededMinutes * 60_000);
    return end;
  }
}
