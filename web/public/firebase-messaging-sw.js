// public/firebase-messaging-sw.js
// Agent 8 — Notifications
// Dieser Service Worker MUSS im /public (oder /src) Root liegen
// damit er unter /firebase-messaging-sw.js erreichbar ist

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

// Konfiguration wird zur Build-Zeit durch envsubst ersetzt
// WICHTIG: Nur nicht-sensitive Werte hier (apiKey ist öffentlich)
firebase.initializeApp({
  apiKey: '${FIREBASE_API_KEY}',
  authDomain: '${FIREBASE_AUTH_DOMAIN}',
  projectId: '${FIREBASE_PROJECT_ID}',
  storageBucket: '${FIREBASE_STORAGE_BUCKET}',
  messagingSenderId: '${FIREBASE_MESSAGING_SENDER_ID}',
  appId: '${FIREBASE_APP_ID}',
});

const messaging = firebase.messaging();

// Background Messages (wenn App nicht im Vordergrund)
messaging.onBackgroundMessage(payload => {
  console.log('[SW] Background message:', payload);

  const { title = 'Work-Time-Manager', body = '' } = payload.notification ?? {};
  const notificationOptions = {
    body,
    icon: '/assets/icon/WorkTimeManagerLogo.png',
    badge: '/assets/icon/WorkTimeManagerLogo.png',
    data: payload.data,
    actions: [
      { action: 'open', title: 'Öffnen' },
      { action: 'dismiss', title: 'Schließen' },
    ],
  };

  self.registration.showNotification(title, notificationOptions);
});

// Notification-Klick: App öffnen
self.addEventListener('notificationclick', event => {
  event.notification.close();
  if (event.action === 'dismiss') return;

  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(clientList => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/dashboard');
      }
    })
  );
});
