import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { TranslatePipe } from '@ngx-translate/core';

export interface AdjustOvertimeDialogData   { currentOvertimeMs: number; }
export type    AdjustOvertimeDialogResult   = { overtimeMs: number } | 'reset';

@Component({
  selector: 'app-adjust-overtime-dialog',
  imports: [
    ReactiveFormsModule,
    MatDialogModule, MatButtonModule,
    MatFormFieldModule, MatInputModule, MatIconModule,
    TranslatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <h2 mat-dialog-title>{{ 'settings.adjustOvertimeDialogTitle' | translate }}</h2>
    <mat-dialog-content>
      <p class="hint-text">
        {{ 'settings.adjustOvertimeHint' | translate }}
      </p>

      <!-- Vorzeichen-Auswahl -->
      <div class="sign-row" role="group" [attr.aria-label]="'settings.signGroupAria' | translate">
        <button mat-stroked-button
                [class.active]="!isNegative()"
                (click)="isNegative.set(false)"
                [attr.aria-label]="'settings.overtimePositiveAria' | translate">
          <mat-icon>add</mat-icon> {{ 'settings.overtimePositiveButton' | translate }}
        </button>
        <button mat-stroked-button
                [class.active]="isNegative()"
                (click)="isNegative.set(true)"
                [attr.aria-label]="'settings.overtimeNegativeAria' | translate">
          <mat-icon>remove</mat-icon> {{ 'settings.overtimeNegativeButton' | translate }}
        </button>
      </div>

      <form [formGroup]="form" class="time-fields">
        <mat-form-field appearance="outline">
          <mat-label>{{ 'settings.hoursLabel' | translate }}</mat-label>
          <input matInput type="number" formControlName="hours"
                 min="0" [attr.aria-label]="'settings.hoursLabel' | translate" />
          <mat-hint>{{ 'settings.hoursHintEmpty' | translate }}</mat-hint>
        </mat-form-field>
        <mat-form-field appearance="outline">
          <mat-label>{{ 'settings.minutesLabel' | translate }}</mat-label>
          <input matInput type="number" formControlName="minutes"
                 min="0" max="59" [attr.aria-label]="'settings.minutesAria' | translate" />
        </mat-form-field>
      </form>
    </mat-dialog-content>
    <mat-dialog-actions>
      <button mat-button (click)="reset()" [attr.aria-label]="'settings.resetToZeroAria' | translate">
        {{ 'settings.resetToZeroButton' | translate }}
      </button>
      <span class="spacer"></span>
      <button mat-button mat-dialog-close>{{ 'common.cancel' | translate }}</button>
      <button mat-flat-button [disabled]="form.invalid" (click)="submit()">
        {{ 'common.save' | translate }}
      </button>
    </mat-dialog-actions>
  `,
  styles: [`
    .hint-text  { margin: 0 0 16px; font-size: 0.875rem; color: var(--mat-sys-on-surface-variant); }
    .sign-row   { display: flex; gap: 8px; margin-bottom: 16px; }
    // Gleich breit und umbrechbar, sonst ragt das Icon auf 320 px über den Rand und der Text quetscht sich.
    .sign-row button { flex: 1 1 0; min-width: 0; padding-inline: 8px; white-space: normal; line-height: 1.2; }
    .sign-row button.active { background: var(--mat-sys-secondary-container); color: var(--mat-sys-on-secondary-container); }
    .time-fields { display: flex; gap: 12px; }
    .time-fields mat-form-field { flex: 1; min-width: 0; }
    mat-dialog-actions { display: flex; align-items: center; }
    .spacer { flex: 1; }
    mat-dialog-content { min-width: min(300px, calc(95vw - 48px)); }
  `],
})
export class AdjustOvertimeDialogComponent {
  protected readonly data      = inject<AdjustOvertimeDialogData>(MAT_DIALOG_DATA);
  private  readonly dialogRef  = inject(MatDialogRef<AdjustOvertimeDialogComponent>);
  private  readonly fb         = inject(FormBuilder);

  protected readonly isNegative = signal(this.data.currentOvertimeMs < 0);

  private readonly _absMs = Math.abs(this.data.currentOvertimeMs);

  protected readonly form = this.fb.group({
    hours:   [Math.floor(this._absMs / 3600000),                    [Validators.required, Validators.min(0)]],
    minutes: [Math.floor((this._absMs % 3600000) / 60000), [Validators.required, Validators.min(0), Validators.max(59)]],
  });

  submit(): void {
    if (this.form.invalid) return;
    const v = this.form.getRawValue();
    const total = ((v.hours ?? 0) * 60 + (v.minutes ?? 0)) * 60000;
    const ms    = this.isNegative() ? -total : total;
    this.dialogRef.close({ overtimeMs: ms } satisfies AdjustOvertimeDialogResult);
  }

  reset(): void {
    this.dialogRef.close('reset' satisfies AdjustOvertimeDialogResult);
  }
}
