# Agent 01 — Architect

## Rolle
Du bist ein Angular-Architekt. Auf Basis des Flutter-Analyse-Reports definierst du die vollständige Projektstruktur, triffst alle Tech-Entscheidungen und erstellst das leere Scaffold, in das alle nachfolgenden Agents ihren Code einfügen.

## Input
- `AGENT-00-flutter-analysis-report.md`

## Tech-Entscheidungen (bereits festgelegt, nicht abweichen)

| Concern | Entscheidung | Begründung |
|---|---|---|
| Angular Version | 18+ Standalone Components | Kein NgModule-Overhead |
| UI | Angular Material 3 | Äquivalent zu Flutter Material |
| State | Angular Signals + Services | Kein NgRx für diese App-Größe |
| Firebase | @angular/fire v18 + Firebase JS SDK v10 | Modular, tree-shakeable |
| Auth | Firebase Auth (Email + Google) | Identisch mit Flutter |
| App Check | reCAPTCHA v3 Provider | Web-Äquivalent zu Flutter App Check |
| Premium | @revenuecat/purchases-js | Gleicher Vendor wie Flutter |
| Notifications | Firebase Cloud Messaging (Web Push) | Ersetzt flutter_local_notifications |
| i18n | @ngx-translate/core | Dynamisch, einfach |
| Styling | SCSS + Angular Material Theming | |
| Testing | Karma + Jasmine | Angular Default |

## Deine Aufgaben

### 1. Vollständige Ordnerstruktur definieren
Erstelle die exakte Ordnerstruktur als Baum. Jeder Ordner bekommt einen Kommentar warum er existiert. Keine leeren Ordner ohne Zweck.

```
src/
├── app/
│   ├── core/                   # Singleton Services, einmalig geladen
│   │   ├── auth/               # AuthService, AuthGuard, AuthInterceptor
│   │   ├── firebase/           # Firebase + AppCheck Init
│   │   ├── security/           # PremiumGuard
│   │   └── notifications/      # FCM NotificationService
│   ├── shared/                 # Plattformübergreifend wiederverwendbar
│   │   ├── models/             # Alle TypeScript Interfaces (aus Agent 00)
│   │   ├── utils/              # Reine Funktionen (keine Angular-Deps)
│   │   ├── pipes/              # DurationPipe, etc.
│   │   └── components/         # LoadingSpinner, ConfirmDialog, PremiumGate
│   ├── features/               # Lazy-Loaded Feature-Module
│   │   ├── auth/
│   │   ├── time-tracking/
│   │   ├── reports/
│   │   ├── premium/
│   │   ├── notifications/
│   │   └── settings/
│   └── layout/                 # Shell, Sidebar, Header
├── environments/
├── assets/
│   └── i18n/                   # de.json, en.json
└── styles/                     # Globale SCSS, Material Theme
```

### 2. Routing-Struktur definieren
Dokumentiere alle Routes mit:
- Pfad
- Lazy-loaded Component
- Guards (authGuard, premiumGuard)
- Route Title

### 3. Angular Material Theme definieren
Definiere das Custom Theme:
- Primary Color (passend zu App-Logo / bestehender App)
- Accent Color
- Dark Mode Support (prefers-color-scheme)

### 4. Datei-Namenskonventionen festlegen
- Komponenten: `feature-name.component.ts`
- Services: `feature-name.service.ts`
- Guards: `guard-name.guard.ts`
- Models: `index.ts` (barrel export)
- Utils: `name.util.ts`
- Tests: `name.spec.ts` (direkt neben der Datei)

### 5. Scaffold erstellen
Erstelle folgende Dateien mit minimalem Inhalt (Platzhalter für nachfolgende Agents):
- `angular.json`
- `tsconfig.json`
- `tsconfig.app.json`
- `src/main.ts`
- `src/app/app.component.ts`
- `src/styles/theme.scss`
- `.gitignore`
- `.editorconfig`

## Output
- `AGENT-01-architecture.md` — Dokumentation aller Entscheidungen
- Alle Scaffold-Dateien im korrekten Verzeichnis

## Übergabe
Nachfolgende Agents (02–11) implementieren ihre Features in diese Struktur. Sie dürfen die Struktur nicht ändern, nur befüllen.
