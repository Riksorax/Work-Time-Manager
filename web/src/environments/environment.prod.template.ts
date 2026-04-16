// DIESES FILE WIRD VON CI/CD BEFÜLLT (envsubst)
// Platzhalter werden durch GitHub Secrets ersetzt
// Nicht manuell bearbeiten

export const environment = {
  production: true,
  firebaseConfig: {
    apiKey: '${FIREBASE_API_KEY}',
    authDomain: '${FIREBASE_AUTH_DOMAIN}',
    projectId: '${FIREBASE_PROJECT_ID}',
    storageBucket: '${FIREBASE_STORAGE_BUCKET}',
    messagingSenderId: '${FIREBASE_MESSAGING_SENDER_ID}',
    appId: '${FIREBASE_APP_ID}',
  },
  recaptchaSiteKey: '${RECAPTCHA_SITE_KEY}',
  revenueCatWebBillingKey: '${REVENUECAT_WEB_BILLING_KEY}',
  vapidKey: '${FCM_VAPID_KEY}',
  premiumEntitlementId: 'premium',
};
