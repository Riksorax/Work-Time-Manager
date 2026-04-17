import {
  ChangeDetectionStrategy,
  Component,
  inject,
  signal,
  computed,
} from '@angular/core';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatDividerModule } from '@angular/material/divider';
import { MatTooltipModule } from '@angular/material/tooltip';
import { TranslateModule } from '@ngx-translate/core';
import { NotificationService } from '../../../../core/notifications/notification.service';
import { UserProfileService } from '../../../settings/services/user-profile.service';
import { ToastService } from '../../../../shared/components/toast/toast.service';

const WEEKDAYS = [
  { iso: 1, label: 'Mo' },
  { iso: 2, label: 'Di' },
  { iso: 3, label: 'Mi' },
  { iso: 4, label: 'Do' },
  { iso: 5, label: 'Fr' },
  { iso: 6, label: 'Sa' },
  { iso: 0, label: 'So' },
];

@Component({
  selector: 'wtm-notification-settings',
  standalone: true,
  imports: [
    MatCardModule,
    MatButtonModule,
    MatIconModule,
    MatSlideToggleModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressSpinnerModule,
    MatDividerModule,
    MatTooltipModule,
    TranslateModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  styles: [`
    :host { display: block; padding: 16px; max-width: 600px; margin: 0 auto; }

    h1 { margin: 0 0 20px; font-size: 1.5rem; font-weight: 700; }

    .setting-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 0;

      .setting-label {
        display: flex;
        flex-direction: column;
        gap: 2px;
        label { font-size: 0.95rem; }
        span { font-size: 0.8rem; color: var(--mat-sys-on-surface-variant); }
      }
    }

    .time-row {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 8px 0;

      label { font-size: 0.875rem; color: var(--mat-sys-on-surface-variant); width: 180px; }
      mat-form-field { flex: 1; }
    }

    .weekday-row {
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
      padding: 8px 0 12px;

      button {
        min-width: 36px;
        width: 36px;
        height: 36px;
        border-radius: 50%;
        padding: 0;
        font-size: 0.75rem;
        font-weight: 600;
      }
    }

    .permission-banner {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px;
      background: var(--mat-sys-error-container);
      border-radius: 8px;
      margin-bottom: 16px;
      color: var(--mat-sys-on-error-container);
      font-size: 0.875rem;
    }
  `],
  template: `
    <h1>{{ 'settings.notifications.title' | translate }}</h1>

    @if (permissionDenied()) {
      <div class="permission-banner">
        <mat-icon>notifications_off</mat-icon>
        {{ 'settings.notifications.permissionDenied' | translate }}
      </div>
    }

    <mat-card appearance="outlined">
      <mat-card-content>
        <div class="setting-row">
          <div class="setting-label">
            <label>{{ 'settings.notifications.enable' | translate }}</label>
            <span>Browser-Benachrichtigungen</span>
          </div>
          <mat-slide-toggle
            [checked]="isEnabled()"
            (change)="toggleNotifications($event.checked)"
            [disabled]="saving()"
          />
        </div>

        @if (isEnabled()) {
          <mat-divider />

          <div class="time-row">
            <label>{{ 'settings.notifications.workStart' | translate }}</label>
            <mat-form-field appearance="outline" subscriptSizing="dynamic">
              <input
                matInput
                type="time"
                [value]="workStartTime()"
                (change)="onTimeChange('work_start', $any($event.target).value)"
              />
            </mat-form-field>
          </div>

          <div class="time-row">
            <label>{{ 'settings.notifications.workEnd' | translate }}</label>
            <mat-form-field appearance="outline" subscriptSizing="dynamic">
              <input
                matInput
                type="time"
                [value]="workEndTime()"
                (change)="onTimeChange('work_end', $any($event.target).value)"
              />
            </mat-form-field>
          </div>

          <mat-divider />

          <div class="setting-row">
            <div class="setting-label">
              <label>Pausenerinnerung</label>
              <span>Hinweis bei fälliger gesetzlicher Pause</span>
            </div>
            <mat-slide-toggle
              [checked]="breakReminderEnabled()"
              (change)="toggleBreakReminder($event.checked)"
            />
          </div>

          <mat-divider />

          <div class="setting-row" style="flex-direction:column;align-items:flex-start;gap:4px">
            <div class="setting-label">
              <label>Benachrichtigungs-Tage</label>
              <span>An welchen Tagen sollen Erinnerungen gesendet werden?</span>
            </div>
            <div class="weekday-row">
              @for (day of weekdays; track day.iso) {
                <button
                  mat-flat-button
                  [color]="isDayActive(day.iso) ? 'primary' : ''"
                  [style.opacity]="isDayActive(day.iso) ? '1' : '0.4'"
                  (click)="toggleDay(day.iso)"
                >{{ day.label }}</button>
              }
            </div>
          </div>

          <mat-divider />

          <div class="setting-row">
            <div class="setting-label">
              <label>{{ 'settings.notifications.testNotification' | translate }}</label>
            </div>
            <button mat-stroked-button (click)="sendTest()">
              <mat-icon>send</mat-icon>
              Test
            </button>
          </div>
        }
      </mat-card-content>
    </mat-card>
  `,
})
export class NotificationSettingsComponent {
  private notificationService = inject(NotificationService);
  private profileService = inject(UserProfileService);
  private toast = inject(ToastService);

  readonly saving = signal(false);
  readonly permissionDenied = signal(false);

  readonly weekdays = WEEKDAYS;

  readonly isEnabled = computed(
    () => this.profileService.profile()?.settings.notificationsEnabled ?? false
  );
  readonly workStartTime = computed(
    () => this.profileService.profile()?.settings.workStartReminder ?? '08:00'
  );
  readonly workEndTime = computed(
    () => this.profileService.profile()?.settings.workEndReminder ?? '17:00'
  );
  readonly breakReminderEnabled = computed(
    () => this.profileService.profile()?.settings.breakReminder ?? false
  );
  readonly activeDays = computed(
    () => this.profileService.profile()?.settings.notificationDays ?? [1, 2, 3, 4, 5]
  );

  isDayActive(iso: number): boolean {
    return this.activeDays().includes(iso);
  }

  async toggleNotifications(enable: boolean): Promise<void> {
    this.saving.set(true);
    this.permissionDenied.set(false);
    try {
      if (enable) {
        const granted = await this.notificationService.requestPermission();
        if (!granted) {
          this.permissionDenied.set(true);
          return;
        }
        const start = this.workStartTime();
        const end = this.workEndTime();
        if (start) this.notificationService.scheduleWorkStartReminder(start);
        if (end) this.notificationService.scheduleWorkEndReminder(end);
      } else {
        await this.notificationService.disableNotifications();
      }
    } catch {
      this.toast.error('common.error');
    } finally {
      this.saving.set(false);
    }
  }

  async onTimeChange(type: 'work_start' | 'work_end', time: string): Promise<void> {
    try {
      if (type === 'work_start') {
        await this.profileService.updateSettings({ workStartReminder: time });
        this.notificationService.scheduleWorkStartReminder(time);
      } else {
        await this.profileService.updateSettings({ workEndReminder: time });
        this.notificationService.scheduleWorkEndReminder(time);
      }
    } catch {
      this.toast.error('common.error');
    }
  }

  async toggleBreakReminder(enabled: boolean): Promise<void> {
    try {
      await this.profileService.updateSettings({ breakReminder: enabled });
    } catch {
      this.toast.error('common.error');
    }
  }

  async toggleDay(iso: number): Promise<void> {
    const current = this.activeDays();
    const next = current.includes(iso)
      ? current.filter(d => d !== iso)
      : [...current, iso];
    try {
      await this.profileService.updateSettings({ notificationDays: next });
    } catch {
      this.toast.error('common.error');
    }
  }

  sendTest(): void {
    this.notificationService.sendTestNotification();
  }
}
