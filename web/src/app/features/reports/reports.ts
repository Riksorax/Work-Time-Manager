import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatTabsModule } from '@angular/material/tabs';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDividerModule } from '@angular/material/divider';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { WorkEntryService } from '../../core/services/work-entry';
import { SettingsService } from '../../core/services/settings';
import { CalendarComponent } from '../../shared/components/calendar/calendar';
import { EditEntryDialogComponent } from '../../shared/components/edit-entry-dialog/edit-entry-dialog';
import { toSignal } from '@angular/core/rxjs-interop';
import { WorkEntry } from '../../shared/models';
import { calculateNetMinutes } from '../../shared/utils/time-calculations.util';

@Component({
  selector: 'app-reports',
  standalone: true,
  imports: [
    CommonModule, 
    MatTabsModule, 
    MatCardModule, 
    MatButtonModule, 
    MatIconModule,
    MatDividerModule,
    MatDialogModule,
    CalendarComponent
  ],
  templateUrl: './reports.html',
  styleUrl: './reports.scss'
})
export class ReportsComponent {
  private entryService = inject(WorkEntryService);
  private settingsService = inject(SettingsService);
  private dialog = inject(MatDialog);

  // State
  selectedDate = signal(new Date());
  viewMonth = signal({ year: new Date().getFullYear(), month: new Date().getMonth() + 1 });
  
  // Data Signals
  settings = toSignal(this.settingsService.getSettings());
  
  // Wir laden die Einträge für den aktuell angezeigten Monat im Kalender
  entries = toSignal(computed(() => {
    const { year, month } = this.viewMonth();
    return this.entryService.getEntriesForMonth(year, month);
  }), { initialValue: [] as WorkEntry[] });

  // Tage mit Einträgen für den Kalender-Dot
  daysWithEntries = computed(() => {
    return this.entries().map(e => e.date.getDate());
  });

  // Details für den selektierten Tag
  selectedDayEntries = computed(() => {
    const sel = this.selectedDate();
    return this.entries().filter(e => 
      e.date.getDate() === sel.getDate() && 
      e.date.getMonth() === sel.getMonth() && 
      e.date.getFullYear() === sel.getFullYear()
    );
  });

  // Statistiken für den Monat
  monthlyStats = computed(() => {
    const data = this.entries();
    const totalMinutes = data.reduce((acc, curr) => acc + calculateNetMinutes(curr), 0);
    const workDays = new Set(data.map(e => e.date.toDateString())).size;
    
    return {
      totalMinutes,
      formattedTotal: this.formatMinutes(totalMinutes),
      workDays,
      avgMinutesPerDay: workDays > 0 ? Math.round(totalMinutes / workDays) : 0,
      formattedAvg: this.formatMinutes(workDays > 0 ? totalMinutes / workDays : 0)
    };
  });

  selectDate(date: Date) {
    this.selectedDate.set(date);
  }

  onMonthChanged(event: { year: number, month: number }) {
    this.viewMonth.set(event);
  }

  formatMinutes(minutes: number): string {
    const h = Math.floor(minutes / 60);
    const m = Math.floor(minutes % 60);
    return `${h}h ${m}m`;
  }

  async deleteEntry(id: string) {
    if (confirm('Eintrag wirklich löschen?')) {
      await this.entryService.deleteEntry(id);
    }
  }

  openEditDialog(entry?: WorkEntry) {
    const dialogRef = this.dialog.open(EditEntryDialogComponent, {
      width: '500px',
      data: {
        entry,
        date: entry?.date || this.selectedDate()
      }
    });

    dialogRef.afterClosed().subscribe(async result => {
      if (result) {
        await this.entryService.saveEntry(result as WorkEntry);
      }
    });
  }
}
