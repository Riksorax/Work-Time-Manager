import { Component, inject, signal, effect } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { NotificationService } from '../../../../core/notifications/notification.service';
import { UserProfileService } from '../../../settings/services/user-profile.service';

@Component({
  selector: 'app-notification-settings',
  standalone: true,
  imports: [
    CommonModule, 
    ReactiveFormsModule, 
    MatCardModule, 
    MatSlideToggleModule, 
    MatFormFieldModule, 
    MatInputModule,
    MatButtonModule,
    MatIconModule
  ],
  template: `
    <div class="settings-container">
      <mat-card>
        <mat-card-header>
          <mat-card-title>🔔 Benachrichtigungen</mat-card-title>
        </mat-card-header>
        
        <mat-card-content>
          @if (unsupported()) {
            <div class="unsupported-msg">
              <mat-icon color="warn">warning</mat-icon>
              <p>Ihr Browser unterstützt keine Benachrichtigungen.</p>
            </div>
          } @else {
            <form [formGroup]="notiForm">
              <mat-slide-toggle formControlName="enabled" (change)="onMainToggle($event.checked)">
                Benachrichtigungen aktivieren
              </mat-slide-toggle>

              @if (notiForm.get('enabled')?.value) {
                <div class="reminder-settings">
                  <div class="reminder-row">
                    <mat-slide-toggle formControlName="startEnabled">Arbeitsbeginn-Erinnerung</mat-slide-toggle>
                    <mat-form-field appearance="outline">
                      <input matInput type="time" formControlName="startTime">
                    </mat-form-field>
                  </div>

                  <div class="reminder-row">
                    <mat-slide-toggle formControlName="endEnabled">Arbeitsende-Erinnerung</mat-slide-toggle>
                    <mat-form-field appearance="outline">
                      <input matInput type="time" formControlName="endTime">
                    </mat-form-field>
                  </div>

                  <button mat-stroked-button type="button" (click)="sendTest()">
                    <mat-icon>notifications_active</mat-icon> Test-Benachrichtigung senden
                  </button>
                </div>
              }
            </form>
          }

          @if (permissionDenied()) {
            <div class="denied-msg">
              <mat-icon color="warn">error</mat-icon>
              <p>Benachrichtigungen wurden blockiert. Bitte erlauben Sie diese in Ihren Browser-Einstellungen.</p>
            </div>
          }
        </mat-card-content>
      </mat-card>
    </div>
  `,
  styles: `
    .settings-container { display: flex; justify-content: center; padding: 1rem; }
    mat-card { width: 100%; max-width: 600px; }
    .reminder-settings { margin-top: 2rem; display: flex; flex-direction: column; gap: 1.5rem; }
    .reminder-row { display: flex; align-items: center; justify-content: space-between; gap: 1rem; }
    .unsupported-msg, .denied-msg { 
      margin-top: 1rem; padding: 1rem; background: #fff3e0; border-radius: 8px; 
      display: flex; align-items: center; gap: 1rem;
    }
    .denied-msg { background: #ffebee; }
    mat-form-field { width: 120px; }
  `
})
export class NotificationSettingsComponent {
  private fb = inject(FormBuilder);
  private notiService = inject(NotificationService);
  private profileService = inject(UserProfileService);

  unsupported = signal(!('Notification' in window));
  permissionDenied = signal(Notification.permission === 'denied');

  notiForm = this.fb.group({
    enabled: [false],
    startEnabled: [false],
    startTime: ['08:00'],
    endEnabled: [false],
    endTime: ['17:00']
  });

  constructor() {
    effect(() => {
      const p = this.profileService.profile();
      if (p) {
        // Initial-Werte laden (Mock-Mapping)
        // this.notiForm.patchValue({ ... });
      }
    });

    // Form-Changes abonnieren
    this.notiForm.valueChanges.subscribe(val => {
      if (val.enabled && val.startEnabled && val.startTime) {
        this.notiService.scheduleWorkStartReminder(val.startTime);
      } else {
        this.notiService.cancelReminder('work_start');
      }
      
      if (val.enabled && val.endEnabled && val.endTime) {
        this.notiService.scheduleWorkEndReminder(val.endTime);
      } else {
        this.notiService.cancelReminder('work_end');
      }
    });
  }

  async onMainToggle(checked: boolean) {
    if (checked) {
      const granted = await this.notiService.requestPermission();
      if (!granted) {
        this.notiForm.get('enabled')?.setValue(false);
        this.permissionDenied.set(Notification.permission === 'denied');
      }
    } else {
      this.notiService.clearAllReminders();
    }
  }

  sendTest() {
    this.notiService.sendTestNotification();
  }
}
