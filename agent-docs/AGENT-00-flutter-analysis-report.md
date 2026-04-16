# Agent 0 — Flutter Analysis Report
# Work-Time-Manager (github.com/Riksorax/Work-Time-Manager, develop branch)
# Version: 0.24.1 | Analysiert: 2026-04-16

---

## 1. Tech Stack (Flutter)

| Bereich | Package | Version | Angular-Äquivalent |
|---|---|---|---|
| State | flutter_riverpod + riverpod_annotation | ^3.0.3 | Angular Signals |
| Auth | firebase_auth | ^6.1.3 | Firebase JS SDK v10 Auth |
| DB | cloud_firestore | ^6.1.1 | Firebase JS SDK v10 Firestore |
| Google Auth | google_sign_in | ^7.2.0 | GoogleAuthProvider |
| App Check | firebase_app_check | ^0.4.1+3 | reCAPTCHA v3 Provider |
| Premium | purchases_flutter + purchases_ui_flutter | ^9.10.2 | @revenuecat/purchases-js |
| Notifications | flutter_local_notifications + timezone | ^19.5.0 | Firebase Cloud Messaging (Web) |
| Lokalisierung | flutter_localizations | sdk | @ngx-translate/core |
| Persistenz | shared_preferences | ^2.5.4 | localStorage (Settings) |
| Logging | logger | ^2.6.2 | Console Service / NGX-Logger |
| UUID | uuid | ^4.5.2 | uuid npm package |
| Equatable | equatable | ^2.0.7 | TypeScript Interfaces |

---

## 2. Features & Premium-Gates (aus Issues + pubspec)

### Kostenlose Features (Free Tier)
- Arbeitszeiterfassung (Start / Stop / Pause / Resume)
- Tages-Übersicht mit aktuellem Timer
- Wochenübersicht (Summen)
- Session-Liste mit Basis-Filterung
- Manuelles Bearbeiten einzelner Sessions
- Benachrichtigungen (Erinnerungen)
- Profil-Einstellungen
- App-Einstellungen (Sprache, Theme)
- Google Sign-In + Email/Password Auth

### Premium Features (hinter RevenueCat-Gate)
- **Multi-Profile / Mehrere Arbeitgeber** (#138) — Mehrere Arbeitszeit-Profile gleichzeitig verwalten
- **Wochen-Reflexion** (#137) — Strukturierte Wochenrückblick-Funktion
- **Jahresberichte** (#136) — Jahresauswertung mit Charts
- **PDF-Export für Berichte** (#135) — Export als PDF-Datei
- **Detaillierte Berichte / Kategorie-Analyse** — Aufschlüsselung nach Kategorien
- **Intelligente Arbeitszeit-Insights** (#134) — KI-basierte Auswertungen (geplant)

---

## 3. Datenmodelle (Firestore-Schema abgeleitet)

### Collection: `users/{uid}`
```
UserProfile {
  uid: string
  email: string
  displayName?: string
  photoURL?: string
  isPremium: boolean
  premiumExpiresAt?: Timestamp
  weeklyTargetHours: number        // Standard: 40
  dailyTargetHours: number         // Standard: 8
  defaultPauseDuration: number     // Minuten, Standard: 30
  activeProfileId?: string         // für Multi-Profile (Premium)
  settings: {
    notificationsEnabled: boolean
    language: 'de' | 'en'
    theme: 'light' | 'dark' | 'system'
    workStartReminder?: string     // "08:00"
    workEndReminder?: string       // "17:00"
    fcmToken?: string
  }
  createdAt: Timestamp
  updatedAt: Timestamp
}
```

### SubCollection: `users/{uid}/workSessions/{sessionId}`
```
WorkSession {
  id: string                       // auto-generated
  userId: string
  profileId?: string               // für Multi-Profile (Premium)
  startTime: Timestamp             // Pflichtfeld
  endTime?: Timestamp              // null wenn Session läuft
  pauseDuration: number            // Gesamte Pausenzeit in Minuten
  pauseStartTime?: Timestamp       // null wenn nicht pausiert
  note?: string
  category?: string
  isRunning: boolean               // true = Timer läuft
  isPaused: boolean                // true = Timer pausiert
  createdAt: Timestamp
  updatedAt: Timestamp
}
```

### SubCollection: `users/{uid}/profiles/{profileId}` (Premium)
```
WorkProfile {
  id: string
  name: string                     // z.B. "Hauptarbeitgeber", "Nebenjob"
  color: string                    // Hex-Farbe
  weeklyTargetHours: number
  dailyTargetHours: number
  isDefault: boolean
  createdAt: Timestamp
}
```

---

## 4. Business-Logik (Berechnungen)

### 4.1 Nettoarbeitszeit berechnen
```
// Bruttozeit - Pausen = Nettoarbeitszeit
nettoMinutes = (endTime - startTime) in Minuten - pauseDuration
// Wenn Session noch läuft: endTime = now()
// Wenn Session gerade pausiert: pauseDuration += (now - pauseStartTime)
// Minimum: 0 (nie negativ)
```

### 4.2 Tages-Summe
```
tagesSumme = SUMME aller abgeschlossenen Sessions des Tages (nettoMinutes)
           + laufende Session (falls vorhanden)
```

### 4.3 Wochen-Summe
```
wochenSumme = SUMME aller Sessions der aktuellen Woche (Mo-So)
wochenSoll  = userProfile.weeklyTargetHours * 60
überstunden = wochenSumme - wochenSoll  (negativ = Unterzeit)
```

### 4.4 Monats-/Jahres-Summe (Premium)
```
// analog Wochen-Summe, aber für den Monat/das Jahr
```

### 4.5 Formatierung
```
formatDuration(minutes):
  h = floor(abs(minutes) / 60)
  m = abs(minutes) % 60
  prefix = minutes < 0 ? "-" : ""
  return "${prefix}${h}h ${m.toString().padStart(2,'0')}min"

// Beispiele:
// 510 → "8h 30min"
// -90 → "-1h 30min"
// 0   → "0h 00min"
```

---

## 5. Authentifizierung

- **Provider 1**: Email + Password (firebase_auth)
- **Provider 2**: Google Sign-In (google_sign_in + firebase_auth)
- **App Check**: Firebase App Check (Debug-Provider in Dev, Standard-Provider in Prod)
- **Flows**: Login, Register, Passwort vergessen (Reset-Email), Logout
- **Post-Login**: UserProfile in Firestore anlegen falls neu, sonst laden

---

## 6. Infrastruktur (bestehend)

- **Container**: Port **8080** (nginx intern)
- **Domain**: `work-time-manager.app`
- **Reverse Proxy**: Traefik mit Let's Encrypt
- **Network**: `traefik-proxy` (external Docker network)
- **Image**: `riksorax/work-time-manager:latest`
- **nginx**: SPA-Routing, Gzip, Cache-Headers, Security-Headers (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection)

---

## 7. Bekannte Bugs (aus Issues)

- #108: **Fehler beim Löschen der Arbeitszeiten** — Fehlerbehandlung beim Delete verbessern
- #107: **Einstellungen-Trennung** — App-Einstellungen von Profil-Einstellungen klar trennen
- #113: **Accessibility** — Screen-Reader-Support für Kalender

Diese Bugs sollen in der Angular-Version von Anfang an korrekt implementiert sein.

---

## 8. RevenueCat-Konfiguration (Web)

- **Package**: `@revenuecat/purchases-js`
- **Billing Engine**: RevenueCat Web Billing → Stripe als Payment Gateway
- **appUserId**: Firebase Auth UID (für cross-platform Entitlements Mobile ↔ Web)
- **Entitlement-ID**: `premium` (angenommen, muss in RevenueCat Dashboard verifiziert werden)
- **Offerings**: Monatlich + Jährlich (muss in RevenueCat Dashboard konfiguriert werden)
- **Wichtig**: Separater Web Billing Public API Key (nicht der mobile API Key)
- **Stripe**: Muss mit RevenueCat Dashboard verknüpft werden

---

## 9. Lokalisierung

- **Hauptsprache**: Deutsch (de)
- **Sekundärsprache**: Englisch (en)
- **Relevante Strings**: Alle UI-Labels, Fehlermeldungen, Zeitformate

---

## Zusammenfassung für nachfolgende Agents

Alle folgenden Agents nutzen diesen Report als einzige Quelle der Wahrheit für:
- Datenmodelle → Agent 3
- Business-Logik-Berechnungen → Agent 5
- Premium-Gates → Agent 7
- Infrastruktur-Konfiguration → Agent 11
- Bekannte Bugs: In Angular von Anfang an korrekt lösen
