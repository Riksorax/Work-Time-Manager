# Agent 08 — Notifications (FCM Web Push)

## Rolle
Du implementierst Web Push Notifications als Äquivalent zu `flutter_local_notifications`. Nutzer können Arbeitsbeginn- und Arbeitsende-Erinnerungen konfigurieren. Der Browser zeigt diese auch wenn die App im Hintergrund läuft.

## Input
- `AGENT-00-flutter-analysis-report.md` (Notification-Trigger, Reminder-Logik)
- Outputs von Agent 03 (UserProfileService, UserSettings-Modell)
- Outputs von Agent 04 (AuthService)

## Flutter → Angular Mapping

| Flutter | Angular/Web |
|---|---|
| `flutter_local_notifications` | Browser Notification API + FCM |
| `timezone` + scheduled notifications | `setTimeout` bis nächste Trigger-Zeit |
| `flutter_timezone` | Browser `Intl.DateTimeFormat().resolvedOptions().timeZone` |
| Notification-Channel | FCM Topic / Notification-Category |

## Technische Grundlagen

**Web Push funktioniert so:**
1. User erteilt Browser-Permission (`Notification.requestPermission()`)
2. FCM gibt einen Push-Token zurück (`getToken()`)
3. Token wird in Firestore gespeichert (`users/{uid}/settings.fcmToken`)
4. Service Worker empfängt Nachrichten im Hintergrund
5. Lokale Reminder via `setTimeout` (keine Server-Infrastruktur nötig)

**Einschränkung:** Lokale Reminder (`setTimeout`) funktionieren nur solange der Browser-Tab offen ist. Für zuverlässige Hintergrund-Notifications wäre FCM + Cloud Function nötig. In der aktuellen Version reicht `setTimeout` als MVP.

## Deine Aufgaben

### 8.1 Firebase Service Worker

Datei: `public/firebase-messaging-sw.js`

```javascript
importScripts('https://www.gstatic.com/firebasejs/10.x/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.x/firebase-messaging-compat.js');

firebase.initializeApp({ /* config via envsubst */ });
const messaging = firebase.messaging();

// Background Messages (App nicht im Vordergrund)
messaging.onBackgroundMessage(payload => {
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/assets/icon/WorkTimeManagerLogo.png',
    badge: '/assets/icon/WorkTimeManagerLogo.png',
    data: payload.data,
    actions: [
      { action: 'open', title: 'Öffnen' },
      { action: 'dismiss', title: 'Schließen' }
    ]
  });
});

// Klick auf Notification → App-Tab fokussieren oder öffnen
self.addEventListener('notificationclick', event => {
  event.notification.close();
  if (event.action === 'dismiss') return;
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(clientList => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin)) return client.focus();
      }
      return clients.openWindow('/dashboard');
    })
  );
});
```

**Wichtig:** Firebase-Config in diesem File wird per `envsubst` im CI/CD befüllt (kein hardcoding).

**Achtung Service Worker Caching:** nginx muss `/firebase-messaging-sw.js` mit `Cache-Control: no-cache` ausliefern (bereits in `nginx.conf` von Agent 02).

### 8.2 NotificationService

Datei: `src/app/core/notifications/notification.service.ts`

```typescript
@Injectable({ providedIn: 'root' })
export class NotificationService {
  private reminderTimers = new Map<string, ReturnType<typeof setTimeout>>()

  // ── Permission & Token ──────────────────────────────────
  async requestPermission(): Promise<boolean>
  // 1. Notification.requestPermission()
  // 2. Falls granted: getToken(messaging, { vapidKey })
  // 3. Token in Firestore speichern: updateSettings({ fcmToken: token, notificationsEnabled: true })
  // 4. return true/false

  async disableNotifications(): Promise<void>
  // clearAllReminders()
  // updateSettings({ notificationsEnabled: false, fcmToken: undefined })

  // ── Foreground Messages ─────────────────────────────────
  listenForMessages(): void
  // onMessage(messaging, payload => new Notification(...))
  // Wird einmalig in main.ts nach Bootstrap aufgerufen

  // ── Lokale Reminder ──────────────────────────────────────
  scheduleWorkStartReminder(time: string): void
  // time: "HH:mm" z.B. "08:00"
  // Berechne Millisekunden bis zur nächsten Trigger-Zeit
  // Falls Zeit heute bereits vergangen: morgen planen
  // setTimeout → showLocalNotification() → dann selbst nochmal schedulen (täglich)

  scheduleWorkEndReminder(time: string): void
  // Analog zu scheduleWorkStartReminder

  cancelReminder(type: 'work_start' | 'work_end'): void
  clearAllReminders(): void

  sendTestNotification(): void
  // Sofortige Test-Notification

  // ── Private ──────────────────────────────────────────────
  private showLocalNotification(title: string, body: string): void
  private msUntilNextTime(time: string): number
  // Berechne Millisekunden bis zur nächsten HH:mm Uhrzeit
}
```

### 8.3 Reminder-Wiederherstellung beim App-Start

In `AppComponent.ngOnInit()` oder via `effect()` auf `UserProfile`:

```typescript
effect(() => {
  const profile = userProfileService.profile();
  if (!profile?.settings.notificationsEnabled) return;

  if (profile.settings.workStartReminder) {
    notificationService.scheduleWorkStartReminder(profile.settings.workStartReminder);
  }
  if (profile.settings.workEndReminder) {
    notificationService.scheduleWorkEndReminder(profile.settings.workEndReminder);
  }
});
```

### 8.4 NotificationSettingsComponent

Route: `/settings/notifications`

```
┌───────────────────────────────────────────────────┐
│  🔔 Benachrichtigungen                             │
├───────────────────────────────────────────────────┤
│  [Toggle] Benachrichtigungen aktivieren            │
│                                                   │
│  Falls aktiviert:                                 │
│  Arbeitsbeginn-Erinnerung   [08:00]  [Toggle]    │
│  Arbeitsende-Erinnerung     [17:00]  [Toggle]    │
│                                                   │
│  [Test-Benachrichtigung senden]                   │
├───────────────────────────────────────────────────┤
│  Falls Browser keine Notifications erlaubt:       │
│  ⚠️ Bitte erlaube Benachrichtigungen in deinen   │
│     Browser-Einstellungen.                        │
└───────────────────────────────────────────────────┘
```

- Haupt-Toggle: ruft `requestPermission()` auf wenn aktiviert
- Uhrzeit-Inputs: `<input type="time">` (Browser-nativer Zeit-Picker)
- Änderungen sofort in Firestore speichern + Reminder neu planen
- Prüfe `Notification.permission` Status beim Laden der Komponente

### 8.5 Fehlerfälle behandeln

- **Permission denied**: Erklärungstext anzeigen + Link zu Browser-Einstellungen
- **Browser unterstützt keine Notifications**: Feature-Hinweis anzeigen (kein Fehler)
- **Token-Abruf schlägt fehl**: Toast-Fehler + Rollback des Toggles

## Output
- `public/firebase-messaging-sw.js`
- `src/app/core/notifications/notification.service.ts`
- `src/app/features/notifications/components/notification-settings/`

## Tests
- `notification.service.spec.ts`: Mock Notification API
  - `msUntilNextTime("08:00")`: korrekte Berechnung (heute noch vs. morgen)
  - `scheduleWorkStartReminder`: Timer wird gesetzt und täglich wiederholt
  - `cancelReminder`: Timer wird gecancelt
