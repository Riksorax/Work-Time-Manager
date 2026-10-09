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
npm run e2e                                   # UI-/E2E-Tests (Playwright, #429), startet `ng serve` selbst
npm run e2e:chromium                          # nur Chromium (lokal ist nur dieser Browser vorinstalliert)
```

**UI-/E2E-Tests (`web/e2e/`, #429):** Playwright, Projekte `chromium`, `firefox`, `webkit`, `edge`,
`mobile-chrome`, `mobile-safari` (in CI je ein Matrix-Job). Die App läuft ohne Konto im localStorage-Modus,
es werden weder Firebase noch Backend benötigt. `fixtures.ts` setzt Sprache/Theme vor dem Boot. Geprüft werden
Laden ohne Konsolenfehler (je DE/EN, hell/dunkel), horizontaler Überlauf bei 320–1440 px, axe (WCAG A/AA,
serious/critical, nur Chromium) und Kernabläufe (Timer, Pausen, Navigation, Theme, Sprache). Neue Seiten in
`PAGES` ergänzen. Testdaten: `e2e/seed.ts` schreibt Einträge im `WorkEntryService`-localStorage-Format vor dem App-Start
(`seedEntries`, `workDay`, `openDay`) und friert die Uhr auf einen festen Tag (`freezeTime`, 2026-03-18), damit nichts
vom Ausführungsdatum abhängt. Abgedeckt: Kalender per Tastatur und Mehrfachauswahl (#377), Banner „Offene Einträge" (#385).
Tests mit Konto (`e2e/account.ts`, `profiles.spec.ts`: Profilwechsel #380/#388, Timer-Dialog, Anlegen/Löschen) laufen nur in
Chromium und nur mit `E2E_EMULATORS=1 npm run e2e:chromium` (Java 21; die Config startet Auth- und Firestore-Emulator über
`npx firebase-tools`, Projekt `demo-e2e`). Die App wird dafür mit `ng serve --configuration e2e` gebaut
(`environment.e2e.ts`: Emulator-Hosts, `apiUrl` `http://localhost:5100`; `app.config.ts` verbindet die Emulatoren nur, wenn
`useEmulators` gesetzt ist, und legt `window.__e2eSignIn` ab). Die .NET-API wird durch ein Fake-Backend (`page.route`) ersetzt,
das in dieselben Firestore-Dokumente schreibt, die die App per `onSnapshot` liest. Jeder Test legt einen eigenen Nutzer an.
Kontrast: Sekundärtext nie per `opacity`, sondern über `--mat-sys-on-surface-variant`.

## Architektur (`web/src/app/`)

The Angular app is a full port of the Flutter app sharing the same Firebase backend.

### Layer Structure

```
core/
├── auth/           AuthService (Firebase Auth, Google Sign-In), AuthGuard
│                   — deleteAccount() via Firebase deleteUser()
├── services/
│   ├── work-entry.ts      Hybrid — eingeloggt: Reads live via Firestore onSnapshot, Writes über ApiClient (Backend-API); ausgeloggt: localStorage. getAllLocalEntries() für DataSync. Optionales `profileId` (#380) bei `saveEntry(entry, profileId?)` / `getTodayEntry(profileId?)`: `undefined` = aktives Profil, sonst festes Profil (anonym ignoriert). `getEntriesForMonthOnce(year, month, profileId?)` (#385): Einmalabruf eines Monats (eingeloggt `ApiClient.getWorkEntriesForMonth`, ausgeloggt localStorage), Fehler werden geworfen
│   ├── overtime.ts        Hybrid — eingeloggt komplett über ApiClient (Reads + Writes), sonst localStorage. Optionales `profileId` (#380) bei `getOvertime`/`getLastUpdateDate`/`saveOvertime` (`undefined` = aktives Profil). `saveOvertime(ms, pid, { keepLastUpdated: true })` (#385, Backend ab PR #408) lässt `lastUpdated` unangetastet; das Feld geht nur eingeloggt und nur bei `true` in den Body
│   ├── settings.ts        Hybrid — wie work-entry.ts (Reads via Firestore onSnapshot, Writes via ApiClient). Feld `bundesland` (#279): Rohwert über `normalizeBundesland`; `""` ans Backend nur über `saveSettings(s, { clearBundesland: true })` (explizite Abwahl), sonst `null` = unangetastet. `getSettingsOnce(profileId?)` (#385): Einmalabruf mit festem Profil (kein Lag-Fenster), `mergeSettings` wie bei `getSettings()`
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
    ├── overtime.utils.ts  Pure — getEffectiveDailyTarget, getWeekEntriesForDate, isSameDay
    └── open-entry.utils.ts  Pure (#385) — Soll-Ende/Vorschlag, gültiges Ende, Saldo-Delta, Tag aus der Eintrags-`id`, Datumsformat

features/
├── dashboard/      DashboardComponent + DashboardService (Timer, Pausen, Überstunden); `OpenEntryService` + `OpenEntryCloseService` + Beenden-Dialog (offene Einträge vor heute, #385)
├── reports/        ReportsComponent + ReportsService (Täglich/Wöchentlich/Monatlich, Premium-Gate); Mehrfachauswahl-Modus im Service: `toggleMultiSelect`, idempotentes `endMultiSelect`, `removeDatesFromSelection`, Modus endet nach erfolgreichem Batch-Speichern (#377)
└── settings/       SettingsComponent + SettingsPageService (Profil, Arbeitszeit, Gleitzeit, Sync, Theme)

shared/
├── components/
│   ├── calendar/               CalendarComponent — Multi-Select + Pointer-Drag, Feiertags-Markierung per `bundesland`-Input (#371), Tastaturbedienung (#377): ARIA `grid > row > gridcell`, Roving tabindex, Pfeile/Home/End/PageUp/PageDown, Enter/Space (Fokus folgt nicht der Auswahl, `event.repeat` ignoriert). Mehrfachauswahl per Tastatur (#377): Toggle-Button im Reports-Kalender-Panel (`ReportsService` besitzt den Modus), Shift+Pfeil/Home/End/PageUp/PageDown wählen einen Bereich ab Anker (Anker/Base im Kalender, `daysDeselected` beim Verkleinern/Umkehren, vorher gewählte Tage bleiben), Escape (`multiSelectEnded`) beendet den Modus, `aria-multiselectable`, im aktiven Modus keine Einzelauswahl-Darstellung; `LiveAnnouncer` (polite) sagt Modus an/aus und nur nach Tastaturaktionen die Anzahl an. Kein Shift+Klick, kein Ctrl+Shift+Home/End
│   ├── edit-entry-dialog/      EditEntryDialogComponent
│   ├── leave-balance-card/     LeaveBalanceCardComponent — reine Darstellung der Urlaubsübersicht (Settings, Reports; bewusst nicht im Dashboard: dort schob sie Start-/Endzeit und den Start-Button unter den sichtbaren Bereich)
│   ├── holiday-banner/         HolidayBannerComponent — „Heute ist Feiertag: …“ (#279), rein informativ
│   ├── open-entry-banner/      OpenEntryBannerComponent — Hinweis auf offenen Eintrag vor heute mit „Beenden“/„Später“ und optional „Fortsetzen“ (#385), rein darstellend
│   ├── time-input/             TimeInputComponent
│   └── work-profile-switcher/  WorkProfileSwitcherComponent + Add-/Manage-Dialoge (siehe #138/#244)
├── utils/
│   ├── german-holidays.util.ts  Pure — gesetzliche Feiertage je Bundesland (#279), Port von Mobile `german_holidays.dart`
│   ├── bundesland.util.ts       Pure — isBundesland / normalizeBundesland
│   ├── promise-timeout.util.ts  Pure (#426) — `withTimeout(promise, ms)` + `PromiseTimeoutError`, Timer immer mit `clearTimeout`
│   ├── calendar-keyboard.util.ts  Pure — Kalender-Tastenlogik (#377): `isCalendarNavKey`, `nextFocusDate`, `rangeKeys`, `rangeDiff`
│   └── work-profile-path.util.ts  Pure — `profileScopedPath` (Firestore-Pfad je Profil), `profileIdForApi` (Profil-ID → API-Form, `'default'` → `undefined`, #380)
└── models/index.ts        WorkEntry, WorkEntryType, Break, UserSettings, UserProfile, WorkProfile
```

### Feature-Services (Pattern)

Jedes Feature hat einen eigenen `*.service.ts` der Core-Services aggregiert:

| Feature-Service | Aggregiert |
|---|---|
| `DashboardService` | WorkEntryService, OvertimeService, SettingsService, TodayService, AuthService, WorkProfileService |
| `OpenEntryService` | AuthService, WorkProfileService, TodayService, WorkEntryService, SettingsService, DashboardService, OpenEntryCloseService |
| `OpenEntryCloseService` | WorkEntryService, OvertimeService, SettingsService |
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
- **Laufender Timer** läuft über Mitternacht weiter (ein laufender Vortag kommt auch über „Fortsetzen" ins Dashboard, #385), der Eintrag bleibt am Starttag; Soll und `isExtraDay` hängen am
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

### Offene Einträge vor heute (#385)

Ein über Mitternacht gelaufener Timer bleibt nach einem Reload als Eintrag mit Start und ohne Ende am Vortag stehen
(das Dashboard lädt nur „heute“). Das Dashboard zeigt unter dem Feiertagsbanner einen nicht-modalen Banner für den
neuesten offenen Eintrag vor heute (Ursache und Mobile-Vorlage: PR #405). Ohne Nutzeraktion ändert sich nichts.
- **Suche** (`OpenEntryService`, `features/dashboard/open-entry.ts`): aktives Profil, aktueller und Vormonat (`new Date(y, m-2, 1)`,
  Januar → Dezember Vorjahr), je Monat eigenes try/catch, über `WorkEntryService.getEntriesForMonthOnce`. Filter: Typ work, Start
  gesetzt, kein Ende, `id`-Tag < heute (`TodayService.today()`, String-Vergleich), nicht der im Dashboard angezeigte Eintrag
  (laufender Vortag, #372). Trigger: Auth (erst nach der ersten Emission), Profil, Tag, Eintragswechsel im Dashboard. Ein
  Kontext-Epoch (Nutzer/Profil) und eine Suchsequenz verwerfen überholte Ergebnisse.
- **Tag immer aus der `id`**, nie aus `date`: `date` ist beim Web UTC-Mitternacht und ergibt westlich von UTC den Vortag. Beim
  Zurückschreiben wird `date` auf das lokale Datum aus der `id` gesetzt (`localDateFromEntryId`). Die bestehende `date`-Nutzung
  im Dashboard ist nicht Teil davon (#407).
- **„Später“:** blendet alle Kandidaten des aktuellen Nutzers und Profils für die Sitzung aus; Schlüssel `uid|profileId|yyyy-MM-dd`
  (ausgeloggt `anon`), nicht persistent (Reload zeigt wieder an).
- **Beenden** (`OpenEntryCloseService`, `open-entry-close.ts`): alle Zugriffe mit dem Profil des Kandidaten (`profileId` je Aktion,
  #380-Semantik): Einstellungen des Profils (`getSettingsOnce`), Monat frisch lesen (nicht mehr offen ⇒ `alreadyClosed`), Ende mit
  frischer Uhr prüfen (`isValidOpenEntryEnd`), offene Pausen zum Ende schließen, `calculateAndApplyBreaks`, Saldo
  `alt + Netto − Soll(Eintragstag) + manualOvertimeMinutes`, **erst Saldo, dann Eintrag**; schlägt der Eintrag-Write fehl, wird der
  Saldo best-effort zurückgesetzt (Rollback, sonst zählt ein Wiederholen doppelt). Der Saldo geht eingeloggt mit
  `keepLastUpdated: true`, ausgeloggt wird `saveLastUpdateDate` nie aufgerufen. Ergebnis: `closed | alreadyClosed | invalidEnd |
  invalidEntry | failed | busy`.
- **`DashboardService.reloadAfterRetroClose(pid)`:** zieht die Saldo-Basis neu (no-op bei anderem Profil). Läuft im Dashboard ein
  Vortag über Mitternacht, läuft kein `_init` (er würde den Timer verwerfen), es wird nur die Basis erneuert; sonst stiller Reload
  (`dayChange`). Richtung der Abhängigkeit: `OpenEntryService` → `DashboardService`, nie umgekehrt.
- **Abweichung zu Mobile:** `manualOvertimeMinutes` wird eingerechnet (wie beim Dashboard-Stop). Den Saldo-Rollback bei
  Eintrag-Fehler hat Mobile seit #410 ebenfalls. `keepLastUpdated` sendet Mobile seit #406 ebenfalls (`CloseOpenWorkEntry`, Body nur bei `true`).
- **Grenzen:** Einträge älter als der Vormonat und andere Profile werden nicht gefunden, kein Re-Check beim Zurückkehren in den
  Tab, Reports-Darstellung offener Einträge #404. „Fortsetzen" gibt es nur für den neuesten Eintrag, nur bei leerem heutigem Tag
  und höchstens 24 h Alter; eine Ablehnung bleibt still (ohne Text, der Banner wird neu gesucht). Ein Service-Aufruf in der
  Ladelücke des Pins (z. B. `startOrStopTimer`) wartet auf den Pin und stoppt danach den gepinnten Lauf; im UI ist das wegen des
  Spinners nicht erreichbar.
- **Fortsetzen (Web-Parität zu Mobile PR 1b #422):** Der Banner bietet für den **neuesten** sichtbaren Kandidaten „Fortsetzen" an
  (`OpenEntryService.canResume`, Button Später Text / Beenden stroked / Fortsetzen flat; ohne `canResume` bleibt das alte Aussehen).
  - **Regel** `canResumeOpenEntry({ entry, now, todayId, todayIsEmpty })` (`domain/utils/open-entry.utils.ts`): Typ work, Start, kein
    Ende, `id` < heute, Alter ≤ 24 h (inklusiv), heute leer. Einzige Regel für Anzeige und Durchsetzung (Tap prüft mit frischer Uhr neu).
  - **`DashboardService.todayIsEmpty`** = nicht ladend **und** `_loadOk` (letzter `_initInner` fehlerfrei; nach einem Fehler ist
    `status` ebenfalls `ready`) **und** angezeigt wird heute, Typ work, kein Start. Heutiger Urlaub/Krank ist nicht „leer".
  - **Pinning:** `resumePastEntry(entry, pid)` wartet auf laufende `_init`, prüft dann synchron (Profil, `todayIsEmpty`, Regel) und
    startet `_init(uid, { pinned: { id } })` ohne dazwischenliegendes `await`. `_initInner` liest den Monat frisch
    (`getEntriesForMonthOnce`), validiert erneut (offen, ≤ 24 h) und setzt `date` auf das lokale Datum aus der `id` (UTC-Falle). Lesefehler
    oder ungültiger Eintrag fallen auf den normalen Pfad für heute zurück (Dashboard bleibt geladen, Ergebnis `false`). Die Saldo-Basis
    ist der gespeicherte Saldo (`storedBase = dayChange || pinned`, nicht die `lastUpdated`-Heuristik); der Zustand wird zurückgesetzt
    (Spinner). `_pinnedGen === _initGen` entscheidet über `true`; danach sofortiger `_tick()`. Kein Write, kein `ActionCtx`
    (Überholung über `_initGen`); Timer, Stop, Mitternacht laufen unverändert nach #372.
  - **`OpenEntryService.resume(candidate)`:** `busy`-Guard, Regel erneut, `await resumePastEntry`; Erfolg entfernt den Kandidaten und
    erhöht `closedCount` (Fokus), Ablehnung erhöht `_clockTick` und sucht still neu. **Flash-Schutz:** wechselt die Dashboard-Id,
    wird der vorherige Tag synchron aus den Kandidaten entfernt (nach Pin, Stop und Reinit sonst kurz wieder als Banner sichtbar).
  - **`busy`-Härtung:** Reset nur bei unverändertem Kontext-Epoch (auch für `endEntry`), der Kontextwechsel setzt `busy` selbst zurück.
  - Texte: `dashboard.openEntryContinue`, `dashboard.openEntryContinueSemantics` (`aria-label` mit Datum, ohne `aria-describedby`).
    Fortsetzen löst keine zusätzliche Ansage aus.
- **Deploy-Reihenfolge: API vor Clients (Web und Mobile).** `keepLastUpdated` kommt aus Backend-PR #408. Eine ältere API ignoriert das Feld; Beenden
  funktioniert dann, setzt aber `lastUpdated` (altes Verhalten), und die Heuristik im Dashboard kann im Fall „beenden, heute
  arbeiten, neu laden“ eine falsche Basis liefern. (Bestehend und nicht Teil davon: der Kommentar in
  `DashboardService.updateInitialOvertime` („kein lastUpdated-Update“) trifft eingeloggt ebenfalls nicht zu.)
- **A11y:** Textblock `role="status"`, Buttons per `aria-describedby` auf den Titel, einmalige polite `LiveAnnouncer`-Ansage je
  Eintrag, nach dem Entfall Fokus auf den nächsten Banner bzw. den Anker `p.timer-label` (`tabindex="-1"`, kein Zusatztext).

### Reentranz-Sperre (#426)

Web-Pendant zu Mobile #413 (`mobile/CLAUDE.md`, „Reentranz-Sperre (#413)“). Überlappende Schreibaktionen im `DashboardService`
(Doppel-Start, Doppel-Stop, Tap im Ladefenster, Tap während des Autosaves, Stop parallel zum Profil-Guard) wurden vorher
nicht serialisiert. Jetzt gilt:
- **Verwerfen statt Queue:** `_runAction(body, discarded)` umschließt `startOrStopTimer`, `startNewSession`, `startOrStopBreak`,
  `setManualStartTime`, `setManualEndTime`, `clearEndTime`, `updateBreak`, `deleteBreak` (Rumpf in `_xxxBody`) und
  `stopRunningTimerForSwitch`. Läuft schon eine Aktion, liefert der zweite Aufruf sofort `undefined` (bei
  `stopRunningTimerForSwitch` `false`): kein Fehler, kein Zustand, kein zweiter Restart-Dialog. Prüfen und Setzen der Sperre
  geschehen **synchron vor dem ersten `await`** (`_busy`); Fehler des Bodys erreichen den Aufrufer unverändert, die Sperre ist danach frei.
- **Besitz über ein Token** (`_actionToken`): das `finally` gibt die Sperre nur frei, wenn sie noch der eigenen Aktion gehört.
  `_initInner` setzt sie **nur bei echtem Profilwechsel** zurück (`profileChanged`): ein Tap im neuen Profil wird nicht verworfen,
  nur weil im alten ein Write hängt, und die alte Aktion löscht die neue Sperre nie. Tageswechsel, Login/Logout, Retro-Close und
  „Fortsetzen“ lösen sie nicht (die Aktion schreibt im Profil des Aktionsbeginns zu Ende).
- **`isSaving`** ist ein eigenes Signal im Service (`_saving`, Spiegel von `_busy`), **nicht** in `DashboardState`: ein Reinit
  mitten in der Aktion darf die UI nicht entsperren.
- **Autosave:** startet nie während einer Aktion oder eines laufenden Autosaves (`_autoSaveRun`); der Zähler bleibt dann stehen
  und der nächste Tick versucht es erneut (kein 30-s-Loch). Eine Aktion wartet vor ihren Writes auf einen laufenden Autosave
  (er überholt den frischen Eintrag nie).
- **Timeouts je Write-Block, 30 s** (`withTimeout` aus `shared/utils/promise-timeout.util.ts`, `PromiseTimeoutError`): Eintrag-Write
  (`_recalculateState`), Saldo-Block (`saveOvertime` + `saveLastUpdateDate` als EIN Block, lokales `timedOut`-Flag: nach dem
  Timeout wird `lastUpdated` nicht mehr nachgeholt) und Autosave (still). Ein Timeout ist ein Schreibfehler (Rejection). Ein
  aufgegebener Write ist nicht abbrechbar und kann später landen („unbekannter Ausgang“; der Saldo ist absolut, Wiederholen
  überschreibt; keine Heilung nach spätem Landen). Das Timeout-Limit ist ein Literal-Feld (`_writeTimeoutMs = 30_000`), keine
  importierte Konstante (Vite-SSR-Falle, siehe „Test-Falle“). Worst Case einer Stop-Aktion: Autosave 30 + Eintrag 30 + Saldo 30 + Saldo (Duplikat, siehe unten) 30 s.
- **`stopRunningTimerForSwitch`** wartet auf `_actionDone` (nie rejected) und läuft danach **ohne weiteres `await`** in
  `_runAction(body, false)` (ein `await` dazwischen wäre ein Fenster für einen Doppel-Stop). **`resumePastEntry`** liefert `false`,
  solange eine Aktion läuft (Prüfung vor und nach der Ladelücke), ohne Pin-Read.
- **Nicht gesperrt:** `updateInitialOvertime` (eine Nutzereingabe der Settings-Seite darf nicht still verworfen werden; das
  Dashboard-Icon „Überstunden anpassen“ ist bei `isSaving` deaktiviert), `reloadAfterRetroClose`, `_onDayChange`, `_init`.
- **UI:** `dashboard.html` bindet `svc.isSaving()`: Haupt- und Pausen-Button mit `[disabled]` + `[disabledInteractive]="true"`
  (`aria-disabled`, Fokus bleibt; **Material fängt Klicks bei `<button>` nicht ab**, der Handler feuert, der Service verwirft: nur dort
  einsetzen, wo ein verworfener Aufruf folgenlos ist), alle übrigen Elemente (Zeitfelder, Clear-Button im `TimeInputComponent`,
  Pause bearbeiten/löschen, „Überstunden anpassen“) mit reinem `[disabled]`. Kein Spinner, keine neuen Texte. Eine SCSS-Regel auf
  `[aria-disabled='true']` macht den Haupt-Button sichtbar deaktiviert (`.running`/`:not(.running)` überschreiben sonst die
  Material-Disabled-Farben; nicht über die Klasse `mat-mdc-button-disabled-interactive` selektieren, Material setzt sie schon bei
  `disabledInteractive` allein).
- **Verhaltensänderung (Z1):** Das `change`-Event eines `<input type="time">` feuert beim Verlassen des Feldes, also vor dem folgenden
  Klick: Beginnt dadurch ein Write, wird ein sofort folgender Klick (Pause/Stop) bei API-Latenz verworfen (Buttons sichtbar deaktiviert).
- **Grenzen:** Lesezugriffe (`_ensureCurrentDay`, `_initInner`, `reloadAfterRetroClose`) haben keinen Timeout (ein dort hängender Read
  sperrt weiter, Folge-Taps werden aber verworfen); das Speichern des Edit-Pausen-Dialogs ist nicht gesperrt (ein vor der Aktion
  geöffneter Dialog kann sein Ergebnis verlieren, extrem selten); ein verworfener Tap ist nur an den deaktivierten Elementen
  erkennbar; die Race tritt nur eingeloggt (API-Latenz) auf, Absicherung ausschließlich über Unit-Tests mit Deferred-Gates.
  `OpenEntryCloseService` hat einen eigenen Lock (kein globaler Mutex).
- **Tests:** `dashboard.busy.spec.ts` (W1-W17), `shared/testing/dashboard-world-fake.ts` (Welt mit Hold/Release/Fail je Zugriffsart,
  gemeinsames Log; ohne `vi`, `tsconfig.app.json` kompiliert es mit), `dashboard.spec.ts` (W19), `time-input.spec.ts`. Specs ohne
  echten Flush: nur Deferred-Gates und `advanceTimersByTimeAsync`; ein Test mit offenem Gate gibt es vor Testende frei
  (`afterEach`: `releaseAll()`, dann `vi.getTimerCount()` == 0).

#### Fehler beim Speichern / Kompensation (#426 B)

Web-Pendant zu Mobile #412 („Fehler beim Speichern (#402)“). Gilt für Aktionen mit Saldo-Block (= `_recalculateState` mit `save` und
gesetztem `workEnd`: Stop, `setManualEndTime`, sowie `setManualStartTime`/`updateBreak`/`deleteBreak` auf bereits beendetem Eintrag):
- **Ablauf:** Der Zustand wird wie bisher sofort optimistisch gesetzt, `ActionCtx.beforeState` hält den Zustand vor der Aktion (in `_ctx()`
  synchron erfasst). Scheitert der **Eintrag**-Write (Fehler oder 30-s-Timeout): nichts geschrieben, `_rollback(ctx)`, `DashboardSaveError`.
  Scheitert der **Saldo**-Block: `_rollback(ctx)` (synchron), dann `_compensateEntry(ctx)` (`saveEntry(beforeState.workEntry, ctx.pid)`
  best-effort mit eigenem 30-s-Timeout, Fehler still, nie `saveLastUpdateDate`), dann `DashboardSaveError`; geworfen wird nie der
  Kompensationsfehler. `_rollback` fasst State/Timer nur an, wenn die Aktion nicht überholt wurde (`_isCurrent`); die Kompensation läuft
  über `ctx.pid` auch nach einem Profilwechsel. Nach einem Fehler gibt es keinen Mitternachts-Reinit.
- **Abweichung zu Mobile:** Mobile schreibt Eintrag -> Saldo -> *dann* den State. Das Web setzt den State vor dem `await` (der Stop hält den
  Timer vorher an, ein späterer State-Wechsel würde die Anzeige um die API-Latenz verzögern und den Timer weiterlaufen lassen) und nimmt ihn
  bei Fehlern per Snapshot zurück; das Endergebnis (Daten und Anzeige = Vorzustand) ist identisch.
- **Meldeweg:** Der Service wirft die typisierte Rejection `DashboardSaveError` (`dashboard-save-error.ts`, `cause` = ursprünglicher
  Fehler bzw. `PromiseTimeoutError`, keine Eintragswerte in der Meldung); Signaturen unverändert. `DashboardComponent.guarded()` umschließt
  alle Schreibaufrufe, fängt **nur** diesen Typ, zeigt die Snackbar `dashboard.saveError` und reicht die Ursache an den globalen
  `ErrorHandler` (Sentry). Andere Fehler laufen unverändert weiter, verworfene Taps und `'restart-dialog'` bleiben ohne Meldung.
  `stopRunningTimerForSwitch` fängt jede Rejection und liefert `false`; die Meldung kommt weiter von `ProfileSwitchConfirmService`
  (`switchSaveFailed`), es gibt keine zweite Snackbar.
- **Aktionen ohne Saldo-Block** (Start, Pause auf laufendem Eintrag, `clearEndTime`, `startNewSession`) bleiben optimistisch: Rohfehler
  wird weitergereicht, kein Rollback, keine Meldung (Offline-Start soll nicht anders reagieren). Ein `_ensureCurrentDay`-Abbruch bleibt still.
- **Der frühere zweite Saldo-Write in `_stopRunning`** (identischer absoluter Wert) ist entfallen; der Stop schreibt den Saldo einmal.
  Worst Case einer Aktion mit Kompensation: Autosave 30 + Eintrag 30 + Saldo 30 + Kompensation 30 s.
- **Grenzen:** Doppelfehler (Saldo plus Kompensation) lässt Daten und Anzeige auseinanderlaufen: bei laufendem Eintrag heilt der Autosave
  innerhalb von 30 s, bei geschlossenem Eintrag bleibt Eintrag neu/Saldo alt bis zur nächsten Aktion. Ein Eintrag-Write, der wirft, obwohl
  er serverseitig landete (mehrdeutiger Fehler), wird nicht kompensiert. Mehrgeräte-Konflikte bleiben.
- **Tests:** `dashboard.compensation.spec.ts` (C1-C12), `dashboard.spec.ts` (S1-S5), `core/i18n-dashboard-save.spec.ts`.

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
