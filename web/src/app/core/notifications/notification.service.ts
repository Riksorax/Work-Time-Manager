// core/notifications/notification.service.ts
// Agent 8 — Notifications (FCM Web Push)

import { Injectable, inject } from '@angular/core';
import { Messaging, getToken, onMessage } from '@angular/fire/messaging';
import { environment } from '../../../environments/environment';
import { UserProfileService } from '../../features/settings/services/user-profile.service';

@Injectable({ providedIn: 'root' })
export class NotificationService {
  private messaging = inject(Messaging);
  private profileService = inject(UserProfileService);

  private reminderTimers: Map<string, ReturnType<typeof setTimeout>> = new Map();

  // ─── Permission & Token ───────────────────────────────────────────────────

  async requestPermission(): Promise<boolean> {
    if (!('Notification' in window)) {
      console.warn('[NotificationService] Browser unterstützt keine Notifications');
      return false;
    }

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return false;

    try {
      const token = await getToken(this.messaging, { vapidKey: environment.vapidKey });
      if (token) {
        await this.profileService.updateSettings({ fcmToken: token, notificationsEnabled: true });
      }
      return true;
    } catch (err) {
      console.error('[NotificationService] Token-Abruf fehlgeschlagen:', err);
      return false;
    }
  }

  async disableNotifications(): Promise<void> {
    this.clearAllReminders();
    await this.profileService.updateSettings({ notificationsEnabled: false, fcmToken: undefined });
  }

  // ─── Foreground Messages ──────────────────────────────────────────────────

  listenForMessages(): void {
    onMessage(this.messaging, payload => {
      if (!payload.notification) return;
      // Im Vordergrund: Browser Notification API nutzen
      new Notification(payload.notification.title ?? 'Work-Time-Manager', {
        body: payload.notification.body,
        icon: '/assets/icon/WorkTimeManagerLogo.png',
      });
    });
  }

  // ─── Lokale Reminder (analog flutter_local_notifications) ─────────────────

  scheduleWorkStartReminder(time: string): void {
    this.cancelReminder('work_start');
    const ms = this.msUntilNextTime(time);
    const timer = setTimeout(() => {
      this.showLocalNotification(
        '⏰ Arbeitsbeginn',
        `Es ist ${time} Uhr — Zeit, den Timer zu starten!`
      );
      // Täglich wiederholen
      this.scheduleWorkStartReminder(time);
    }, ms);
    this.reminderTimers.set('work_start', timer);
  }

  scheduleWorkEndReminder(time: string): void {
    this.cancelReminder('work_end');
    const ms = this.msUntilNextTime(time);
    const timer = setTimeout(() => {
      this.showLocalNotification(
        '🏁 Arbeitsende',
        `Es ist ${time} Uhr — vergiss nicht den Timer zu stoppen!`
      );
      this.scheduleWorkEndReminder(time);
    }, ms);
    this.reminderTimers.set('work_end', timer);
  }

  cancelReminder(type: 'work_start' | 'work_end'): void {
    const timer = this.reminderTimers.get(type);
    if (timer) {
      clearTimeout(timer);
      this.reminderTimers.delete(type);
    }
  }

  clearAllReminders(): void {
    this.reminderTimers.forEach(timer => clearTimeout(timer));
    this.reminderTimers.clear();
  }

  sendTestNotification(): void {
    this.showLocalNotification(
      '✅ Benachrichtigungen aktiv',
      'Deine Erinnerungen wurden erfolgreich eingerichtet.'
    );
  }

  // ─── Hilfsfunktionen ─────────────────────────────────────────────────────

  private showLocalNotification(title: string, body: string): void {
    if (Notification.permission === 'granted') {
      new Notification(title, {
        body,
        icon: '/assets/icon/WorkTimeManagerLogo.png',
        badge: '/assets/icon/WorkTimeManagerLogo.png',
      });
    }
  }

  /** Berechnet Millisekunden bis zur nächsten Trigger-Zeit (z.B. "08:00") */
  private msUntilNextTime(time: string): number {
    const [hours, minutes] = time.split(':').map(Number);
    const now = new Date();
    const target = new Date();
    target.setHours(hours, minutes, 0, 0);

    // Falls Zeitpunkt heute bereits vergangen: morgen planen
    if (target.getTime() <= now.getTime()) {
      target.setDate(target.getDate() + 1);
    }

    return target.getTime() - now.getTime();
  }
}
