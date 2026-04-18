import { Injectable, inject } from '@angular/core';
import { Messaging, getToken, onMessage } from '@angular/fire/messaging';
import { environment } from '../../../environments/environment';
import { UserProfileService } from '../../features/settings/services/user-profile.service';
import { ToastService } from '../../shared/components/toast/toast.service';
import { parse, addDays, differenceInMilliseconds } from 'date-fns';

@Injectable({
  providedIn: 'root'
})
export class NotificationService {
  private messaging = inject(Messaging);
  private profileService = inject(UserProfileService);
  private toast = inject(ToastService);

  private reminderTimers = new Map<string, any>();

  async requestPermission(): Promise<boolean> {
    try {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        const token = await getToken(this.messaging, {
          vapidKey: environment.fcmVapidKey
        });
        
        if (token) {
          await this.profileService.updateSettings({ 
            fcmToken: token, 
            notificationsEnabled: true 
          } as any);
          return true;
        }
      }
      return false;
    } catch (error) {
      console.error('Notification permission error:', error);
      this.toast.error('Benachrichtigungen konnten nicht aktiviert werden.');
      return false;
    }
  }

  listenForMessages() {
    onMessage(this.messaging, (payload) => {
      console.log('Foreground message received:', payload);
      if (payload.notification) {
        this.showLocalNotification(
          payload.notification.title || 'Benachrichtigung',
          payload.notification.body || ''
        );
      }
    });
  }

  scheduleWorkStartReminder(time: string) {
    this.scheduleReminder('work_start', time, 'Arbeitsbeginn', 'Zeit zum Einstempeln!');
  }

  scheduleWorkEndReminder(time: string) {
    this.scheduleReminder('work_end', time, 'Arbeitsende', 'Zeit für Feierabend!');
  }

  private scheduleReminder(id: string, time: string, title: string, body: string) {
    this.cancelReminder(id);
    
    const ms = this.msUntilNextTime(time);
    const timer = setTimeout(() => {
      this.showLocalNotification(title, body);
      this.scheduleReminder(id, time, title, body); // Für nächsten Tag
    }, ms);
    
    this.reminderTimers.set(id, timer);
  }

  cancelReminder(id: string) {
    if (this.reminderTimers.has(id)) {
      clearTimeout(this.reminderTimers.get(id));
      this.reminderTimers.delete(id);
    }
  }

  clearAllReminders() {
    this.reminderTimers.forEach(timer => clearTimeout(timer));
    this.reminderTimers.clear();
  }

  private showLocalNotification(title: string, body: string) {
    if (Notification.permission === 'granted') {
      new Notification(title, {
        body,
        icon: '/assets/icon/WorkTimeManagerLogo.png'
      });
    }
  }

  private msUntilNextTime(timeStr: string): number {
    const now = new Date();
    const [hours, minutes] = timeStr.split(':').map(Number);
    let target = new Date();
    target.setHours(hours, minutes, 0, 0);

    if (target <= now) {
      target = addDays(target, 1);
    }

    return differenceInMilliseconds(target, now);
  }

  async sendTestNotification() {
    this.showLocalNotification('Test', 'Dies ist eine Test-Benachrichtigung.');
  }
}
