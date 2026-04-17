// DIESE DATEI NICHT IN GIT COMMITTEN
// Lokal: Werte aus Firebase Console eintragen
// CI/CD: Werte als GitHub Secrets hinterlegen, per envsubst injizieren

export const environment = {
  production: false,
  firebaseConfig: {
    apiKey: 'YOUR_DEV_API_KEY',
    authDomain: 'YOUR_PROJECT.firebaseapp.com',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT.appspot.com',
    messagingSenderId: 'YOUR_SENDER_ID',
    appId: 'YOUR_APP_ID',
  },
  recaptchaSiteKey: 'YOUR_RECAPTCHA_V3_SITE_KEY',
  revenueCatWebBillingKey: 'YOUR_RC_WEB_BILLING_SANDBOX_KEY',
  vapidKey: 'YOUR_FCM_VAPID_KEY',
  premiumEntitlementId: 'premium',
  // Spezifisches UUID aus Firebase Console → App Check → Debug-Tokens
  // Niemals auf true setzen (würde Token in Konsole loggen)
  appCheckDebugToken: '' as string | undefined,
};
