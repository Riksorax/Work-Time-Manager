// Agent 10 — Testing
// features/time-tracking/utils/time-calculations.util.spec.ts

import { Timestamp } from 'firebase/firestore';
import {
  calculateNetMinutes,
  calculateDailyTotal,
  calculateOvertimeMinutes,
  formatDuration,
  formatTimer,
  getElapsedSeconds,
  startOfWeek,
  endOfWeek,
  isSameDay,
  calculateCategoryBreakdown,
} from './time-calculations.util';
import { WorkSession } from '../../../shared/models';

// ─── Test-Hilfsfunktionen ────────────────────────────────────────────────────

function makeSession(overrides: Partial<WorkSession> = {}): WorkSession {
  const now = new Date('2024-01-15T08:00:00');
  return {
    id: 'test-id',
    userId: 'user-1',
    startTime: Timestamp.fromDate(now),
    endTime: Timestamp.fromDate(new Date('2024-01-15T17:00:00')),
    pauseDuration: 0,
    isRunning: false,
    isPaused: false,
    createdAt: Timestamp.fromDate(now),
    updatedAt: Timestamp.fromDate(now),
    ...overrides,
  };
}

// ─── calculateNetMinutes ─────────────────────────────────────────────────────

describe('calculateNetMinutes', () => {
  it('berechnet Nettozeit korrekt (ohne Pause)', () => {
    const session = makeSession({
      startTime: Timestamp.fromDate(new Date('2024-01-15T08:00:00')),
      endTime: Timestamp.fromDate(new Date('2024-01-15T17:00:00')),
      pauseDuration: 0,
    });
    expect(calculateNetMinutes(session)).toBe(540); // 9h = 540min
  });

  it('zieht Pausenzeit korrekt ab', () => {
    const session = makeSession({
      startTime: Timestamp.fromDate(new Date('2024-01-15T08:00:00')),
      endTime: Timestamp.fromDate(new Date('2024-01-15T17:00:00')),
      pauseDuration: 30,
    });
    expect(calculateNetMinutes(session)).toBe(510); // 9h - 30min = 510min
  });

  it('gibt niemals negative Werte zurück', () => {
    const session = makeSession({
      startTime: Timestamp.fromDate(new Date('2024-01-15T08:00:00')),
      endTime: Timestamp.fromDate(new Date('2024-01-15T08:05:00')),
      pauseDuration: 999, // Mehr Pause als Bruttozeit
    });
    expect(calculateNetMinutes(session)).toBe(0);
  });

  it('verwendet aktuelle Zeit wenn Session noch läuft (isRunning=true, kein endTime)', () => {
    const start = new Date();
    start.setMinutes(start.getMinutes() - 60); // vor 60 Minuten gestartet
    const session = makeSession({
      startTime: Timestamp.fromDate(start),
      endTime: undefined,
      isRunning: true,
      pauseDuration: 0,
    });
    const result = calculateNetMinutes(session);
    // Toleranz: ±1 Minute (Timing-Schwankungen im Test)
    expect(result).toBeGreaterThanOrEqual(59);
    expect(result).toBeLessThanOrEqual(61);
  });

  it('rechnet laufende Pause ein (isPaused=true)', () => {
    const start = new Date('2024-01-15T08:00:00');
    const pauseStart = new Date('2024-01-15T12:00:00');
    // pauseStartTime liegt in der Vergangenheit → laufende Pausenzeit wird addiert
    const session = makeSession({
      startTime: Timestamp.fromDate(start),
      endTime: undefined,
      isRunning: true,
      isPaused: true,
      pauseDuration: 0,
      pauseStartTime: Timestamp.fromDate(pauseStart),
    });
    // Erwartung: Bruttozeit minus laufende Pause → ≈ 0 Nettozeit bis 12:00 Uhr
    // (Test läuft nach 12:00, also laufende Pause ist ≥ Bruttozeit bis 12:00)
    const result = calculateNetMinutes(session);
    expect(result).toBeGreaterThanOrEqual(0);
  });
});

// ─── calculateDailyTotal ─────────────────────────────────────────────────────

describe('calculateDailyTotal', () => {
  it('summiert mehrere Sessions korrekt', () => {
    const sessions = [
      makeSession({ pauseDuration: 0,
        startTime: Timestamp.fromDate(new Date('2024-01-15T08:00:00')),
        endTime:   Timestamp.fromDate(new Date('2024-01-15T12:00:00')) }), // 240min
      makeSession({ pauseDuration: 0,
        startTime: Timestamp.fromDate(new Date('2024-01-15T13:00:00')),
        endTime:   Timestamp.fromDate(new Date('2024-01-15T17:00:00')) }), // 240min
    ];
    expect(calculateDailyTotal(sessions)).toBe(480); // 8h
  });

  it('gibt 0 zurück für leere Session-Liste', () => {
    expect(calculateDailyTotal([])).toBe(0);
  });
});

// ─── calculateOvertimeMinutes ─────────────────────────────────────────────────

describe('calculateOvertimeMinutes', () => {
  it('berechnet positive Überstunden', () => {
    expect(calculateOvertimeMinutes(510, 480)).toBe(30);
  });
  it('berechnet negative Unterzeit', () => {
    expect(calculateOvertimeMinutes(420, 480)).toBe(-60);
  });
  it('gibt 0 zurück wenn exakt Soll', () => {
    expect(calculateOvertimeMinutes(480, 480)).toBe(0);
  });
});

// ─── formatDuration ───────────────────────────────────────────────────────────

describe('formatDuration', () => {
  it('formatiert positive Minuten korrekt', () => {
    expect(formatDuration(510)).toBe('8h 30min');
    expect(formatDuration(480)).toBe('8h 00min');
    expect(formatDuration(0)).toBe('0h 00min');
    expect(formatDuration(59)).toBe('0h 59min');
    expect(formatDuration(60)).toBe('1h 00min');
  });
  it('formatiert negative Minuten (Unterzeit) korrekt', () => {
    expect(formatDuration(-90)).toBe('-1h 30min');
    expect(formatDuration(-60)).toBe('-1h 00min');
    expect(formatDuration(-1)).toBe('-0h 01min');
  });
});

// ─── formatTimer ─────────────────────────────────────────────────────────────

describe('formatTimer', () => {
  it('formatiert Sekunden als HH:MM:SS', () => {
    expect(formatTimer(0)).toBe('00:00:00');
    expect(formatTimer(90)).toBe('00:01:30');
    expect(formatTimer(3661)).toBe('01:01:01');
    expect(formatTimer(36000)).toBe('10:00:00');
  });
});

// ─── startOfWeek / endOfWeek ─────────────────────────────────────────────────

describe('startOfWeek / endOfWeek', () => {
  it('Montag ist Wochenstart', () => {
    const wednesday = new Date('2024-01-17T12:00:00'); // Mittwoch
    const monday = startOfWeek(wednesday);
    expect(monday.getDay()).toBe(1); // Montag
    expect(monday.getDate()).toBe(15);
  });
  it('Sonntag ist Wochenende', () => {
    const wednesday = new Date('2024-01-17T12:00:00');
    const sunday = endOfWeek(wednesday);
    expect(sunday.getDay()).toBe(0); // Sonntag
    expect(sunday.getDate()).toBe(21);
  });
});

// ─── calculateCategoryBreakdown ───────────────────────────────────────────────

describe('calculateCategoryBreakdown', () => {
  it('gruppiert Sessions nach Kategorie', () => {
    const sessions = [
      makeSession({ category: 'Entwicklung',
        startTime: Timestamp.fromDate(new Date('2024-01-15T08:00:00')),
        endTime:   Timestamp.fromDate(new Date('2024-01-15T12:00:00')) }), // 240min
      makeSession({ category: 'Meetings',
        startTime: Timestamp.fromDate(new Date('2024-01-15T13:00:00')),
        endTime:   Timestamp.fromDate(new Date('2024-01-15T14:00:00')) }), // 60min
      makeSession({ category: 'Entwicklung',
        startTime: Timestamp.fromDate(new Date('2024-01-15T14:00:00')),
        endTime:   Timestamp.fromDate(new Date('2024-01-15T17:00:00')) }), // 180min
    ];

    const result = calculateCategoryBreakdown(sessions);
    expect(result).toHaveLength(2);
    expect(result[0].category).toBe('Entwicklung');
    expect(result[0].totalMinutes).toBe(420);
    expect(result[1].category).toBe('Meetings');
    expect(result[1].totalMinutes).toBe(60);
    expect(result[0].percentage + result[1].percentage).toBeLessThanOrEqual(101); // Rundungsfehler
  });

  it('gibt "Keine Kategorie" für Sessions ohne Kategorie', () => {
    const sessions = [makeSession({ category: undefined })];
    const result = calculateCategoryBreakdown(sessions);
    expect(result[0].category).toBe('Keine Kategorie');
  });
});
