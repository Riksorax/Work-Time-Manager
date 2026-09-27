# CLAUDE.md — Web (Angular)

Ergänzt die Root-`CLAUDE.md` (Firestore-Datenpfade, Rechenregel, Key Rules).
Allgemeine Angular-/TypeScript-Regeln stehen in `AGENTS.md` (auch für andere Tools) und werden
hier importiert:

@AGENTS.md

## Commands (aus `web/`)

```bash
npm ci --legacy-peer-deps                     # Install
npm start                                     # Dev-Server http://localhost:4200
npm test -- --watch=false                     # Unit-Tests (Vitest); ohne --watch=false hängt der Runner
npm run build -- --configuration production   # wie CI
```

## Architektur (`web/src/app/`)

The Angular app is a full port of the Flutter app sharing the same Firebase backend.

### Layer Structure

```
core/
├── auth/           AuthService (Firebase Auth, Google Sign-In), AuthGuard
│                   — deleteAccount() via Firebase deleteUser()
├── services/
│   ├── work-entry.ts      Hybrid — eingeloggt: Reads live via Firestore onSnapshot, Writes über ApiClient (Backend-API); ausgeloggt: localStorage. getAllLocalEntries() für DataSync
│   ├── overtime.ts        Hybrid — eingeloggt komplett über ApiClient (Reads + Writes), sonst localStorage
│   ├── settings.ts        Hybrid — wie work-entry.ts (Reads via Firestore onSnapshot, Writes via ApiClient)
│   ├── api-client.ts      ApiClient — typisierter Client für die .NET-Backend-API (Endpunkte: `server/CLAUDE.md`), Token via authInterceptor
│   ├── work-profile.ts    WorkProfileService — aktives/zusätzliche Arbeitszeit-Profile (siehe #138/#244), profileId für ApiClient + Firestore-Pfade
│   ├── profile.ts         ProfileService — isPremium Signal (Firestore-Flag)
│   ├── theme.ts           ThemeService — isDarkMode Signal + localStorage-Persistenz
│   ├── data-sync.ts       DataSyncService — localStorage→Firebase-Migration bei Login
│   └── web-premium.ts     WebPremiumService — RC Billing Paywall + Kauf-Wiederherstellung

domain/
├── models/
│   └── reports.models.ts  DailyStat, WeeklyReport, MonthlyReport
├── services/
│   ├── break-calculator.ts   Pure — Pflichtpausen (30min/6h, 45min/9h)
│   └── report-calculator.ts  Pure — ISO-8601-Wochennummer, DailyStat, Weekly/MonthlyReport
└── utils/
    └── overtime.utils.ts  Pure — getEffectiveDailyTarget, getWeekEntriesForDate, isSameDay

features/
├── dashboard/      DashboardComponent + DashboardService (Timer, Pausen, Überstunden)
├── reports/        ReportsComponent + ReportsService (Täglich/Wöchentlich/Monatlich, Premium-Gate)
└── settings/       SettingsComponent + SettingsPageService (Profil, Arbeitszeit, Gleitzeit, Sync, Theme)

shared/
├── components/
│   ├── calendar/               CalendarComponent — Multi-Select + Pointer-Drag
│   ├── edit-entry-dialog/      EditEntryDialogComponent
│   ├── time-input/             TimeInputComponent
│   └── work-profile-switcher/  WorkProfileSwitcherComponent + Add-/Manage-Dialoge (siehe #138/#244)
└── models/index.ts        WorkEntry, WorkEntryType, Break, UserSettings, UserProfile, WorkProfile
```

### Feature-Services (Pattern)

Jedes Feature hat einen eigenen `*.service.ts` der Core-Services aggregiert:

| Feature-Service | Aggregiert |
|---|---|
| `DashboardService` | WorkEntryService, OvertimeService, SettingsService |
| `ReportsService` | WorkEntryService, SettingsService, ProfileService, AuthService, OvertimeService |
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

### Dark Mode

`ThemeService` verwaltet Hell/Dunkel. `app.ts` appliziert beim Start via `applyStoredTheme()` + `effect()` die Klasse `.dark-theme` auf `<html>`. SCSS-Override in `styles.scss` überschreibt dann das Angular Material M3-Theme.

### Daten-Synchronisation

`DataSyncService.syncAll()` liest alle localStorage-Einträge (via `WorkEntryService.getAllLocalEntries()` + `LS_KEYS`-Index) und schreibt sie nach Firebase. Wird manuell aus den Einstellungen getriggert.

## Web-Port-Workflow (5 Phasen)

Für neue Feature-Portierungen. Das Argument ist wie bei Mobile und Backend die GitHub-Issue-Nummer.
Arbeitsdateien: `web/thoughts/<nr>-research.md`, `-ui-report.md`, `-plan.md`, `-pr.md`
(per `.gitignore` lokal; die älteren `dashboard-*.md` stammen noch aus der Zeit der Feature-Namen).

Jede Phase läuft als Subagent (`.claude/agents/web-*.md`) in eigenem Kontext.

| Command | Phase |
|---|---|
| `/web-analyze <nr>` | Phase 1 — Issue lesen, Flutter-Feature analysieren, Feature-Ordner festlegen |
| `/web-design <nr>` | Phase 2 — UI entwerfen (Stitch API oder manuell) |
| `/web-plan <nr>` | Phase 3 — Implementierungsplan |
| `/web-implement <nr>` | Phase 4 — Code schreiben (TDD) |
| `/web-review <nr>` | Phase 5 — Review + PR |

Stitch API Key in `.claude/settings.local.json`: `{ "env": { "STITCH_API_KEY": "..." } }`
**Hinweis:** Stitch API ist aktuell nicht verfügbar (HTTP 405) — UI wird manuell nach Flutter-Vorlage designed.
