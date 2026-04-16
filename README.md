# Work-Time-Manager

Arbeitszeiterfassung mit Premium-Features. Zwei Plattformen, eine Firebase-Datenbank, geteilte RevenueCat-Entitlements.

---

## Repo-Struktur

```
work-time-manager/
├── mobile/                  # Flutter Mobile App
│   ├── lib/                 # Source — Clean Architecture (domain/data/presentation/core)
│   ├── test/                # Tests — Riverpod + Mockito
│   ├── android/             # Android platform files
│   ├── assets/              # Icons, Legal
│   ├── pubspec.yaml
│   ├── CLAUDE.md            # Architektur & Workflow-Regeln für Claude
│   └── thoughts/            # Ticket-Research + Pläne
│
├── web/                     # Angular Web-App (eigenständiges Projekt)
│   ├── angular.json
│   ├── tsconfig.json
│   ├── package.json
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── nginx.conf
│   ├── firestore.rules
│   ├── public/              # firebase-messaging-sw.js
│   └── src/
│       ├── app/             # Angular App (Core, Features, Layout, Shared)
│       ├── assets/i18n/     # de.json
│       ├── environments/
│       ├── styles/          # Material Theme (theme.scss)
│       ├── index.html
│       ├── main.ts
│       └── styles.scss
│
├── agent-docs/              # Bau-Dokumentation der Angular Web-App
│   ├── README.md            # Agent-Übersicht + Abhängigkeiten
│   ├── SETUP.md             # Infra-Setup (Firebase, RevenueCat, Hetzner, CI/CD)
│   ├── AGENT-00-flutter-analysis-report.md
│   └── AGENT-00 bis AGENT-11 (Anweisungen je Agent)
│
└── .claude/agents/          # Flutter-Workflow-Agents (Slash Commands)
    ├── README.md
    └── analyst / planner / developer / tester / ui-reviewer / reviewer
```

---

## Flutter Mobile App

**Stack:** Flutter · Riverpod · Firebase · RevenueCat (`purchases_flutter`)
**Architektur:** Clean Architecture (domain → data → presentation + core)
**Hybrid-Repos:** Firebase (eingeloggt) ↔ SharedPreferences (ausgeloggt)

### Commands

```bash
cd mobile
flutter run
flutter test
flutter analyze && dart run custom_lint
dart run build_runner build   # nach @riverpod-Änderungen
```

### Workflow

```
/analyze TICKET-123   → Phase 1: Analyst
/plan TICKET-123      → Phase 2: Planner
/implement TICKET-123 → Phase 3: Developer (TDD)
/validate TICKET-123  → Phase 4: Tester + UI-Reviewer
/review TICKET-123    → Phase 5: Reviewer + PR
```

Vollständige Regeln: [`mobile/CLAUDE.md`](mobile/CLAUDE.md)

---

## Angular Web-App

**Stack:** Angular 18 · Signals · Angular Material 3 · Firebase JS SDK v10 · RevenueCat Web Billing → Stripe
**Domain:** `app.work-time-manager.app` | **Infra:** Hetzner · Docker · Traefik

### Commands

```bash
cd web
npm install
npm start            # Dev-Server: http://localhost:4200
npm run build        # Produktions-Build
npm test             # Karma-Tests
```

### Agent-Status

| # | Agent | Status |
|---|---|---|
| 00 | Flutter Analyst | ✅ Report erstellt |
| 01 | Architect | ✅ Scaffold + Config erstellt |
| 02 | Security | ✅ Guards, Interceptors, Firestore Rules |
| 03 | Core / Foundation | 🔄 Services ✅ — Komponenten (Shell, Pipes, Shared) fehlen |
| 04 | Auth | 🔄 AuthService ✅ — Login/Register-Komponenten fehlen |
| 05 | Time Tracking | 🔄 Services + Utils ✅ — Dashboard/Timer-Komponenten fehlen |
| 06 | Reports | 🔄 ReportService ✅ — Report-Komponenten fehlen |
| 07 | Premium | 🔄 PremiumService ✅ — Paywall-Komponente fehlt |
| 08 | Notifications | 🔄 NotificationService ✅ — Settings-Komponente fehlt |
| 09 | Settings | 🔄 UserProfileService ✅ — Settings-Komponenten fehlen |
| 10 | Testing | ⬜ Offen |
| 11 | CI/CD | ✅ Dockerfile, docker-compose, GitHub Actions |

**Nächster Schritt:** Agent 03 — Shell-Layout, Shared Components, Pipes

Setup-Guide: [`agent-docs/SETUP.md`](agent-docs/SETUP.md)

---

## Geteilte Konfiguration

| Was | Detail |
|---|---|
| Firebase | Shared zwischen Flutter + Angular (gleiche UID = gleiche Daten) |
| RevenueCat | Firebase UID als `appUserId` → Cross-Platform Entitlements |
| Entitlement-ID | `premium` |
| Produkte | `wtm_premium_monthly` · `wtm_premium_yearly` |
