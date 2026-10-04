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
│   ├── work-entry.ts      Hybrid — eingeloggt: Reads live via Firestore onSnapshot, Writes über ApiClient (Backend-API); ausgeloggt: localStorage. getAllLocalEntries() für DataSync. Optionales `profileId` (#380) bei `saveEntry(entry, profileId?)` / `getTodayEntry(profileId?)`: `undefined` = aktives Profil, sonst festes Profil (anonym ignoriert)
│   ├── overtime.ts        Hybrid — eingeloggt komplett über ApiClient (Reads + Writes), sonst localStorage. Optionales `profileId` (#380) bei `getOvertime`/`getLastUpdateDate`/`saveOvertime` (`undefined` = aktives Profil)
│   ├── settings.ts        Hybrid — wie work-entry.ts (Reads via Firestore onSnapshot, Writes via ApiClient). Feld `bundesland` (#279): Rohwert über `normalizeBundesland`; `""` ans Backend nur über `saveSettings(s, { clearBundesland: true })` (explizite Abwahl), sonst `null` = unangetastet
│   ├── api-client.ts      ApiClient — typisierter Client für die .NET-Backend-API (Endpunkte: `server/CLAUDE.md`), Token via authInterceptor
│   ├── work-profile.ts    WorkProfileService — aktives/zusätzliche Arbeitszeit-Profile (siehe #138/#244), profileId für ApiClient + Firestore-Pfade; Guard-Registry `registerSwitchGuard`/`requestSwitch` für interaktive Wechsel (#380)
│   ├── profile.ts         ProfileService — isPremium Signal (Firestore-Flag)
│   ├── today.ts           TodayService — lokaler Tages-Key (Signal `today`), Midnight-Timer, visibilitychange/focus/pageshow, Cleanup via DestroyRef (#372)
│   ├── theme.ts           ThemeService — isDarkMode Signal + localStorage-Persistenz
│   ├── leave-balance.ts   Hybrid — LeaveBalanceService: Jahres-Urlaubsübersicht (eingeloggt `ApiClient.getYearlyLeave`, anonym lokal via `calculateYearlyLeave`), `refresh()` nach Änderungen (#278)
│   ├── data-sync.ts       DataSyncService — localStorage→Firebase-Migration bei Login (Settings inkl. Bundesland: Cloud gewinnt, nie `""`)
│   └── web-premium.ts     WebPremiumService — RC Billing Paywall + Kauf-Wiederherstellung

domain/
├── models/
│   ├── reports.models.ts  DailyStat, WeeklyReport, MonthlyReport
│   └── leave.models.ts    YearlyLeaveReport (1:1 Backend-DTO)
├── services/
│   ├── break-calculator.ts   Pure — Pflichtpausen (30min/6h, 45min/9h)
│   ├── report-calculator.ts  Pure — ISO-8601-Wochennummer, DailyStat, Weekly/MonthlyReport
│   └── leave-calculator.ts   Pure — calculateYearlyLeave (Urlaubs-/Kranktage je Jahr, anonyme Nutzer)
└── utils/
    └── overtime.utils.ts  Pure — getEffectiveDailyTarget, getWeekEntriesForDate, isSameDay

features/
├── dashboard/      DashboardComponent + DashboardService (Timer, Pausen, Überstunden)
├── reports/        ReportsComponent + ReportsService (Täglich/Wöchentlich/Monatlich, Premium-Gate)
└── settings/       SettingsComponent + SettingsPageService (Profil, Arbeitszeit, Gleitzeit, Sync, Theme)

shared/
├── components/
│   ├── calendar/               CalendarComponent — Multi-Select + Pointer-Drag, Feiertags-Markierung per `bundesland`-Input (#371)
│   ├── edit-entry-dialog/      EditEntryDialogComponent
│   ├── leave-balance-card/     LeaveBalanceCardComponent — reine Darstellung der Urlaubsübersicht (Dashboard, Settings, Reports)
│   ├── holiday-banner/         HolidayBannerComponent — „Heute ist Feiertag: …“ (#279), rein informativ
│   ├── time-input/             TimeInputComponent
│   └── work-profile-switcher/  WorkProfileSwitcherComponent + Add-/Manage-Dialoge (siehe #138/#244)
├── utils/
│   ├── german-holidays.util.ts  Pure — gesetzliche Feiertage je Bundesland (#279), Port von Mobile `german_holidays.dart`
│   ├── bundesland.util.ts       Pure — isBundesland / normalizeBundesland
│   └── work-profile-path.util.ts  Pure — `profileScopedPath` (Firestore-Pfad je Profil), `profileIdForApi` (Profil-ID → API-Form, `'default'` → `undefined`, #380)
└── models/index.ts        WorkEntry, WorkEntryType, Break, UserSettings, UserProfile, WorkProfile
```

### Feature-Services (Pattern)

Jedes Feature hat einen eigenen `*.service.ts` der Core-Services aggregiert:

| Feature-Service | Aggregiert |
|---|---|
| `DashboardService` | WorkEntryService, OvertimeService, SettingsService, TodayService, AuthService, WorkProfileService |
| `ReportsService` | WorkEntryService, SettingsService, ProfileService, AuthService, OvertimeService, LeaveBalanceService |
| `SettingsPageService` | SettingsService, AuthService, ProfileService, OvertimeService, ThemeService, DataSyncService, LeaveBalanceService, WorkProfileService |

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

### Feiertage (#279)

`getGermanHolidayIds(year, bundesland)` liefert `Map<'YYYY-MM-DD', GermanHoliday>`. Berechnung ausschließlich über UTC-Felder
(Ostern, Buß- und Bettag), „heute“ über lokale Felder (`toDateKey`), nie `toISOString()` — TZ/DST-sicher. Parität mit der
Mobile-Fixture (`mobile/test/domain/utils/german_holidays_fixture.dart`, im Spec 1:1 übernommen, bei Änderungen dort manuell nachziehen).
`DashboardService.holidayToday` ist reiner Hinweis (Soll/Überstunden unberührt) und liest `TodayService.today()` (lokale Mitternacht, `visibilitychange`/`focus`/`pageshow`).
Der Kalender (Reports, Tab „Täglich“, #371) markiert Feiertage rein visuell (fett, `--mat-sys-error`, Unterstrich, `matTooltip`,
`aria-label` via `shared.calendarHolidayAria`); das Jahr kommt aus dem angezeigten Monat (`viewDate`), `ReportsService.bundesland`
reicht die Einstellung durch. Wochen-/Monatslisten sind nicht markiert, die Auswahlfarbe hat Vorrang.

### Tageswechsel (#372)

`TodayService.today()` ist die einzige Quelle für „heute“ im Dashboard. Beim Wechsel gilt (Variante B):
- **Laufender Timer** läuft über Mitternacht weiter, der Eintrag bleibt am Starttag; Soll und `isExtraDay` hängen am
  **Eintragsdatum** (`_targetDailyMs(settings, entry.date)`), nicht an „jetzt“. Autosave/Stop/Pause bleiben am Starttag.
  Nach dem Stop eines Vortagseintrags schaltet das Dashboard auf den neuen, leeren Tag um.
- **Gestoppter/leerer Eintrag** schaltet still auf den neuen Tag (`_init(uid, { dayChange: true })`, kein Speichern).
  Die Überstunden-Basis ist dann der gespeicherte Wert (ohne `calculateInitialOvertime`-Heuristik, `lastUpdated` ist nach
  einem Vortags-Save „heute“); Ausnahme: der geladene heutige Eintrag ist abgeschlossen und nach `workEnd` gespeichert.
- **Aktionen-Guard** `_ensureCurrentDay()` vor allen Schreibaktionen: ein gestoppter Vortagseintrag wird zuerst auf heute
  umgestellt, „Start“ nach Mitternacht schreibt nie in den Vortag. Liefert er `false` (Reinit überholt/fehlgeschlagen),
  bricht die Aktion ab; ein laufender anderer `_init` (Doppelklick, Login) wird vorher abgewartet (`_initRun`).
- `_init` hat einen Generationszähler (`_initGen`); überholte Läufe (Login, Tageswechsel) ändern weder Zustand noch Timer.
- Tests: feste lokale Daten + `vi.setSystemTime`, keine Zeitzonen-Annahme (lokal in Berlin/LA/Auckland/UTC prüfen).

### Profilwechsel (#380)

Das Dashboard lädt bei jedem Wechsel des Arbeitszeit-Profils (Header-Wechsler, Reload mit gemerktem Profil, `addProfile()`,
`deleteProfile(aktiv)`) vollständig für das neue Profil neu; nie darf etwas ins falsche Profil geschrieben werden.
- **Trigger** ist `WorkProfileService.activeProfileId$` (`distinctUntilChanged`), **nicht** ein Signal-Effect (`toObservable`
  hinkt dem Signal hinterher). Der Auth-Effect ruft `_init` in `untracked`, sonst abonniert er das Profil-Signal mit.
- `_loadedProfileId` = Profil der aktuell angezeigten Daten, synchron am Anfang jedes `_init` gesetzt. `_onProfileChange` ist
  idempotent (gleiches Profil → kein Lauf). Reads laufen mit explizitem Profil (`getTodayEntry(pid)`, `getOvertime(pid)`,
  `getLastUpdateDate(pid)`), nie „Eintrag A + Saldo B". Ein Profilwechsel ist nie ein stiller Tageswechsel (Ladezustand, Heuristik).
- **Schreibaktionen** halten Profil und `_initGen` zum Aktionsbeginn fest (`ActionCtx`) und schreiben Eintrag, dann Saldo
  (mit dem vor dem ersten `await` eingefrorenen Wert) explizit in dieses Profil (`saveEntry(entry, pid)`, `saveOvertime(ms, pid)`).
  Nach einer Überholung (Profilwechsel mitten in der Aktion) werden nur Folgeschritte (Timer-Start, Reinit) abgebrochen.
  Der Aktionen-Guard `_ensureCurrentDay` wartet zusätzlich auf einen laufenden Ladevorgang.
- **Timer wird eingefroren:** `_init` stoppt ihn ohne Speichern, der Eintrag bleibt im alten Profil laufend und läuft beim
  Zurückwechseln weiter. Autosave schreibt mit `_loadedProfileId`.
- `updateInitialOvertime(ms, profileId?)` schreibt in das übergebene Profil (Settings-Seite: das angezeigte), sonst ins geladene;
  `SettingsPageService` lädt den Saldo je Profil und verwirft überholte Antworten.
- Test-Helper `shared/testing/work-profile-fake.ts` (ohne `vi`: `tsconfig.app.json` kompiliert ihn mit `types: []` mit).
- `WorkProfileService.deleteProfile(aktiv)` wechselt zuerst ins Standard-Profil und ruft erst dann die API (kein Autosave
  mehr ins zu löschende Profil; bei API-Fehler Rückwechsel).
- **Guard-Hook (Stufe 2):** `WorkProfileService.registerSwitchGuard(guard): () => void` + `requestSwitch(id): Promise<boolean>`
  (Registry, der Core kennt keine Features). Guards laufen sequenziell vor dem Wechsel, `false`/Ausnahme/parallele Anfrage
  (`_switchPending`) = kein Wechsel. Nutzer: `DashboardService` (Constructor, nicht die Component: der Timer läuft auch ohne
  gerendertes Dashboard) fragt bei laufendem Timer über `ProfileSwitchConfirmService` (Dialog, `shared/components/work-profile-switcher/`,
  lazy per `Injector` aufgelöst), stoppt/speichert via `stopRunningTimerForSwitch` im alten Profil (Rollback bei Fehler, Snackbar)
  und wechselt erst danach. Interaktiv über Guard: Header-Wechsler (`requestSwitch`) und `addProfile()` (Guard VOR dem API-Aufruf,
  Rückgabe `null` = abgelehnt, nichts angelegt). **Bewusst ohne Guard:** `setActiveProfile`, `deleteProfile(aktiv)`, Reload mit
  gemerktem Profil, Logout (dort gilt das „Einfrieren").
- **Test-Falle (Vite 7.3 SSR-Transform, Ursache von #370/#380):** Steht ein importierter Wert direkt als Klassenfeld-Initializer
  (`x = IMPORTIERTE_KONSTANTE;`), hebt der Transform ihn als Schnappschuss `const X = import.X` vor die Klasse. Ist das Modul
  im Vollauf zu diesem Zeitpunkt noch nicht ausgewertet, ist der Wert `undefined` (nicht deterministisch, Einzellauf grün).
  Kein Importzyklus im Quelltext (`madge --circular`: 0). Abhilfe: Wert im Constructor zuweisen oder als Argument/Ausdruck
  einbetten (`[...X]`, `signal(X)`), nie als nackte Referenz.

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
