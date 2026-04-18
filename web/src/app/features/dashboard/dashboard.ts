import { Component, inject, signal, computed, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { WorkEntryService } from '../../core/services/work-entry';
import { WorkEntry, WorkEntryType } from '../../shared/models';
import { 
  calculateNetMinutes, 
  calculateGrossMinutes, 
  calculateOvertimeMinutes 
} from '../../shared/utils/time-calculations.util';
import { toSignal } from '@angular/core/rxjs-interop';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, MatCardModule, MatButtonModule, MatIconModule],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss'
})
export class DashboardComponent {
  private entryService = inject(WorkEntryService);

  // Heutiger Eintrag als Signal
  todayEntry = toSignal(this.entryService.getTodayEntry());

  // Aktuelle Zeit für den Live-Timer
  now = signal(new Date());

  // Berechnete Werte basierend auf Signals
  netMinutes = computed(() => {
    const entry = this.todayEntry();
    if (!entry) return 0;
    // Wir triggern das Signal 'now' alle Sekunde (siehe unten)
    this.now(); 
    return calculateNetMinutes(entry);
  });

  formattedTime = computed(() => {
    const totalMinutes = this.netMinutes();
    const hours = Math.floor(totalMinutes / 60);
    const minutes = Math.floor(totalMinutes % 60);
    const seconds = Math.floor((totalMinutes * 60) % 60);
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  });

  constructor() {
    // Live-Timer Ticker
    setInterval(() => {
      this.now.set(new Date());
    }, 1000);
  }

  async startTimer() {
    const today = new Date();
    const newEntry: WorkEntry = {
      id: today.toISOString().split('T')[0],
      date: today,
      workStart: new Date(),
      breaks: [],
      isManuallyEntered: false,
      type: WorkEntryType.Work
    };
    await this.entryService.saveEntry(newEntry);
  }

  async stopTimer() {
    const entry = this.todayEntry();
    if (entry) {
      const updated = { ...entry, workEnd: new Date() };
      await this.entryService.saveEntry(updated);
    }
  }

  async toggleBreak() {
    const entry = this.todayEntry();
    if (!entry) return;

    const activeBreak = entry.breaks.find(b => !b.end);
    let updatedBreaks = [...entry.breaks];

    if (activeBreak) {
      // Pause beenden
      updatedBreaks = updatedBreaks.map(b => b.id === activeBreak.id ? { ...b, end: new Date() } : b);
    } else {
      // Neue Pause starten
      updatedBreaks.push({
        id: crypto.randomUUID(),
        name: `Pause ${entry.breaks.length + 1}`,
        start: new Date(),
        isAutomatic: false
      });
    }

    await this.entryService.saveEntry({ ...entry, breaks: updatedBreaks });
  }
}
