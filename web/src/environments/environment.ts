export const environment = {
  production: false,
  apiUrl: 'http://localhost:5000',
  rcWebApiKey: '',
  // Sentry-DSN für Fehler-Tracking (siehe #207). Leer = Sentry bleibt
  // deaktiviert (lokale Entwicklung, CI).
  sentryDsn: '',
  firebase: {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_AUTH_DOMAIN",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_STORAGE_BUCKET",
    messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
    appId: "YOUR_APP_ID"
  }
};
