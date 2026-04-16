# Setup-Anleitung: Work-Time-Manager Angular Web

## Voraussetzungen

- Node.js 20+
- Angular CLI: `npm install -g @angular/cli`
- Firebase CLI: `npm install -g firebase-tools`
- Docker + Docker Compose
- Zugriff auf: Firebase Console, RevenueCat Dashboard, Stripe

---

## 1. Projekt initialisieren

```bash
# Repository erstellen (separates Repo oder Subfolder im bestehenden)
git init work-time-manager-web
cd work-time-manager-web

# Angular Projekt anlegen
ng new work-time-manager-web \
  --standalone \
  --routing \
  --style=scss \
  --ssr=false

# Alle generierten Files durch die Agent-Outputs ersetzen
```

---

## 2. Dependencies installieren

```bash
npm install \
  @angular/fire firebase \
  @angular/material @angular/cdk \
  @ngx-translate/core @ngx-translate/http-loader \
  @revenuecat/purchases-js \
  uuid

npm install --save-dev \
  @types/uuid
```

---

## 3. Firebase Konfiguration

### 3.1 Firebase Console
1. Projekteinstellungen → Web-App hinzufügen → Config kopieren → in `environment.ts`
2. Authentication → Sign-in methods: **Email/Password** + **Google** aktivieren
3. Firestore → `firestore.rules` aus diesem Projekt deployen:
   ```bash
   firebase deploy --only firestore:rules
   ```
4. App Check → Web-App → **reCAPTCHA v3** aktivieren → Site Key → `environment.ts`
5. Cloud Messaging → Web Push Zertifikat (VAPID Key) → `environment.ts`

### 3.2 reCAPTCHA v3
- Google reCAPTCHA Console: https://www.google.com/recaptcha/admin
- Neue Site erstellen → reCAPTCHA v3 → Domain `work-time-manager.app` + `localhost`
- Site Key → `environment.ts` (recaptchaSiteKey)
- Secret Key → Firebase App Check Console

---

## 4. RevenueCat Web Billing einrichten

### 4.1 RevenueCat Dashboard
1. **Neues Projekt** anlegen (oder bestehendes Flutter-Projekt nutzen)
2. **Web Billing Plattform** hinzufügen: Settings → Apps → Web Billing
3. **Stripe verbinden**: Billing → Connect Stripe Account
4. **Produkte anlegen**:
   - `wtm_premium_monthly` — Monatlich (Preis festlegen, z.B. 3,99 €)
   - `wtm_premium_yearly` — Jährlich (z.B. 29,99 €)
5. **Entitlement anlegen**: Entitlements → `premium` → beide Produkte zuordnen
6. **Offering anlegen**: Offerings → `default` → beide Produkte als Packages
7. **Public Web Billing API Key** kopieren → `environment.ts` (revenueCatWebBillingKey)

### 4.2 Wichtig: Cross-Platform Entitlements
Da als `appUserId` die **Firebase UID** genutzt wird:
- Mobile Flutter-App: `PurchasesConfiguration(<public_api_key>)` mit Firebase UID als User ID
- Angular Web-App: `Purchases.configure({ apiKey: ..., appUserId: firebaseUid })`
- **Ergebnis**: Premium auf Web = Premium auf Mobile (und umgekehrt)

### 4.3 Stripe Setup
- Stripe Account erstellen/verbinden
- Test-Modus: `4242 4242 4242 4242` als Testkarte
- Live-Modus: Erst nach Stripe-Verifizierung aktivieren

---

## 5. Lokale Entwicklung

```bash
# Environment befüllen (lokal manuell, nicht per envsubst)
cp src/environments/environment.ts src/environments/environment.local.ts
# Werte eintragen...

# Dev-Server starten
ng serve --open
# App läuft auf http://localhost:4200
```

---

## 6. Firestore Composite Indexes

Folgende Indexes müssen in der Firebase Console angelegt werden
(oder per `firebase.json` / CLI deployed werden):

```json
{
  "indexes": [
    {
      "collectionGroup": "workSessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isRunning", "order": "ASCENDING" },
        { "fieldPath": "startTime", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "workSessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "startTime", "order": "ASCENDING" },
        { "fieldPath": "startTime", "order": "DESCENDING" }
      ]
    }
  ]
}
```

> Tipp: Beim ersten Start erscheinen Firestore-Fehler mit direkten Links zum
> Index-Erstellen. Diese Links einfach aufrufen.

---

## 7. GitHub Secrets einrichten

In den Repository Settings → Secrets and Variables → Actions:

| Secret | Wert |
|---|---|
| `FIREBASE_API_KEY` | Aus Firebase Console |
| `FIREBASE_AUTH_DOMAIN` | `*.firebaseapp.com` |
| `FIREBASE_PROJECT_ID` | Firebase Projekt-ID |
| `FIREBASE_STORAGE_BUCKET` | `*.appspot.com` |
| `FIREBASE_MESSAGING_SENDER_ID` | Aus Firebase Console |
| `FIREBASE_APP_ID` | Aus Firebase Console |
| `RECAPTCHA_SITE_KEY` | Aus reCAPTCHA Console |
| `REVENUECAT_WEB_BILLING_KEY` | RevenueCat Dashboard |
| `FCM_VAPID_KEY` | Firebase Cloud Messaging |
| `GHCR_TOKEN` | GitHub Personal Access Token (write:packages) |
| `HETZNER_HOST` | IP oder Domain des Hetzner-Servers |
| `HETZNER_USER` | SSH-Benutzer |
| `HETZNER_SSH_KEY` | Privater SSH-Key (ohne Passphrase) |

---

## 8. Hetzner-Server vorbereiten

```bash
# Auf dem Server:
mkdir -p /opt/work-time-manager-web
cd /opt/work-time-manager-web

# docker-compose.yml kopieren (einmalig)
# Sicherstellen dass traefik-proxy Network existiert:
docker network create traefik-proxy 2>/dev/null || true
```

---

## 9. Deployment

```bash
# Push auf main → automatisches Deployment via GitHub Actions
git push origin main

# Manuell (auf Hetzner):
cd /opt/work-time-manager-web
IMAGE_TAG=latest docker compose up -d
```

---

## 10. Agent-Checkliste

- [ ] Agent 0: Flutter Analysis Report ✅ (AGENT-00-flutter-analysis-report.md)
- [ ] Agent 3: Firebase + App.config + Modelle ✅
- [ ] Agent 2: Security (Guards, Interceptor, Firestore Rules, nginx) ✅
- [ ] Agent 4: Auth (AuthService, Guards, Login/Register Komponenten) — Komponenten implementieren
- [ ] Agent 5: Time Tracking (WorkSessionService + Kalkulationen + Komponenten) ✅ (Services + Utils)
- [ ] Agent 6: Reports (ReportService + Komponenten) ✅ (Service)
- [ ] Agent 7: Premium/RevenueCat Web Billing ✅ (PremiumService)
- [ ] Agent 8: Notifications (FCM + Service Worker) ✅
- [ ] Agent 9: Settings (UserProfileService + Komponenten) ✅ (Service)
- [ ] Agent 10: Tests ✅ (time-calculations.util.spec.ts)
- [ ] Agent 11: CI/CD (Dockerfile, docker-compose, GitHub Actions, nginx) ✅
