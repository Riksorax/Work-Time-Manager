# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a monorepo for a German work-time tracking app:

- `mobile/` — Flutter app (primary, production-ready). Has its own detailed `mobile/CLAUDE.md`.
- `web/` — Angular web app (feature-complete on `feature/angular-web-scaffold`).

For all Flutter/mobile work, refer to `mobile/CLAUDE.md` for commands, architecture details, and workflow rules.

## Mobile (Flutter) — Quick Reference

All commands run from inside `mobile/`:

```bash
flutter run
flutter test
flutter test test/path/to/file.dart
flutter analyze && dart run custom_lint
dart run build_runner build          # Regenerate .g.dart and .mocks.dart
flutter build appbundle --release \
  --dart-define=RC_ANDROID_KEY=<key> \
  --dart-define=RC_IOS_KEY=<key>
```

## Web (Angular) — Quick Reference

Commands run from inside `web/`:

```bash
npm ci --legacy-peer-deps            # Install
npm start                            # Dev-Server http://localhost:4200
npm run build -- --configuration production
```

## CI/CD

| Workflow | Trigger | Jobs |
|---|---|---|
| `flutter-production.yml` | Push to `main` | Android AAB → Google Play (Closed Testing) |
| `deploy-angular.yml` | Push to `main` oder `workflow_dispatch` | 1. Angular Build → 2. Docker Image → Docker Hub → 3. Deploy → Hetzner |
| `deploy-api.yml` | Push to `main` oder `workflow_dispatch` | 1. .NET Build & Test → 2. Docker Image → Docker Hub → 3. Deploy → Hetzner |
| `ci.yml` | PRs / Push | Lint & Tests |
| `version-bump.yml` | Push to `main` | Versionsnummer erhöhen |

**Web-Deployment Detail (`deploy-angular.yml`):**
- **Build**: Angular Production Build mit injizierten Firebase-Secrets
- **Docker**: Image `riksorax/work-time-manager-web` → Docker Hub (nur bei nicht-PR)
- **Deploy**: SSH auf Hetzner-Server, `docker compose up` (nur bei Push auf `main`)
- Manueller Trigger via `workflow_dispatch` baut & pusht Docker Image, deployt aber **nicht** (kein `main`-Branch)

**API-Deployment Detail (`deploy-api.yml`):**
- **Build & Test**: `dotnet build`/`dotnet test` gegen `server/WorkTimeManager.slnx`
- **Docker**: Image `riksorax/work-time-manager-api` → Docker Hub (nur bei nicht-PR)
- **Deploy**: SSH auf Hetzner-Server, `docker compose up` (nur bei Push auf `main`) — Firebase-Projekt-ID und Service-Account-Credential werden als GitHub Secrets per SSH-Session-Env injiziert (`appleboy/ssh-action` `envs:`), es liegt **keine** `.env`-Datei auf dem Server
- Manueller Trigger via `workflow_dispatch` baut & pusht Docker Image, deployt aber **nicht** (kein `main`-Branch)

**Required Secrets (Web):** `FIREBASE_API_KEY`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_PROJECT_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_APP_ID`, `FIREBASE_MEASUREMENT_ID`, `RC_WEB_KEY`, `DOCKERHUB_TOKEN`, `HETZNER_SSH_PRIVATE_KEY`

**Required Vars (Web):** `DOCKERHUB_USERNAME`, `HETZNER_HOST`, `HETZNER_USER`

**Required Secrets (API, zusätzlich):** `FIREBASE_PROJECT_ID` (geteilt mit Web), `FIREBASE_SERVICE_ACCOUNT_BASE64` (Base64-kodiertes Firebase-Service-Account-JSON für `worktime-56c7a`, Quelle: Firebase Console → Projekteinstellungen → Dienstkonten → "Neuen privaten Schlüssel generieren")

**Required Secrets (Flutter):** `RC_ANDROID_KEY`, `RC_IOS_KEY`, Android keystore secrets

## Mobile Architecture

Clean Architecture with three layers (`domain/`, `data/`, `presentation/`) and Riverpod for DI and state. Firebase Firestore for authenticated users; SharedPreferences as local fallback. **Hybrid Repository** pattern switches transparently based on auth state. See `mobile/CLAUDE.md` for full details.

## Web Architecture (`web/src/app/`)

The Angular app is a full port of the Flutter app sharing the same Firebase backend.

### Layer Structure

```
core/
├── auth/           AuthService (Firebase Auth, Google Sign-In), AuthGuard
│                   — deleteAccount() via Firebase deleteUser()
├── services/
│   ├── work-entry.ts      Hybrid Firebase/localStorage — getAllLocalEntries() für DataSync
│   ├── overtime.ts        Hybrid — getOvertime() / saveOvertime() / getLastUpdateDate()
│   ├── settings.ts        Hybrid — getSettings() Observable / saveSettings()
│   ├── profile.ts         ProfileService — isPremium Signal (Firestore-Flag)
│   ├── theme.ts           ThemeService — isDarkMode Signal + localStorage-Persistenz
│   ├── data-sync.ts       DataSyncService — localStorage→Firebase-Migration bei Login
│   └── web-premium.ts     WebPremiumService — RC Billing Paywall + Kauf-Wiederherstellung

domain/
├── models/
│   └── reports.models.ts  DailyStat, WeeklyReport, MonthlyReport
├── services/
│   ├── break-calculator.service.ts   Pure — Pflichtpausen (30min/6h, 45min/9h)
│   └── report-calculator.service.ts  Pure — ISO-8601-Wochennummer, DailyStat, Weekly/MonthlyReport
└── utils/
    └── overtime.utils.ts  Pure — getEffectiveDailyTarget, getWeekEntriesForDate, isSameDay

features/
├── dashboard/      DashboardComponent + DashboardService (Timer, Pausen, Überstunden)
├── reports/        ReportsComponent + ReportsService (Täglich/Wöchentlich/Monatlich, Premium-Gate)
└── settings/       SettingsComponent + SettingsPageService (Profil, Arbeitszeit, Gleitzeit, Sync, Theme)

shared/
├── components/
│   ├── calendar/          CalendarComponent — Multi-Select + Pointer-Drag
│   ├── edit-entry-dialog/ EditEntryDialogComponent
│   └── time-input/        TimeInputComponent
└── models/index.ts        WorkEntry, WorkEntryType, Break, UserSettings, UserProfile
```

### Feature-Services (Pattern)

Jedes Feature hat einen eigenen `*.service.ts` der Core-Services aggregiert:

| Feature-Service | Aggregiert |
|---|---|
| `DashboardService` | WorkEntryService, OvertimeService, SettingsService |
| `ReportsService` | WorkEntryService, SettingsService, ProfileService, AuthService, OvertimeService, ReportCalculatorService |
| `SettingsPageService` | SettingsService, AuthService, ProfileService, OvertimeService, ThemeService, DataSyncService |

### Key Angular-Regeln

- **Kein `standalone: true`** — Default in Angular v20+, nie explizit setzen
- **Signals-first**: `signal()` + `computed()` + `effect()`, öffentliche Signals via `.asReadonly()`
- **`inject()` statt Constructor-Parameter**
- **`@if` / `@for`** statt `*ngIf` / `*ngFor`
- **`ChangeDetectionStrategy.OnPush`** bei allen Components
- **Kein `color="primary/warn/accent"`** auf Material-Buttons (M3-deprecated)
- **Premium-Gate**: `ProfileService.isPremium` — kein RevenueCat (Web nutzt Firestore-Flag)
- **Kein `CommonModule`** — nur spezifische Imports (`DatePipe`, `AsyncPipe` etc.)

### Firebase / AngularFire-Regeln (kritisch)

AngularFire 20 bundelt **eigenes Firebase v11** in `node_modules/@angular/fire/node_modules/`. Das Projekt hat separat Firebase v12. Die Typen sind **inkompatibel** — niemals mischen:

```typescript
// ✅ RICHTIG — alles aus @angular/fire/*
import { Firestore, doc, onSnapshot, setDoc } from '@angular/fire/firestore';
import { Auth, authState } from '@angular/fire/auth';

// ❌ FALSCH — firebase/* und @angular/fire/* nie mischen
import { doc } from '@angular/fire/firestore';
import { onSnapshot } from 'firebase/firestore'; // anderes Modul-Bundle!
```

**`runInInjectionContext` für alle Firebase-Calls außerhalb des Constructors:**

```typescript
// Calls in switchMap / async-Callbacks benötigen runInInjectionContext
runInInjectionContext(this.injector, () => {
  unsub = onSnapshot(ref, snap => observer.next(snap.data()), err => observer.error(err));
});
```

**Nie `docData` / `collectionData` verwenden** — rxfire-Bug mit DocumentReference. Stattdessen eigene `new Observable(observer => { runInInjectionContext(...) })`.

### Firestore-Datenpfade (Flutter-kompatibel)

| Daten | Pfad | Felder |
|---|---|---|
| Arbeitseintrag | `users/{uid}/work_entries/{yyyy-MM}` | `days: { "5": { date, workStart, workEnd, breaks, ... } }` |
| Pause (in Eintrag) | (eingebettet in days-Map) | `{ name, start, end }` — Flutter ignoriert `id`/`isAutomatic` |
| Gleitzeit | `users/{uid}/overtime/balance` | `minutes` (int), `lastUpdated` (Timestamp) |
| Einstellungen | `users/{uid}/settings/current` | nur Web — Flutter nutzt SharedPreferences |
| Profil/Premium | `users/{uid}` | `isPremium` (bool) |

### Dark Mode

`ThemeService` verwaltet Hell/Dunkel. `app.ts` appliziert beim Start via `applyStoredTheme()` + `effect()` die Klasse `.dark-theme` auf `<html>`. SCSS-Override in `styles.scss` überschreibt dann das Angular Material M3-Theme.

### Daten-Synchronisation

`DataSyncService.syncAll()` liest alle localStorage-Einträge (via `WorkEntryService.getAllLocalEntries()` + `LS_KEYS`-Index) und schreibt sie nach Firebase. Wird manuell aus den Einstellungen getriggert.

## Web-Port Workflow (5 Phasen)

Für neue Feature-Portierungen:

| Command | Phase |
|---|---|
| `/web-analyze <feature>` | Phase 1 — Flutter-Feature analysieren |
| `/web-design <feature>` | Phase 2 — UI entwerfen (Stitch API oder manuell) |
| `/web-plan <feature>` | Phase 3 — Implementierungsplan |
| `/web-implement <feature>` | Phase 4 — Code schreiben (TDD) |
| `/web-review <feature>` | Phase 5 — Review + PR |

Stitch API Key in `.claude/settings.local.json`: `{ "env": { "STITCH_API_KEY": "..." } }`
**Hinweis:** Stitch API ist aktuell nicht verfügbar (HTTP 405) — UI wird manuell nach Flutter-Vorlage designed.

## Key Rules (Gesamt)

- `*.g.dart` / `*.mocks.dart` nicht editieren — generiert.
- `dart run build_runner build` nach `@Riverpod`-Änderungen.
- Alle User-Strings auf Deutsch — kein i18n-System.
- Premium-Features hinter `isPremiumProvider` (Flutter) bzw. `ProfileService.isPremium` (Web).
- Hybrid-Layer nie umgehen — immer über `WorkEntryService` / `OvertimeService`.
