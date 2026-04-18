import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatListModule } from '@angular/material/list';
import { MatDividerModule } from '@angular/material/divider';
import { MatChipsModule } from '@angular/material/chips';
import { MatTooltipModule } from '@angular/material/tooltip';
import { WorkEntryService } from '../../core/services/work-entry';
import { SettingsService } from '../../core/services/settings';
import { WorkEntry, WorkEntryType, Break } from '../../shared/models';
import { 
  calculateNetMinutes, 
  calculateGrossMinutes, 
} from '../../shared/utils/time-calculations.util';
import { toSignal } from '@angular/core/rxjs-interop';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [
    CommonModule, 
    MatCardModule, 
    MatButtonModule, 
    MatIconModule, 
    MatFormFieldModule, 
    MatInputModule,
    MatListModule,
    MatDividerModule,
    MatChipsModule,
    MatTooltipModule
  ],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss'
})
export class DashboardComponent {
  private entryService = inject(WorkEntryService);
  private settingsService = inject(SettingsService);

  // Heutiger Eintrag als Signal
  todayEntry = toSignal(this.entryService.getTodayEntry());
  settings = toSignal(this.settingsService.getSettings());

  // Aktuelle Zeit für den Live-Timer
  now = signal(new Date());

  constructor() {
    // Live-Timer Ticker
    setInterval(() => {
      this.now.set(new Date());
    }, 1000);
  }

  // --- Berechnungen ---

  isTimerRunning = computed(() => {
    const entry = this.todayEntry();
    return !!(entry?.workStart && !entry.workEnd);
  });

  isBreakActive = computed(() => {
    const entry = this.todayEntry();
    return !!entry?.breaks.find(b => !b.end);
  });

  netMinutes = computed(() => {
    const entry = this.todayEntry();
    if (!entry || !entry.workStart) return 0;
    this.now(); // Trigger
    return calculateNetMinutes(entry);
  });

  grossMinutes = computed(() => {
    const entry = this.todayEntry();
    if (!entry || !entry.workStart) return 0;
    this.now(); // Trigger
    return calculateGrossMinutes(entry);
  });

  dailyOvertime = computed(() => {
    const s = this.settings();
    if (!s) return 0;
    const targetMinutes = (s.weeklyTargetHours / s.workdaysPerWeek) * 60;
    return this.netMinutes() - targetMinutes;
  });

  expectedEndTime = computed(() => {
    const entry = this.todayEntry();
    const s = this.settings();
    if (!entry?.workStart || !s) return null;

    const targetMinutes = (s.weeklyTargetHours / s.workdaysPerWeek) * 60;
    const totalBreakMinutes = entry.breaks.reduce((sum, b) => {
      const end = b.end || new Date();
      return sum + (end.getTime() - b.start.getTime()) / 60000;
    }, 0);

    const end = new Date(entry.workStart);
    end.setMinutes(end.getMinutes() + targetMinutes + totalBreakMinutes);
    return end;
  });

  formattedNetTime = computed(() => this.formatMinutes(this.netMinutes()));
  formattedGrossTime = computed(() => this.formatMinutes(this.grossMinutes()));
  formattedDailyOvertime = computed(() => this.formatOvertime(this.dailyOvertime()));

  // --- Actions ---

  async startOrStopTimer() {
    const entry = this.todayEntry();
    if (!entry?.workStart) {
      await this.entryService.saveEntry({
        id: new Date().toISOString().split('T')[0],
        date: new Date(),
        workStart: new Date(),
        breaks: [],
        isManuallyEntered: false,
        type: WorkEntryType.Work
      });
    } else if (!entry.workEnd) {
      await this.entryService.saveEntry({ ...entry, workEnd: new Date() });
    } else {
      if (confirm('Neue Session starten? (Pausen werden beibehalten)')) {
        await this.entryService.saveEntry({ ...entry, workStart: new Date(), workEnd: undefined });
      }
    }
  }

  async toggleBreak() {
    const entry = this.todayEntry();
    if (!entry) return;

    const activeBreak = entry.breaks.find(b => !b.end);
    let updatedBreaks = [...entry.breaks];

    if (activeBreak) {
      updatedBreaks = updatedBreaks.map(b => b.id === activeBreak.id ? { ...b, end: new Date() } : b);
    } else {
      updatedBreaks.push({
        id: crypto.randomUUID(),
        name: `Pause ${entry.breaks.length + 1}`,
        start: new Date(),
        isAutomatic: false
      });
    }

    await this.entryService.saveEntry({ ...entry, breaks: updatedBreaks });
  }

  async deleteBreak(id: string) {
    const entry = this.todayEntry();
    if (entry) {
      await this.entryService.saveEntry({
        ...entry,
        breaks: entry.breaks.filter(b => b.id !== id)
      });
    }
  }

  async setStartTime(timeStr: string) {
    const entry = this.todayEntry();
    if (entry && timeStr) {
      const date = this.parseTime(entry.date, timeStr);
      await this.entryService.saveEntry({ ...entry, workStart: date });
    }
  }

  async setEndTime(timeStr: string) {
    const entry = this.todayEntry();
    if (entry && timeStr) {
      const date = this.parseTime(entry.date, timeStr);
      await this.entryService.saveEntry({ ...entry, workEnd: date });
    }
  }

  async clearEndTime() {
    const entry = this.todayEntry();
    if (entry) {
      const { workEnd, ...rest } = entry;
      await this.entryService.saveEntry({ ...rest } as WorkEntry);
    }
  }

  // --- Utils ---

  formatMinutes(min: number): string {
    const h = Math.floor(min / 60);
    const m = Math.floor(min % 60);
    const s = Math.floor((min * 60) % 60);
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  formatOvertime(min: number): string {
    const sign = min >= 0 ? '+' : '-';
    const abs = Math.abs(min);
    const h = Math.floor(abs / 60);
    const m = Math.floor(abs % 60);
    return `${sign}${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
  }

  private parseTime(baseDate: Date, timeStr: string): Date {
    const [h, m] = timeStr.split(':').map(Number);
    const d = new Date(baseDate);
    d.setHours(h, m, 0, 0);
    return d;
  }

  getTimeValue(date?: Date): string {
    if (!date) return '';
    return date.toTimeString().slice(0, 5);
  }
}
