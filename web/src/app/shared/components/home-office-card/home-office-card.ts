import { ChangeDetectionStrategy, Component, computed, effect, inject, input, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslatePipe } from '@ngx-translate/core';
import { LanguageService } from '../../../core/services/language';
import { WorkEntryService } from '../../../core/services/work-entry';
import { WorkProfileService } from '../../../core/services/work-profile';
import { HomeOfficeStats, calculateHomeOfficeStats } from '../../../domain/services/home-office-stats';
import { WorkEntry } from '../../models/index';

type CardState = { status: 'loading' } | { status: 'error' } | { status: 'data'; stats: HomeOfficeStats };

/** Home-Office-Jahresauswertung (#283/#483): lädt die zwölf Monate des Jahres und zählt nach `calculateHomeOfficeStats`. */
@Component({
  selector: 'app-home-office-card',
  imports: [MatButtonModule, MatIconModule, MatProgressSpinnerModule, TranslatePipe],
  templateUrl: './home-office-card.html',
  styleUrl: './home-office-card.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class HomeOfficeCardComponent {
  private readonly workEntries = inject(WorkEntryService);
  private readonly workProfile = inject(WorkProfileService);
  private readonly language    = inject(LanguageService);

  readonly year = input.required<number>();

  protected readonly state = signal<CardState>({ status: 'loading' });
  protected readonly ratio = computed(() => {
    const s = this.state();
    return s.status === 'data' ? s.stats.ratio : null;
  });

  private _seq = 0;

  constructor() {
    effect(() => {
      const year = this.year();
      // Profilwechsel lädt neu (die Karte liest immer das aktive Profil).
      this.workProfile.activeProfileId();
      void this.load(year);
    });
  }

  /** Anteil mit einer Nachkommastelle in der Sprache der App ("33,3 %" / "33.3 %"). */
  protected formatRatio(ratio: number): string {
    return `${(ratio * 100).toLocaleString(this.language.locale(), { minimumFractionDigits: 1, maximumFractionDigits: 1 })} %`;
  }

  protected retry(): void {
    void this.load(this.year());
  }

  private async load(year: number): Promise<void> {
    const seq = ++this._seq;
    this.state.set({ status: 'loading' });
    try {
      const months = await Promise.all(
        Array.from({ length: 12 }, (_, i) => this.workEntries.getEntriesForMonthOnce(year, i + 1)),
      );
      if (seq !== this._seq) return;
      const entries: WorkEntry[] = months.flat();
      this.state.set({ status: 'data', stats: calculateHomeOfficeStats(entries) });
    } catch {
      if (seq !== this._seq) return;
      this.state.set({ status: 'error' });
    }
  }
}
