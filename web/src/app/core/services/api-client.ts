import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, firstValueFrom, map } from 'rxjs';
import { environment } from '../../../environments/environment';
import { Break, UserSettings, WorkEntry, WorkEntryType } from '../../shared/models';
import { DailyStat, MonthlyReport, WeeklyReport } from '../../domain/models/reports.models';

// ─── Backend-DTO-Formen (JSON, camelCase, ISO-8601-Daten, Zeiten in ms) ──────

interface WorkEntryDto {
  id: string;
  date: string;
  workStart: string | null;
  workEnd: string | null;
  type: string;
  isManuallyEntered: boolean;
  manualOvertimeMinutes: number | null;
  description: string | null;
  breaks: BreakDto[];
}
interface BreakDto {
  id: string;
  name: string;
  isAutomatic: boolean;
  start: string;
  end: string | null;
}
interface OvertimeDto { minutes: number; lastUpdated: string | null; }
interface ProfileDto { uid: string; isPremium: boolean; }
interface DailyStatDto { targetMs: number; workedMs: number; overtimeMs: number; }
interface ReportDayDto { date: string; workedMs: number; }
interface WeeklyReportDto {
  weekNumber: number; start: string; end: string;
  totalWorkedMs: number; totalBreaksMs: number; workDays: number;
  avgPerDayMs: number; overtimeMs: number; days: ReportDayDto[];
}
interface ReportWeekDto { weekNumber: number; totalWorkedMs: number; }
interface MonthlyReportDto {
  month: string; totalWorkedMs: number; totalBreaksMs: number; workDays: number;
  avgPerDayMs: number; avgPerWeekMs: number; monthlyOvertimeMs: number;
  totalOvertimeMs: number; weeks: ReportWeekDto[]; days: ReportDayDto[];
}

/**
 * Typisierter Client für die .NET-Backend-API. Übernimmt das Mapping zwischen
 * Backend-DTOs und den Domain-Modellen. Das Firebase-ID-Token wird vom
 * `authInterceptor` angehängt.
 */
@Injectable({ providedIn: 'root' })
export class ApiClient {
  private readonly http = inject(HttpClient);
  private readonly base = `${environment.apiUrl}/api`;

  // ── Work-Entries ──────────────────────────────────────────────────────────

  saveWorkEntry(entry: WorkEntry): Promise<void> {
    return firstValueFrom(
      this.http.put<WorkEntryDto>(`${this.base}/work-entries`, this.toDto(entry)).pipe(map(() => void 0))
    );
  }

  deleteWorkEntry(id: string): Promise<void> {
    const [y, m, d] = id.split('-').map(Number);
    return firstValueFrom(
      this.http.delete<void>(`${this.base}/work-entries/${y}/${m}/${d}`)
    );
  }

  async getWorkEntriesForMonth(year: number, month: number): Promise<WorkEntry[]> {
    const dtos = await firstValueFrom(
      this.http.get<WorkEntryDto[]>(`${this.base}/work-entries/${year}/${month}`)
    );
    return dtos.map(dto => this.fromDto(dto));
  }

  // ── Overtime ──────────────────────────────────────────────────────────────

  async getOvertimeMs(): Promise<number> {
    const dto = await firstValueFrom(this.http.get<OvertimeDto>(`${this.base}/overtime`));
    return (dto.minutes ?? 0) * 60_000;
  }

  async getOvertimeLastUpdate(): Promise<Date | null> {
    const dto = await firstValueFrom(this.http.get<OvertimeDto>(`${this.base}/overtime`));
    return dto.lastUpdated ? new Date(dto.lastUpdated) : null;
  }

  saveOvertimeMs(ms: number): Promise<void> {
    return firstValueFrom(
      this.http.put<OvertimeDto>(`${this.base}/overtime`, { minutes: Math.round(ms / 60_000) }).pipe(map(() => void 0))
    );
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  async getSettings(): Promise<UserSettings> {
    return firstValueFrom(this.http.get<UserSettings>(`${this.base}/settings`));
  }

  saveSettings(settings: UserSettings): Promise<void> {
    return firstValueFrom(
      this.http.put<UserSettings>(`${this.base}/settings`, settings).pipe(map(() => void 0))
    );
  }

  // ── Profile ───────────────────────────────────────────────────────────────

  async getProfile(): Promise<ProfileDto> {
    return firstValueFrom(this.http.get<ProfileDto>(`${this.base}/profile`));
  }

  // ── Reports (reaktiv) ─────────────────────────────────────────────────────

  getDailyReport(year: number, month: number, day: number): Observable<DailyStat> {
    return this.http.get<DailyStatDto>(`${this.base}/reports/daily/${year}/${month}/${day}`).pipe(
      map(dto => ({ target: dto.targetMs, worked: dto.workedMs, overtime: dto.overtimeMs }))
    );
  }

  getWeeklyReport(year: number, month: number, day: number): Observable<WeeklyReport> {
    return this.http.get<WeeklyReportDto>(`${this.base}/reports/weekly/${year}/${month}/${day}`).pipe(
      map(dto => ({
        weekNumber: dto.weekNumber,
        start: new Date(dto.start),
        end: new Date(dto.end),
        totalWorked: dto.totalWorkedMs,
        totalBreaks: dto.totalBreaksMs,
        workDays: dto.workDays,
        avgPerDay: dto.avgPerDayMs,
        overtime: dto.overtimeMs,
        days: dto.days.map(d => ({ date: new Date(d.date), worked: d.workedMs })),
      }))
    );
  }

  getMonthlyReport(year: number, month: number): Observable<MonthlyReport> {
    return this.http.get<MonthlyReportDto>(`${this.base}/reports/monthly/${year}/${month}`).pipe(
      map(dto => ({
        month: new Date(dto.month),
        totalWorked: dto.totalWorkedMs,
        totalBreaks: dto.totalBreaksMs,
        workDays: dto.workDays,
        avgPerDay: dto.avgPerDayMs,
        avgPerWeek: dto.avgPerWeekMs,
        monthlyOvertime: dto.monthlyOvertimeMs,
        totalOvertime: dto.totalOvertimeMs,
        weeks: dto.weeks.map(w => ({ weekNumber: w.weekNumber, totalWorked: w.totalWorkedMs })),
        days: dto.days.map(d => ({ date: new Date(d.date), worked: d.workedMs })),
      }))
    );
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  private toDto(entry: WorkEntry): WorkEntryDto {
    return {
      id: entry.id,
      // UTC-Mitternacht aus lokalen Y/M/D — verhindert Tag-Verschiebung (analog Firestore-Mapping)
      date: new Date(Date.UTC(entry.date.getFullYear(), entry.date.getMonth(), entry.date.getDate())).toISOString(),
      workStart: entry.workStart?.toISOString() ?? null,
      workEnd: entry.workEnd?.toISOString() ?? null,
      type: entry.type ?? WorkEntryType.Work,
      isManuallyEntered: entry.isManuallyEntered ?? false,
      manualOvertimeMinutes: entry.manualOvertimeMinutes ?? null,
      description: entry.description ?? null,
      breaks: entry.breaks.map(b => ({
        id: b.id,
        name: b.name,
        isAutomatic: b.isAutomatic,
        start: b.start.toISOString(),
        end: b.end?.toISOString() ?? null,
      })),
    };
  }

  private fromDto(dto: WorkEntryDto): WorkEntry {
    return {
      id: dto.id,
      date: new Date(dto.date),
      workStart: dto.workStart ? new Date(dto.workStart) : undefined,
      workEnd: dto.workEnd ? new Date(dto.workEnd) : undefined,
      type: (dto.type as WorkEntryType) ?? WorkEntryType.Work,
      isManuallyEntered: dto.isManuallyEntered ?? false,
      manualOvertimeMinutes: dto.manualOvertimeMinutes ?? undefined,
      description: dto.description ?? undefined,
      breaks: (dto.breaks ?? []).map((b): Break => ({
        id: b.id,
        name: b.name,
        isAutomatic: b.isAutomatic ?? false,
        start: new Date(b.start),
        end: b.end ? new Date(b.end) : undefined,
      })),
    };
  }
}
