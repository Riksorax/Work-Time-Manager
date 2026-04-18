# GitHub Secrets - Agent 11

The following secrets must be configured in GitHub Repository Settings -> Secrets and Variables -> Actions:

| Secret Name | Description | Source |
|---|---|---|
| `FIREBASE_API_KEY` | Firebase Web API Key | Firebase Console |
| `FIREBASE_AUTH_DOMAIN` | Firebase Auth Domain | Firebase Console |
| `FIREBASE_PROJECT_ID` | Firebase Project ID | Firebase Console |
| `FIREBASE_STORAGE_BUCKET` | Firebase Storage Bucket | Firebase Console |
| `FIREBASE_MESSAGING_SENDER_ID` | Firebase Messaging Sender ID | Firebase Console |
| `FIREBASE_APP_ID` | Firebase App ID | Firebase Console |
| `RECAPTCHA_SITE_KEY` | Google reCAPTCHA v3 Site Key | reCAPTCHA Admin Console |
| `REVENUECAT_WEB_BILLING_KEY` | RevenueCat Web Billing Public API Key | RevenueCat Dashboard |
| `FCM_VAPID_KEY` | Firebase Cloud Messaging VAPID Key | Firebase Console |
| `HETZNER_HOST` | Server IP or Domain | Hetzner Cloud |
| `HETZNER_USER` | SSH Deployment User | Server Config |
| `HETZNER_SSH_KEY` | Private SSH Key for Deployment | SSH Key Generation |

## Variables (Optional)
You can also set these as Variables if they are not sensitive:
- `HETZNER_HOST`
- `HETZNER_USER`
