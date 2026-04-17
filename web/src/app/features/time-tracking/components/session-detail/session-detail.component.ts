import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
  input,
  effect,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { Router } from '@angular/router';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { TranslateModule } from '@ngx-translate/core';
import { WorkSessionService } from '../../services/work-session.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { WorkSession, WorkSessionType } from '../../../../shared/models';
import { DurationPipe } from '../../../../shared/pipes/duration.pipe';
import { calculateNetMinutes } from '../../utils/time-calculations.util';

const SESSION_TYPE_ICONS: Record<WorkSessionType, string> = {
  work: 'work',
  vacation: 'beach_access',
  sick: 'sick',
  holiday: 'celebration',
};

@Component({
  selector: 'wtm-session-detail',
  standalone: true,
  imports: [
    DatePipe,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatIconModule,
    MatProgressSpinnerModule,
    TranslateModule,
    DurationPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 600px; margin: 0 auto; }

    .page-header {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 24px;
      h1 { margin: 0; font-size: 1.25rem; font-weight: 700; }
    }

    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-bottom: 24px;

      .info-item {
        label { font-size: 0.75rem; color: var(--mat-sys-on-surface-variant); display: block; }
        span { font-weight: 600; }
      }
    }

    form { display: flex; flex-direction: column; gap: 12px; }

    mat-form-field { width: 100%; }

    .type-row {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 0.9rem;
    }

    .form-actions {
      display: flex;
      gap: 8px;
      justify-content: flex-end;
      margin-top: 8px;
    }
  `],
  template: `
    <div class="page-header">
      <button mat-icon-button (click)="back()">
        <mat-icon>arrow_back</mat-icon>
      </button>
      <h1>{{ 'common.edit' | translate }}</h1>
    </div>

    @if (session()) {
      <div class="info-grid">
        <div class="info-item">
          <label>{{ 'sessions.startTime' | translate }}</label>
          <span>{{ session()!.startTime.toDate() | date:'dd.MM.yyyy HH:mm' }}</span>
        </div>
        <div class="info-item">
          <label>{{ 'sessions.endTime' | translate }}</label>
          <span>
            @if (session()!.endTime) {
              {{ session()!.endTime!.toDate() | date:'dd.MM.yyyy HH:mm' }}
            } @else {
              läuft noch
            }
          </span>
        </div>
        <div class="info-item">
          <label>{{ 'sessions.pause' | translate }}</label>
          <span>{{ session()!.pauseDuration }} min</span>
        </div>
        <div class="info-item">
          <label>{{ 'sessions.duration' | translate }}</label>
          <span>{{ netMinutes() | duration }}</span>
        </div>
      </div>

      <form [formGroup]="form" (ngSubmit)="save()">
        <mat-form-field appearance="outline">
          <mat-label>Typ</mat-label>
          <mat-select formControlName="type">
            @for (t of sessionTypes; track t) {
              <mat-option [value]="t">
                <span class="type-row">
                  <mat-icon style="font-size:16px;width:16px;height:16px">{{ typeIcon(t) }}</mat-icon>
                  {{ typeLabel(t) }}
                </span>
              </mat-option>
            }
          </mat-select>
        </mat-form-field>

        <mat-form-field appearance="outline">
          <mat-label>{{ 'sessions.note' | translate }}</mat-label>
          <textarea matInput formControlName="note" rows="3"></textarea>
        </mat-form-field>

        <mat-form-field appearance="outline">
          <mat-label>{{ 'sessions.category' | translate }}</mat-label>
          <input matInput formControlName="category" />
          <mat-icon matSuffix>label</mat-icon>
        </mat-form-field>

        <div class="form-actions">
          <button mat-button type="button" (click)="back()">
            {{ 'common.cancel' | translate }}
          </button>
          <button mat-flat-button type="submit" [disabled]="saving()">
            @if (saving()) {
              <mat-spinner diameter="18" />
            } @else {
              {{ 'common.save' | translate }}
            }
          </button>
        </div>
      </form>
    } @else {
      <div style="text-align:center;padding:40px;color:var(--mat-sys-on-surface-variant)">
        <mat-spinner />
      </div>
    }
  `,
})
export class SessionDetailComponent {
  readonly id = input.required<string>();

  private sessionService = inject(WorkSessionService);
  private router = inject(Router);
  private toast = inject(ToastService);
  private fb = inject(FormBuilder);

  readonly saving = signal(false);
  readonly session = signal<WorkSession | null>(null);

  readonly sessionTypes: WorkSessionType[] = ['work', 'vacation', 'sick', 'holiday'];

  readonly form = this.fb.nonNullable.group({
    type: ['work' as WorkSessionType],
    note: [''],
    category: [''],
  });

  constructor() {
    effect(() => {
      const id = this.id();
      if (!id) return;
      this.sessionService.getSession$(id).subscribe(s => {
        this.session.set(s);
        if (s) {
          this.form.patchValue({
            type: s.type ?? 'work',
            note: s.note ?? '',
            category: s.category ?? '',
          });
        }
      });
    });
  }

  typeIcon(type: WorkSessionType): string {
    return SESSION_TYPE_ICONS[type];
  }

  typeLabel(type: WorkSessionType): string {
    const labels: Record<WorkSessionType, string> = {
      work: 'Arbeit', vacation: 'Urlaub', sick: 'Krank', holiday: 'Feiertag',
    };
    return labels[type];
  }

  netMinutes(): number {
    const s = this.session();
    return s ? calculateNetMinutes(s) : 0;
  }

  async save(): Promise<void> {
    const s = this.session();
    if (!s) return;
    this.saving.set(true);
    try {
      const { type, note, category } = this.form.getRawValue();
      await this.sessionService.updateSession(s.id, {
        type,
        note: note || undefined,
        category: category || undefined,
      });
      this.toast.success('Gespeichert');
      this.back();
    } catch {
      this.toast.error('common.error');
    } finally {
      this.saving.set(false);
    }
  }

  back(): void {
    this.router.navigate(['/time-tracking']);
  }
}
