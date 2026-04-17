import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
} from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatDividerModule } from '@angular/material/divider';
import { MatDialog, MatDialogModule } from '@angular/material/dialog';
import { TranslateModule } from '@ngx-translate/core';
import { UserProfileService } from '../../services/user-profile.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';
import { LegalDialogComponent } from '../../../../shared/components/legal/legal-dialog.component';

const APP_VERSION = '1.0.0';

@Component({
  selector: 'wtm-app-settings',
  standalone: true,
  imports: [
    ReactiveFormsModule,
    MatCardModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatDividerModule,
    MatDialogModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 600px; margin: 0 auto; }

    h1 { margin: 0 0 20px; font-size: 1.5rem; font-weight: 700; }

    section { margin-bottom: 20px; }

    h2 { font-size: 0.85rem; font-weight: 600; text-transform: uppercase;
      letter-spacing: 0.5px; color: var(--mat-sys-on-surface-variant);
      margin: 0 0 12px; }

    form { display: flex; flex-direction: column; gap: 4px; }
    mat-form-field { width: 100%; }

    .form-actions {
      display: flex;
      justify-content: flex-end;
      margin-top: 4px;
    }

    .legal-row {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      padding: 8px 0;
    }

    .version-row {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 0.8rem;
      color: var(--mat-sys-on-surface-variant);
      padding: 8px 0;
    }
  `],
  template: `
    <h1>{{ 'settings.app.title' | translate }}</h1>

    <mat-card appearance="outlined">
      <mat-card-content>
        <form [formGroup]="form" (ngSubmit)="save()">
          <section>
            <h2>Darstellung</h2>

            <mat-form-field appearance="outline">
              <mat-label>{{ 'settings.app.language' | translate }}</mat-label>
              <mat-select formControlName="language">
                <mat-option value="de">Deutsch</mat-option>
                <mat-option value="en">English</mat-option>
              </mat-select>
              <mat-icon matSuffix>language</mat-icon>
            </mat-form-field>

            <mat-form-field appearance="outline">
              <mat-label>{{ 'settings.app.theme' | translate }}</mat-label>
              <mat-select formControlName="theme">
                <mat-option value="system">{{ 'settings.app.themeSystem' | translate }}</mat-option>
                <mat-option value="light">{{ 'settings.app.themeLight' | translate }}</mat-option>
                <mat-option value="dark">{{ 'settings.app.themeDark' | translate }}</mat-option>
              </mat-select>
              <mat-icon matSuffix>palette</mat-icon>
            </mat-form-field>
          </section>

          <mat-divider />

          <section style="margin-top:16px">
            <h2>Arbeitszeiten</h2>

            <mat-form-field appearance="outline">
              <mat-label>{{ 'settings.app.weeklyTarget' | translate }}</mat-label>
              <input matInput type="number" formControlName="weeklyTargetHours" min="1" max="80" />
              <span matSuffix>h</span>
            </mat-form-field>

            <mat-form-field appearance="outline">
              <mat-label>{{ 'settings.app.dailyTarget' | translate }}</mat-label>
              <input matInput type="number" formControlName="dailyTargetHours" min="1" max="24" />
              <span matSuffix>h</span>
            </mat-form-field>

            <mat-form-field appearance="outline">
              <mat-label>{{ 'settings.app.defaultPause' | translate }}</mat-label>
              <input matInput type="number" formControlName="defaultPauseDuration" min="0" max="120" />
              <span matSuffix>min</span>
            </mat-form-field>
          </section>

          <div class="form-actions">
            <button mat-flat-button type="submit" [disabled]="form.pristine || saving()">
              @if (saving()) {
                <mat-spinner diameter="18" />
              } @else {
                {{ 'common.save' | translate }}
              }
            </button>
          </div>
        </form>
      </mat-card-content>
    </mat-card>

    <mat-card appearance="outlined" style="margin-top:16px">
      <mat-card-content>
        <section>
          <h2>Rechtliches</h2>
          <div class="legal-row">
            <button mat-stroked-button (click)="openLegal('imprint')">
              <mat-icon>gavel</mat-icon>
              Impressum
            </button>
            <button mat-stroked-button (click)="openLegal('privacy')">
              <mat-icon>privacy_tip</mat-icon>
              Datenschutz
            </button>
            <button mat-stroked-button (click)="openLegal('terms')">
              <mat-icon>description</mat-icon>
              AGB
            </button>
          </div>
        </section>

        <mat-divider />

        <div class="version-row" style="margin-top:12px">
          <mat-icon style="font-size:16px;width:16px;height:16px">info</mat-icon>
          Work Time Manager · Version {{ appVersion }}
        </div>
      </mat-card-content>
    </mat-card>
  `,
})
export class AppSettingsComponent {
  private profileService = inject(UserProfileService);
  private toast = inject(ToastService);
  private dialog = inject(MatDialog);
  private http = inject(HttpClient);
  private fb = inject(FormBuilder);

  readonly saving = signal(false);
  readonly appVersion = APP_VERSION;

  private readonly p = this.profileService.profile();

  readonly form = this.fb.nonNullable.group({
    language: [this.p?.settings.language ?? 'de'],
    theme: [this.p?.settings.theme ?? 'system'],
    weeklyTargetHours: [this.p?.weeklyTargetHours ?? 40, [Validators.min(1), Validators.max(80)]],
    dailyTargetHours: [this.p?.dailyTargetHours ?? 8, [Validators.min(1), Validators.max(24)]],
    defaultPauseDuration: [this.p?.defaultPauseDuration ?? 30, [Validators.min(0), Validators.max(120)]],
  });

  openLegal(type: 'imprint' | 'privacy' | 'terms'): void {
    const titles = { imprint: 'Impressum', privacy: 'Datenschutzerklärung', terms: 'AGB' };
    const files = { imprint: 'imprint.md', privacy: 'privacy.md', terms: 'terms.md' };
    this.http.get(`assets/legal/${files[type]}`, { responseType: 'text' }).subscribe({
      next: content => {
        this.dialog.open(LegalDialogComponent, {
          data: { title: titles[type], content },
          maxWidth: '640px',
          width: '90vw',
        });
      },
      error: () => this.toast.error('common.error'),
    });
  }

  async save(): Promise<void> {
    if (this.form.invalid) return;
    this.saving.set(true);
    try {
      const { language, theme, weeklyTargetHours, dailyTargetHours, defaultPauseDuration } =
        this.form.getRawValue();

      await this.profileService.updateProfile({
        weeklyTargetHours,
        dailyTargetHours,
        defaultPauseDuration,
      });
      await this.profileService.updateSettings({ language, theme });

      this.form.markAsPristine();
      this.toast.success('common.save');
    } catch {
      this.toast.error('common.error');
    } finally {
      this.saving.set(false);
    }
  }
}
