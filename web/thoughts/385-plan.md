# Web-Plan: #385 — Offene Einträge vor heute (Banner mit „Beenden" und „Später")
Erstellt: 2026-10-04
Research: web/thoughts/385-research.md (Abschnitt „Entscheidungen zu den offenen Fragen (Hauptsession)" gilt vor allem anderen)
UI-Report: entfällt (Stitch nicht verfügbar; UI-Konzept steht in der Research, Abschnitt 3, Vorlage Mobile `OpenEntryBanner`/`OpenEntryEndDialog` und `HolidayBannerComponent`)
Mobile-Vorlage: PR #405 (`mobile/thoughts/385-plan.md`, `mobile/CLAUDE.md` „Offene Einträge vor heute (#385)"). Tracking: #406 (Backend/Mobile-Folgen), #407 (`date`-vs-`id` im Dashboard).

## Ziel
Das Web-Dashboard zeigt unter dem Feiertagsbanner einen nicht-modalen Banner für den neuesten nicht beendeten Eintrag vor heute (aktives Profil, aktueller + Vormonat). „Beenden" öffnet einen Dialog (Datum + Uhrzeit), schließt den Eintrag, schreibt den Saldo fort (ohne `lastUpdated` anzufassen) und lädt die Saldo-Basis des Dashboards neu; „Später" blendet den Banner für die Sitzung aus. Ohne Nutzeraktion ändert sich nichts.

Nicht Teil: Fortsetzen (Mobile PR 1b), Reparatur verfälschter Daten, Scan anderer Profile, Re-Check beim Tab-Rückkehr, Reports-Darstellung offener Einträge (#404), Umbau der `date`-Nutzung im Dashboard (#407), Mobile-Nachzug (`keepLastUpdated`, `manualOvertimeMinutes`; #406-Folge).

## Voraussetzung / Reihenfolge
- Backend-PR #408 ist gemergt: `PUT /api/overtime` akzeptiert optional `keepLastUpdated: true` (Default unverändert, ältere API-Stände ignorieren das Feld). Der Web-Beenden-Pfad sendet es im eingeloggten Betrieb.
- **Deploy-Reihenfolge: API vor Clients.** Wird das Web vor der API ausgeliefert, funktioniert Beenden, aber `lastUpdated` wird (wie bisher) gesetzt, und die Heuristik kann im Szenario „beenden, heute arbeiten, Reload" falsche Basis liefern. Hinweis in `web/CLAUDE.md` und im PR-Body (Schritt 8).
- Kein neuer Firestore-Pfad, keine Änderung an `web/firestore.rules`, kein Premium-Gate.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Hybrid-Service nötig? | Bestehende erweitern, kein neuer | `WorkEntryService.getEntriesForMonthOnce` (Einmalabruf), `OvertimeService.saveOvertime(ms, pid, { keepLastUpdated })`, `SettingsService.getSettingsOnce(pid)` (neu, siehe Offene Fragen 1) |
| Neuer Domain-Service? | Nein; reine Funktionen in `domain/utils/open-entry.utils.ts` | Endung `.utils.ts` entspricht `overtime.utils.ts`; bisher keine Spec dort, die neue Datei bekommt eine |
| Feature-Services | `OpenEntryService` (Zustand, Suche, Später) und `OpenEntryCloseService` (Beenden, ohne UI-Zustand) in `features/dashboard/` | Trennung Zustand/Aktion hält beide testbar; Dateinamen `open-entry.ts`, `open-entry-close.ts` (keine Kollision mit `dashboard.ts`) |
| Zyklus-Vermeidung | `OpenEntryService` -> `DashboardService`, nie umgekehrt; `DashboardService` bekommt nur `reloadAfterRetroClose(pid)` | `dashboard.service.ts` bleibt bis auf eine öffentliche Methode unverändert |
| Premium-Gate? | Nein | Datensicherheit |
| Routing-Änderung? | Nein | Banner im bestehenden Dashboard |
| Neuer API-Endpunkt? | Nein; bestehender `PUT /overtime` + Body-Feld | Backend ist fertig |
| Neuer Firestore-Pfad? | Nein | Lesen über `GET /work-entries/{y}/{m}` (API), Schreiben über ApiClient |
| Neue Texte? | Ja, `dashboard.openEntry*` in de.json + en.json | Plural als zwei Keys, Deutsch duzen, kein ICU |
| Shared Component? | Banner ja (`shared/components/open-entry-banner/`, rein darstellend, Muster Holiday-Banner); Dialog in `features/dashboard/components/open-entry-end-dialog/` | Nur das Dashboard nutzt den Dialog |
| Tag eines Eintrags | Immer aus `id` (`yyyy-MM-dd`), nie aus `date` | Entscheidung 5; LA-Zone macht `date` (UTC-Mitternacht) zum Vortag |
| „heute" | `TodayService.today()` (Key `yyyy-MM-dd`), String-Vergleich | einzige Quelle, TZ-sicher |
| Lesepfad | `WorkEntryService.getEntriesForMonthOnce(year, month, profileId)` | Entscheidung 4: eingeloggt `ApiClient.getWorkEntriesForMonth` mit explizitem Profil, ausgeloggt `_localGetMonth`; Fehler werfen |
| Dialog-Eingabe | natives `type="date"` + `type="time"`, Reactive Form, Gruppen-Validator | Kein Datepicker-Modul; `min`/`max` erzwingen nichts |
| Datumsanzeige | `Intl.DateTimeFormat` mit `LanguageService.locale()` auf lokales Datum aus `id` | `DatePipe` ist fest `de-DE` |
| Fokus/Ansage nach Entfall | stabiler Anker (`tabindex="-1"`) + `LiveAnnouncer` einmal je Eintrag | Entscheidung 7, keine Snackbar bei Erfolg; Snackbar nur bei Fehler (`openEntrySaveError`) |

## Neue / geänderte Dateien

### Domain Layer
```
web/src/app/domain/utils/
├── open-entry.utils.ts        # neu, pure
└── open-entry.utils.spec.ts   # neu
```
Inhalt der Utils (Signaturen vor Implementierung gegen `overtime.utils.ts`, `time-precision.util.ts`, `break-calculator.ts` prüfen):
- `OPEN_ENTRY_MAX_NOW_AGE_MS` (24 h), `OPEN_ENTRY_LONG_WARNING_MS` (16 h)
- `localDateFromEntryId(id)`: lokales `Date` (Mitternacht) aus `yyyy-MM-dd`
- `effectiveTargetMsForDate(settings, date)`: Soll des Eintragstags, gleiche Formel wie `DashboardService._targetDailyMs` (`roundMsToMinute(weeklyMs / n)`, `getEffectiveDailyTarget`); `workdays` leer ⇒ 0
- `suggestOpenEntryEnd(entry, targetMs, now)` => `{ expectedEnd, suggestedEnd, suggestedIsNow, nowAllowed }` (Soll-Ende = Start + Soll + Summe geschlossener Pausen in Millisekunden; Soll 0 ⇒ kein Soll-Ende; liegt es vor jetzt ⇒ Vorschlag; sonst „Jetzt" nur bei Alter <= 24 h, abgeschnitten auf Minute; sonst `null`)
- `isValidOpenEntryEnd(entry, end, now)`: nach Start, nicht nach jetzt, nicht vor Ende einer geschlossenen bzw. Beginn einer offenen Pause; Ende = Pausenende erlaubt
- `closedBreakMs(breaks)`
- `retroDeltaMs(entryAfterBreaks, targetMs)`: `Netto (nur geschlossene Pausen) − Soll + (manualOvertimeMinutes ?? 0) * 60000` (Entscheidung 3, wie Dashboard-Stop)

### Core Layer
```
web/src/app/core/services/
├── api-client.ts       # saveOvertimeMs(ms, profileId?, opts?: { keepLastUpdated?: boolean }): Body { minutes, keepLastUpdated? } nur wenn true
├── api-client.spec.ts  # Erweiterung: getWorkEntriesForMonth (Pfad, Query, DTO-Mapping), saveOvertimeMs Body
├── overtime.ts         # saveOvertime(ms, profileId?, opts?: { keepLastUpdated?: boolean }); lokal ändert opts nichts
├── overtime.spec.ts    # neu oder erweitert
├── work-entry.ts       # getEntriesForMonthOnce(year, month, profileId?): Promise<WorkEntry[]>
├── work-entry.spec.ts  # Erweiterung
├── settings.ts         # getSettingsOnce(profileId?): Promise<UserSettings> (siehe Offene Fragen 1)
└── settings.service.spec.ts  # Erweiterung (Dateiname im Repo vorhanden, vor Edit prüfen)
```

### Feature Layer
```
web/src/app/features/dashboard/
├── dashboard.service.ts        # + reloadAfterRetroClose(pid)  (einzige Änderung)
├── dashboard.service.spec.ts   # Erweiterung
├── open-entry.ts               # OpenEntryService: Signals, Suche, Später, Epoche
├── open-entry-close.ts         # OpenEntryCloseService: endEntry(...)
├── open-entry.spec.ts, open-entry-close.spec.ts
├── dashboard.ts / dashboard.html / dashboard.scss   # Einbindung unter app-holiday-banner, Fokus-Anker
└── components/open-entry-end-dialog/
    ├── open-entry-end-dialog.ts / .html / .scss / .spec.ts
web/src/app/shared/components/open-entry-banner/
    ├── open-entry-banner.ts / .html / .scss / .spec.ts
web/public/i18n/de.json, en.json        # dashboard.openEntry*
web/src/app/shared/testing/            # ggf. Fakes (ohne vi-Import, siehe Test-Rahmen)
web/CLAUDE.md                           # Doku
```

## Test-Rahmen (gilt für alle Schritte)
- **Rot-Nachweis je Schritt:** Spec zuerst schreiben, laufen lassen (`npm test -- --watch=false --include <spec>`; Flag in Schritt 0 prüfen, sonst Vollauf), Fehlschlag (Symbol fehlt oder Assertion rot) im Commit-Text bzw. `web/thoughts/385-pr.md` festhalten, dann implementieren, dann grün.
- Feste lokale Daten: `vi.useFakeTimers()` + `vi.setSystemTime(new Date(2026, 9, 3, 9, 0))` (Sa 2026-10-03 09:00). Bezugstage Fr 10-02, Sa 10-03, So 10-04, Mo 10-05; Monatsgrenze 10-31/11-01; Jahreswechsel 2026-01-05 -> 2025-12. DST nur als Invarianten (absolute Differenzen, Millisekunden-Addition): 2026-10-25 und 2026-03-29 (Berlin), 2026-11-01 und 2026-03-08 (LA), 2026-09-27 und 2026-04-05 (Auckland). Kein Wochentag-/Zonen-Hartcode.
- **Vite-SSR-Falle (`web/CLAUDE.md`):** nie nackte importierte Werte als Klassenfeld-Initializer (`DEFAULT_WORK_PROFILE_ID`, 24-h-/16-h-Konstanten, `WorkEntryType.Work`); im Constructor zuweisen oder in `signal(...)`/Ausdruck einbetten. Test-Fakes ohne `vi`-Import (`tsconfig.app.json` kompiliert Nicht-Spec-Dateien mit `types: []`).
- **Kein `setTimeout`-Flush:** Im Vollauf steht teils ein fremder Fake-Timer (#392, siehe `settings.service.spec.ts` ab Z. 146, `profile-switch-confirm.spec.ts` ab Z. 18). Flush nur über Microtasks (`await Promise.resolve()` in Schleife, `TestBed.tick()`); Specs mit eigenem Fake-Timer wie `dashboard.profile.spec.ts` mit `vi.advanceTimersByTimeAsync(0)`. Aufräumen in `afterEach` (`vi.useRealTimers`, `TestBed.resetTestingModule`).
- Bestehende Dashboard-Specs (`dashboard.spec.ts`, `.switch`, `.profile`, `.service`) bleiben inhaltlich unverändert grün; `DashboardComponent` bekommt eine neue Abhängigkeit, daher in diesen Specs nur ein Stub-Provider für `OpenEntryService` (Pflegeaufwand, in Schritt 7 eingeplant).
- Je Schritt Lauf unter `TZ=Europe/Berlin` (CI); vollständige Zonenläufe in Schritt 9.

## Implementierungsschritte (TDD-First, Commit je Schicht)

### Schritt 0: Vorbereitung
- [x] Branch von `develop` (aktueller Stand mit gemergtem #408), `web/`: `npm ci --legacy-peer-deps`.
- [x] Prüfen: `--include`-Flag des Test-Runners; Basisvollauf grün; `DashboardService.workEntry`/`isLoading` öffentlich lesbar; Signaturen aus `overtime.utils.ts`, `time-precision.util.ts`, `break-calculator.ts`.
- [x] Gegenprobe Backend: `server/CLAUDE.md` nennt `keepLastUpdated` (bestätigt), Request-DTO-Name im Body ist `keepLastUpdated` (camelCase, `OvertimeSaveTests.cs`).

### Schritt 1: Reine Utils (Commit 1)
- [x] Test `open-entry.utils.spec.ts`:
  - `localDateFromEntryId`: einstellige/zweistellige Tage, Monatsgrenze, Jahreswechsel; Ergebnis lokale Mitternacht (unabhängig von Zone)
  - `effectiveTargetMsForDate`: Arbeitstag (z. B. 40 h / 5 Tage = 8 h), Nicht-Arbeitstag ⇒ 0 (Wochenende = Zusatztag), leere `workdays` ⇒ 0, Minutenrundung (z. B. 40 h / 3 Tage), Gleichheit mit der Dashboard-Formel (Vergleichstest gegen `DashboardService`-Ergebnis, kein Refactor des Dashboards)
  - `suggestOpenEntryEnd`: Soll-Ende = Start + Soll + geschlossene Pausen (offene Pause zählt nicht); DST-Tage als Invariante (`expectedEnd − start` = Soll + Pausen in ms); Soll 0 ⇒ kein `expectedEnd`; Soll-Ende < jetzt ⇒ Vorschlag Soll-Ende; Soll-Ende >= jetzt und <= 24 h ⇒ „Jetzt" (auf Minute abgeschnitten); genau 24 h ⇒ `nowAllowed`; 24 h + 1 min ⇒ nicht, `suggestedEnd` null
  - `isValidOpenEntryEnd`: Ende = Start ungültig, Ende nach jetzt ungültig, Ende = jetzt gültig, vor Ende geschlossener Pause ungültig, = Pausenende gültig, vor Beginn offener Pause ungültig; Test mit minutengenauem und sekundengenauem Ende
  - `retroDeltaMs`: Netto − Soll mit geschlossener Pause; Samstag (Soll 0); `manualOvertimeMinutes` positiv und negativ; offene Pause im Eingang wird nicht eingerechnet (Aufrufer schließt sie vorher, Test dokumentiert das)
- [x] Rot-Nachweis (Datei/Symbole fehlen), dann Impl `open-entry.utils.ts` (pure, kein `inject`).
- [x] Mutationsproben (Test muss rot werden, danach zurücknehmen): 24-h-Grenze `<=` -> `<`; Pausen im Soll-Ende nicht addieren; `manualOvertimeMinutes` weglassen; Soll vom falschen Tag (Parameter vertauscht).

### Schritt 2: Core — Einmalabruf, Suche-Grundlage (Commit 2) und `keepLastUpdated` (Commit 3 oder im selben Commit, getrennte Tests)
**2a Einmalabruf am `WorkEntryService`**
- [x] Tests `work-entry.spec.ts`: eingeloggt ruft `ApiClient.getWorkEntriesForMonth(year, month, pidForApi)` (`'default'` ⇒ `undefined`, sonst ID; explizites Profil unabhängig vom aktiven); ausgeloggt liest `_localGetMonth` aus localStorage-Fixture (Flutter-kompatible Keys), `profileId` ignoriert; Fehler (Reject) wirft weiter; `getEntriesForMonth` (Reports) bleibt unverändert (bestehende Tests).
- [x] `api-client.spec.ts`: HTTP-Test mit `HttpTestingController` für `getWorkEntriesForMonth` (Pfad `/work-entries/2026/10`, Query `profileId` nur bei Nicht-Default, DTO-Mapping inkl. `id`; LA-Lauf: `id` bleibt maßgeblich).
- [x] Impl `getEntriesForMonthOnce`.
- [x] Mutation: `profileId` nicht durchreichen (aktives statt explizites) ⇒ rot.

**2b `keepLastUpdated`**
- [x] Tests `api-client.spec.ts`: `saveOvertimeMs(ms, pid, { keepLastUpdated: true })` sendet Body `{ minutes, keepLastUpdated: true }`; ohne Option Body unverändert `{ minutes }` (kein `keepLastUpdated`-Schlüssel); Query `profileId` wie bisher.
- [x] Tests `overtime.spec.ts`: eingeloggt reicht Option an `ApiClient` durch; ausgeloggt schreibt nur `overtime_value`, `overtime_last_update` bleibt unberührt; Default-Aufrufe unverändert (Regression `Dashboard`/`data-sync`).
- [x] Impl (rückwärtskompatibel: dritter optionaler Parameter).
- [x] Mutation: Option nicht durchreichen ⇒ rot.

**2c `SettingsService.getSettingsOnce(profileId?)`** (siehe Offene Fragen 1)
- [x] Tests: eingeloggt `ApiClient.getSettings(pidForApi)` mit `mergeSettings` (Defaults greifen, `workdaysPerWeek`-Migration), explizites Profil; ausgeloggt `_localGet()`; Fehler wirft.
- [x] Impl; `getSettings()` unverändert.

### Schritt 3: `OpenEntryCloseService` — Beenden (Commit 4)
Aktionskontext (analog `ActionCtx`): beim Aufruf synchron `pid = workProfile.activeProfileId()`, `uid`, Epoche des `OpenEntryService`/eigener Zähler festhalten; alle Reads/Writes mit diesem `pid`; Ergebnis nur zurückgeben, Zustandswirkung (Reload, Re-Check) entscheidet der Aufrufer anhand `isCurrent`.
Signatur (Arbeitstitel): `endEntry(candidate: { id; profileId }, end: Date): Promise<CloseResult>` mit `CloseResult = 'closed' | 'alreadyClosed' | 'invalidEnd' | 'invalidEntry' | 'failed'`.
Ablauf: Ende auf Minute abschneiden -> Einstellungen des Profils lesen (`getSettingsOnce(pid)`, Entscheidung 11, danach nur damit rechnen) -> Eintragsmonat frisch lesen (`getEntriesForMonthOnce`, Eintrag per `id` finden; fehlt/hat Ende ⇒ `alreadyClosed`) -> `invalidEntry` (Typ != work, kein Start) -> `isValidOpenEntryEnd` mit frischer „jetzt"-Zeit (`invalidEnd`) -> offene Pausen auf `end` schließen -> `calculateAndApplyBreaks` (nur Typ work) -> Delta (`retroDeltaMs`, Soll am `id`-Tag aus den Einstellungen) -> alten Saldo `getOvertime(pid)` -> `saveOvertime(alt + delta, pid, { keepLastUpdated: true })` -> `saveEntry({ ...entry, date: localDateFromEntryId(id) }, pid)`; schlägt der Entry-Write fehl: best-effort Rollback `saveOvertime(alt, pid, { keepLastUpdated: true })` (Rollback setzt `lastUpdated` ebenfalls nicht), Ergebnis `failed`. Nie `saveLastUpdateDate`, nie `getLastUpdateDate`. Keine Logs mit Eintragsinhalten. Doppelaufruf während laufender Aktion wird ignoriert.
- [x] Tests `open-entry-close.spec.ts` (Fakes für `WorkEntryService`, `OvertimeService`, `SettingsService`, `WorkProfileService`; gemeinsames Schreib-Log mit Label und `pid`):
  - Ende gesetzt, auf Minute abgeschnitten; gespeicherter Eintrag `workEnd == end`
  - offene Pause erhält `end` = gewähltes Ende; geschlossene Pausen unverändert
  - Auto-Pausen: 10 h brutto ohne Pause ⇒ identisch zu direktem `calculateAndApplyBreaks`; kurzer Eintrag ⇒ keine; Typ != work ⇒ `invalidEntry`
  - Saldo: `neu = alt + (Netto nach Auto-Pausen − Soll am Eintragstag [+ manual])`; Samstag (Soll 0) und Arbeitstag (8 h); Soll aus den Einstellungen des Profils des Eintrags (Fake liefert je `pid` andere Einstellungen)
  - eingeloggt: `saveOvertime` mit `{ keepLastUpdated: true }` (Aufrufargumente); ausgeloggt (localStorage): `saveLastUpdateDate` nie aufgerufen, `getLastUpdateDate` nie gelesen
  - Schreib-Reihenfolge Saldo vor Eintrag; beide mit explizitem `pid`
  - Eintrag wird mit `date` = lokaler Tag aus `id` geschrieben (LA-Lauf: kein Vortag)
  - Validierung ohne Writes: Ende <= Start, > jetzt (frische Uhr, `vi.setSystemTime` zwischen Dialog und Bestätigung), vor Pause ⇒ `invalidEnd`
  - Frisch lesen: schon beendet oder nicht mehr vorhanden ⇒ `alreadyClosed`, keine Writes; zweiter Aufruf nach Erfolg zählt Saldo nicht doppelt
  - Fehler: Lesefehler ⇒ `failed` ohne Writes; Settings-Lesefehler ⇒ `failed` ohne Writes; Saldo-Write schlägt fehl ⇒ kein Entry-Write, `failed`; Entry-Write schlägt fehl ⇒ Rollback-Write mit altem Saldo (Reihenfolge und Wert prüfen), `failed`; Rollback schlägt auch fehl ⇒ `failed`, kein Wurf
  - Profilwechsel mitten in der Aktion (Fake wechselt `activeProfileId` bei gehaltenem Read): alle Writes im Profil des Beginns
  - Doppelaufruf: zweiter Aufruf während offener Aktion ignoriert (genau ein Write-Satz)
  - Soft-Warnung > 16 h blockiert den Service nicht
- [x] Rot-Nachweis, dann Impl.
- [x] Mutationsproben: `saveLastUpdateDate` einbauen; `keepLastUpdated` weglassen (Option nicht senden); Saldo `+` -> `−`; Soll vom heutigen statt Eintragstag; offene Pause nicht schließen; Auto-Pausen weglassen; Reihenfolge Entry vor Saldo; Rollback entfernen; Rollback ohne `keepLastUpdated`; Frisch-lesen-Guard entfernen; `pid` weglassen (aktives Profil); Tag aus `date` statt `id`; Einstellungen des aktiven statt des Eintragsprofils.

### Schritt 4: Dashboard-Einbindung `reloadAfterRetroClose(pid)` (Commit 5)
Verhalten:
- No-op, wenn `pid !== _loadedProfileId` (Profil gewechselt).
- Läuft im Dashboard ein Eintrag mit `workStart != null`, `workEnd == null` und Starttag (aus `id`) ≠ heute (#372-Lauf über Mitternacht): **kein `_init`**; nur `getOvertime(pid)` lesen, `_initGen` vor/nach dem Read prüfen (unverändert lassen, nicht erhöhen), `initialOvertimeMs` erneuern, `_recalculateOvertime()` aufrufen.
- Sonst `_init(uid, { dayChange: true })` (Basis = gespeicherter Saldo; `dailyAlreadyStored`-Ausnahme bleibt über die bestehende Heuristik). Danach ggf. sofort einen Tick auslösen, damit `elapsedMs` nicht bis zum nächsten Sekunden-Tick auf 0 steht (nur wenn Timer läuft).
- Kein `_ensureCurrentDay`, da keine Schreibaktion.
- [x] Tests `dashboard.service.spec.ts`:
  - heute laufender Timer: läuft weiter, Basis = neuer gespeicherter Saldo, Stop danach speichert „neuer Saldo + Tagesanteil" (Delta des Vortags bleibt)
  - heute abgeschlossen und nach `workEnd` gespeichert (`dailyAlreadyStored`): kein Doppelzählen
  - `lastUpdated` unverändert (Fake liefert fest „vor dem Beenden"): Reload zieht heute nicht doppelt ab
  - leerer heutiger Tag: Zustand leerer Tag, Saldo = neuer Wert, kein Ladespinner
  - im Dashboard laufender **Vortag**: kein `_init` (Eintrag und Timer unangetastet, `getTodayEntry` nicht erneut aufgerufen), nur Basis erneuert, `_initGen` unverändert
  - Aufruf mit anderem `pid` als geladenem Profil ⇒ no-op (kein Read)
  - überholter Lauf (Profilwechsel während des Reads) ⇒ Ergebnis verworfen
  - Regression: bestehende `dayChange`-/Profil-Tests unverändert grün
- [x] Rot-Nachweis (Methode fehlt), dann Impl.
- [x] Mutationsproben: Sonderfall „laufender Vortag" entfernen (Timer stoppt ⇒ rot); `pid`-Guard entfernen; Basis nicht erneuern.

### Schritt 5: `OpenEntryService` — Zustand und Signals (Commit 6)
Signals (nur `.asReadonly()`/`computed` öffentlich): `candidates` (Roh-Treffer des Profils, neuester zuerst), `entries` (computed: ohne Dashboard-Lauftag, ohne Später-Treffer, leer solange Dashboard lädt oder Auth `undefined`), `current` (`entries()[0] ?? null`), `moreCount` (`entries().length − 1`, min 0), `busy`, `saveError`. Später-Speicher: Signal mit `Set<string>`-Wert, Schlüssel `uid|pid|yyyy-MM-dd` (ausgeloggt `anon`), nicht persistent; „Später" blendet alle Kandidaten des aktuellen uid+Profil aus. Epoche (Zähler) steigt bei Auth-, Profil-, Tageswechsel; jede Suche trägt `pid` + Epoche und wird bei Abweichung verworfen. Trigger: `effect` auf `AuthService.user()` (nicht `undefined`), `WorkProfileService.activeProfileId()`, `TodayService.today()`; Suche in `untracked`. Suche: aktueller + Vormonat via `new Date(y, m-2, 1)`-Normalisierung (Januar ⇒ Dezember Vorjahr), je Monat eigenes try/catch, Filter Typ work, Start gesetzt, kein Ende, `id`-Tag < heute (String-Vergleich), sortiert absteigend nach `id`. `endEntry(...)` des Close-Service wird hier orchestriert: `busy`-Guard, nach `closed`/`alreadyClosed` nur wenn nicht überholt: `dashboard.reloadAfterRetroClose(pid)`, Re-Check, Fokus-Anker/Ansage-Signal; bei `failed`/`invalidEnd`: `saveError`-Signal (Komponente zeigt Snackbar), Banner bleibt.
- [x] Tests `open-entry.spec.ts` (Close-Service und `DashboardService` gefakt; Flush über Microtasks/`TestBed.tick()`):
  - Fr 22:00 offen, jetzt Sa 09:00 ⇒ 1 Treffer; heute offen / Zukunft / abgeschlossen / ohne Start / Typ vacation, sick, holiday ⇒ keiner
  - Monatsgrenze (2026-11-01 liest 2026-10), Jahreswechsel (Januar liest Dezember Vorjahr), Vor-Vormonat wird nicht gelesen (Lese-Log)
  - mehrere Treffer neuester zuerst, auch bei unsortierter Antwort; `moreCount`
  - Tag nur aus `id`: Eintrag mit `date`, das in LA auf den Vortag fiele, bleibt am `id`-Tag
  - Lesefehler eines Monats ⇒ anderer Monat liefert weiter; beide ⇒ leer, kein Wurf
  - im Dashboard laufender Vortag (Dashboard-Fake: `workEntry` mit Start, ohne Ende, Vortag) ⇒ nicht in `entries`; nach dessen Stop kommt er nicht zurück (Dashboard-Eintrag mit Ende)
  - Banner erst, wenn Dashboard nicht mehr lädt; Auth `undefined` ⇒ keine Suche; Login/Logout ⇒ neue Suche, Altergebnis verworfen
  - Später je uid+Profil+Tag: A→B→A bleibt A ausgeblendet, B unabhängig; anderer Nutzer (uid) sieht ihn wieder; neuer TestBed (neue Sitzung) zeigt wieder; „Später" blendet alle Kandidaten des Profils
  - Profilwechsel mit gehaltenem Read: überholtes Ergebnis wird verworfen; Tageswechsel (`vi.setSystemTime` + `TodayService.refresh`) sucht neu, Später bleibt erhalten
  - `endEntry` `closed`: Close-Aufruf mit `pid` des Beginns, danach `reloadAfterRetroClose(pid)` und Re-Check (nächster Eintrag wird `current`); `alreadyClosed`: ebenfalls Reload + Re-Check; `failed`/`invalidEnd`: kein Reload, `saveError` gesetzt, Banner bleibt
  - Profilwechsel mitten in `endEntry`: kein Reload, kein Zustand im neuen Profil
  - Doppelklick ⇒ `busy`, zweiter Aufruf ignoriert
- [x] Rot-Nachweis, dann Impl (Vite-SSR-Falle beachten: Konstanten im Constructor/`signal(...)`).
- [x] Mutationsproben: Später-Filter entfernen; Schlüssel ohne uid; Schlüssel ohne Profil; Ausschluss des laufenden Dashboard-Tags entfernen; Reload nach Beenden weglassen; Epoche/Profil-Abgleich entfernen; Typfilter entfernen; `workEnd`-Filter entfernen; `< heute` -> `<= heute`; Vormonat weglassen; Sortierung umdrehen; Tag aus `date` statt `id`.

### Schritt 6: i18n (Commit 7)
- [x] Test (klein, neue Spec z. B. `shared/testing` oder `core/i18n-parity.spec.ts`): alle `dashboard.openEntry*`-Keys in `de.json` und `en.json` vorhanden, Platzhalter (`{{date}}`, `{{time}}`, `{{count}}`) je Key gleich, nicht leer.
- [x] Keys unter `dashboard.*` gemäß Research-Tabelle: `openEntryBannerTitle`, `openEntryBannerMoreOne`, `openEntryBannerMoreOther`, `openEntryEnd`, `openEntryLater`, `openEntryEndDialogTitle`, `openEntryEndDialogBody`, `openEntryEndSuggestionExpected`, `openEntryEndSuggestionNow`, `openEntryEndDateLabel`, `openEntryEndTimeLabel`, `openEntryEndTimeRequired`, `openEntryEndInvalid`, `openEntryEndLongWarning`, `openEntryEndDialogConfirm`, `openEntrySaveError`. Abbrechen über vorhandenes `common.cancel`. Deutsch duzen. Kein `openEntryContinue`, keine `…Semantics`-Keys (Entscheidung 9). Ein Tippfehler-Check: Rot-Nachweis = Test vor den Keys.

### Schritt 7: Banner + Dialog + Einbindung (Commit 8)
**Banner** `OpenEntryBannerComponent` (rein darstellend, `OnPush`, `input()`/`output()`, `host` statt `HostBinding`, `MatButtonModule`, `MatIconModule`, `TranslatePipe`): Inputs Datum-Text, Startzeit, `moreCount`, `busy`; Outputs `end`, `later`. Plural per `moreCount === 1`. Layout wie Holiday-Banner (max 1200 px, Radius 12 px, Abstand 16 px unten), nur M3-System-Tokens `--mat-sys-secondary-container`/`--mat-sys-on-secondary-container`, keine Hex-Werte; Zeile mit Icon + Text, unter 600 px Spalte, Buttons `flex-wrap`, Mindesthöhe 44–48 px; Icon `aria-hidden="true"`; Textblock `role="status"` (Buttons außerhalb); Buttons sichtbar „Beenden"/„Später" mit `aria-describedby` auf den Titeltext; 320 px ohne horizontales Scrollen, bei 200 % Zoom nutzbar.
**Dialog** `OpenEntryEndDialogComponent` (`MatDialog`, Reactive Form): `h2 mat-dialog-title`, Textzeile, zwei Vorschlags-Buttons (Soll-Ende mit Uhrzeit; „Jetzt" nur wenn zulässig, je nur wenn Vorschlag existiert), Datum (`min` = Starttag, `max` = heute) + Zeit nativ, Gruppen-Validator `isValidOpenEntryEnd` (frische „jetzt"-Zeit bei Validierung), Fehlerzeile `role="alert"` mit Text und Icon (nicht nur Farbe), Hinweis > 16 h Netto `role="status"` (blockiert nicht), leere Zeit ⇒ Pflichtfeld-Hinweis und Bestätigen gesperrt, Aktionen „Abbrechen"/„Eintrag beenden" (`mat-flat-button`), `cdkFocusInitial` auf dem ersten sinnvollen Element; `maxWidth` relativ zum Viewport, Felder untereinander unter 480 px, kein `min-width: 400px`. Ergebnis: lokales `Date` (Minuten) oder `undefined`.
**Einbindung** `dashboard.html` im `@else`: `@if (openEntry.current(); as e)` unter `app-holiday-banner`, über dem Timer/Grid; `end` ⇒ Dialog ⇒ bei Ergebnis `openEntry.endEntry`; `later` ⇒ `openEntry.later()`; `saveError` ⇒ `MatSnackBar` (Muster `ProfileSwitchConfirmService.notifySaveFailed`, `translate.instant`, `'OK'`, 5000 ms); Fokus nach Entfall auf stabilen Anker (z. B. Überschrift/Timer-Bereich mit `tabindex="-1"`) bzw. Banner des nächsten Eintrags; `LiveAnnouncer.announce` (polite) einmal je Eintrag beim ersten Erscheinen. Datum per `Intl.DateTimeFormat(languageService.locale(), …)` auf `localDateFromEntryId`.
- [x] Tests zuerst:
  - `open-entry-banner.spec.ts` (Muster `holiday-banner.spec.ts`, `provideTranslateService`, `setTranslation` de/en): Text de/en mit Datum und Startzeit; „Noch n weitere" nur bei n > 0, Plural 1/n; Klicks lösen `end`/`later` aus; `busy` deaktiviert beide Buttons; Icon `aria-hidden`; `role="status"` nur am Textblock; `aria-describedby` verweist auf existierende Titel-ID; Quelltext-Test optional: keine Hex-Werte in der SCSS
  - `open-entry-end-dialog.spec.ts` (Muster `profile-switch-confirm.spec.ts`: `NoopAnimationsModule`, Overlay-Container, Microtask-Flush, kein `setTimeout`): Vorbelegung Soll-Ende; „Jetzt" nur <= 24 h; Vorschlags-Buttons setzen Datum + Zeit; `min`/`max` am Datumsfeld; Fehler (Ende <= Start, nach jetzt, vor Pause) mit Text und `role="alert"`, Bestätigen deaktiviert; leere Zeit sperrt Bestätigen und zeigt `openEntryEndTimeRequired`; > 16 h Hinweis blockiert nicht; Rückgabe = lokales `Date`; Abbrechen/Esc ⇒ `undefined`; Fokus startet im Dialog; Datum über Mitternacht (Ende am Folgetag) gültig
  - `dashboard.spec.ts`-Ergänzung (mit `OpenEntryService`-Stub): Banner im `@else` (nicht beim Laden), DOM-Reihenfolge nach Holiday-Banner und vor Timer; Beenden ⇒ Dialog (gemockt) ⇒ Service-Aufruf mit Ergebnis; Dialog-Abbruch ⇒ kein Aufruf; Fehler ⇒ Snackbar, Banner bleibt; „Später" ⇒ ausgeblendet; Timer-Start-Button bleibt bedienbar (nicht modal); Fokus-Anker nach Entfall; `LiveAnnouncer` einmal je Eintrag
  - Stub-Provider in `dashboard.switch.spec.ts`, `dashboard.profile.spec.ts`, `dashboard.service.spec.ts` (nur falls dort `DashboardComponent` gerendert wird)
- [x] Rot-Nachweis, dann Impl (HTML/SCSS, `@if`/`@for`, kein `ngClass`/`ngStyle`, kein `CommonModule`).
- [x] Mutation: Banner an falscher Stelle (vor Feiertag) ⇒ Reihenfolge-Test rot; `busy`-Disable entfernen; Gültigkeitsvalidator entfernen.

### Schritt 8: Doku (Commit 9)
- [x] `web/CLAUDE.md`: neuer Abschnitt „Offene Einträge vor heute (#385)" (Suche, Banner/Später-Schlüssel uid|Profil|Datum, `OpenEntryCloseService` mit Saldo → Eintrag, Rollback, `keepLastUpdated`, `reloadAfterRetroClose` inkl. Sonderfall Vortag, Tag aus `id`, `manualOvertimeMinutes` eingerechnet (Abweichung zu Mobile), Grenzen: älter als Vormonat, andere Profile, kein Tab-Re-Check, Fortsetzen = Mobile PR 1b, Reports #404, #407); Einträge in Layer-Struktur (utils, `open-entry*`, Banner) und Feature-Service-Tabelle; Zeilen `work-entry.ts` (`getEntriesForMonthOnce`), `overtime.ts` (`keepLastUpdated`), `settings.ts` (`getSettingsOnce`) ergänzen.
- [x] **Deploy-Hinweis** in `web/CLAUDE.md` (kurz) und PR-Body: API (mit #408) vor Web ausliefern; ältere API ignoriert `keepLastUpdated`, dann wird `lastUpdated` beim Beenden gesetzt (altes Verhalten).
- [x] Hinweis, dass der Kommentar in `DashboardService.updateInitialOvertime` („kein lastUpdated-Update") eingeloggt weiterhin nicht zutrifft (bestehend, nicht Teil).

### Schritt 9: Gesamtvalidierung
- [x] Vollläufe aus `web/`: `TZ=Europe/Berlin npm test -- --watch=false`, dann dieselben Läufe mit `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland`; alle grün, keine Flakes (Vollauf wegen Fake-Timer-Interferenz, nicht nur Einzelspecs).
- [x] `npm run build -- --configuration production` (Budgets prüfen: kein Datepicker, kein MessageFormat).
- [x] Mutations-Tabellen der Schritte 1, 2, 3, 4, 5, 7 abgearbeitet; Ergebnis je Probe (rot ja/nein) in `web/thoughts/385-pr.md`.
- [ ] `madge --circular` (falls im Repo genutzt) ohne Zyklus (`OpenEntryService` ↔ `DashboardService`).
- [ ] Manuelle Prüfung (Liste unten) durchführen und Ergebnis in den PR-Body.

## PR-Zuschnitt
Ein PR gegen `develop` mit je einem Commit pro Schicht: (1) Utils, (2) Core-Einmalabruf + `keepLastUpdated` + `getSettingsOnce` (ggf. zwei Commits), (3) Close-Service, (4) Dashboard-Reload, (5) Zustand-Service, (6) i18n, (7) UI, (8) Doku. Geschätzt M–L. Schnitt W1 (ohne UI: Schritte 1–5) / W2 (UI: 6–8) nur, wenn der Diff im Review zu groß wird (Richtwert > ca. 1500 Zeilen ohne Specs); W2 hängt dann von W1 ab. PR-Text nennt: Abweichung zu Mobile (`manualOvertimeMinutes`, `keepLastUpdated`, Rollback), Deploy-Reihenfolge, Tracking #406/#407, „Fortsetzen" nicht enthalten.

## Manuelle Prüfliste (für den PR-Body)
- [ ] **Echter Mitternachtslauf mit Reload:** Timer vor Mitternacht starten, Tab über Mitternacht schließen oder Seite danach neu laden; Banner „Dein Eintrag vom … läuft noch seit …" erscheint; zweiter Lauf mit Tab, der über Mitternacht offen bleibt (Banner darf für den laufenden Eintrag **nicht** erscheinen, #372)
- [ ] Beenden mit Soll-Ende-Vorschlag, mit „Jetzt", mit eigener Zeit über Mitternacht; Saldo in Dashboard und Einstellungen stimmt (Netto − Soll des Eintragstags, bei Samstag Soll 0); nach Beenden heute Timer starten, Reload bei laufendem Timer, Stop: Saldo ohne Verschiebung (prüft `keepLastUpdated` gegen die deployte API; zusätzlich gegen eine API ohne #408 als Gegenprobe vermerken)
- [ ] Mehrere offene Einträge: „Noch n weitere", nach Beenden erscheint der nächste; „Später" blendet alle aus, nach Reload wieder da
- [ ] Profilwechsel: Banner gehört zum aktiven Profil; Wechsel mitten im geöffneten Dialog; Soll stammt aus dem Eintragsprofil
- [ ] Offline (DevTools): Beenden zeigt Fehler-Snackbar, Banner bleibt, kein Teilzustand; danach online wiederholen; Ausgeloggt (localStorage): Beenden funktioniert, `lastUpdated` unverändert
- [ ] Zweiter Tab: Eintrag in Tab 1 beenden, in Tab 2 erneut ⇒ `alreadyClosed`, kein doppelter Saldo
- [ ] Tastatur: Tab-Reihenfolge, Enter/Space auf Buttons, Dialog ohne Fokusfalle, Esc schließt, Fokus nach Entfall des Banners auf dem Anker, Fokus-Ring sichtbar
- [ ] Screenreader (NVDA/VoiceOver): einmalige polite Ansage, Buttonbeschreibung enthält Datum, Fehlertext im Dialog wird angesagt
- [ ] axe (DevTools/CLI) und Lighthouse Accessibility auf Dashboard mit Banner und auf geöffnetem Dialog: 0 Verstöße
- [ ] Hell/Dunkel: Kontrast Banner (secondary-container-Paar), Dialogtexte, Fehler-/Hinweiszeile, Fokus-Ring (WCAG AA)
- [ ] 320 px Breite und 200 % Zoom: kein horizontales Scrollen, Buttons umbrechen, Dialog bedienbar; Sprache de/en: Datum und Texte lokalisiert (englische UI ohne deutsche Wochentage)
- [ ] Browser: Chrome, Firefox, Safari (natives `type="date"`/`"time"`)

## Signal-Design (Kurzform)
`OpenEntryService`: `private _candidates = signal<Candidate[]>([])`, `_dismissed = signal(new Set<string>())`, `_busy`, `_saveError`, `_epoch` (Zähler, nicht reaktiv); `entries = computed(...)` kombiniert `_candidates`, `_dismissed`, `DashboardService.isLoading()`, `DashboardService.workEntry()`, uid/Profil/Heute-Signale. `DashboardComponent`: `protected readonly openEntry = inject(OpenEntryService)`, Banner-Daten per `computed` (Datum-Text, Startzeit); `OnPush`.

## Risiken (Plan-spezifisch)
| Risiko | Umgang |
|---|---|
| `getSettingsOnce` fehlt im Core | Neu in Schritt 2c; ApiClient liefert unmergte Einstellungen, daher `mergeSettings` verwenden |
| Dashboard-Service-Race | nur eine neue öffentliche Methode; bestehende Specs als Regression; Sonderfall Vortag ohne `_init` |
| Specs flakig im Vollauf (Fake-Timer, SSR-Transform) | Test-Rahmen oben, Vollläufe in 4 Zonen |
| Rollback-Write schlägt ebenfalls fehl | Saldo um Delta zu hoch bei offenem Eintrag; kein Wurf, `failed`, Nutzer korrigiert über „Überstunden anpassen"; im PR-Text dokumentiert |
| API ohne #408 | Funktioniert, altes `lastUpdated`-Verhalten; Deploy-Reihenfolge dokumentiert |

## Offene Fragen an die Hauptsession
1. **`SettingsService.getSettingsOnce(profileId)`** als neue öffentliche Core-Methode (eingeloggt `ApiClient.getSettings(pid)` + `mergeSettings`, lokal `_localGet()`): Entscheidung 11 verlangt Einstellungen des Eintragsprofils bei Aktionsbeginn, `getSettings()` hat das Lag-Fenster. Freigabe für die zusätzliche Core-Methode? (Alternative: Beenden bei Profilwechsel mitten im Lauf abbrechen und mit `firstValueFrom(getSettings())` rechnen, wäre schwächer.)
2. **Zwei Services** (`OpenEntryService` + `OpenEntryCloseService`) statt einem `open-entry.ts` wie in der Research-Domain-Tabelle: so geplant, weil Zustand und Aktion getrennt testbar sind. Einverstanden?
3. **Rollback** schreibt den alten Saldo ebenfalls mit `keepLastUpdated: true`. Falls die API den Wert beim Rollback zurücksetzen soll wie bisher, bitte melden (Annahme: nein).
4. **Fokus-Anker:** konkretes Element (Dashboard-Überschrift oder Timer-Karte) wird in Schritt 7 anhand des aktuellen Templates gewählt; kein sichtbarer Zusatztext. Reicht das als Freigabe?

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. `SettingsService.getSettingsOnce(pid)` als neue Core-Methode freigegeben (Einmalabruf mit `mergeSettings`, kein Lag-Fenster); mit eigenen Tests, bestehende `getSettings()`-Aufrufer unverändert.
2. Zwei Feature-Services (`OpenEntryService` für Zustand/Suche/Später, `OpenEntryCloseService` für Beenden) sind einverstanden.
3. Der Saldo-Rollback sendet ebenfalls `keepLastUpdated: true` (ja).
4. Fokus-Anker in Schritt 7 anhand des Templates wählen, im PR-Body begründen und in der manuellen Prüfliste aufführen (ausreichend).

## Umsetzungsstand (Web-Developer, 2026-10-04)
Schritte 0 bis 8 umgesetzt und committet (lokal, nicht gepusht): 1442bf0, 433052d, 9caf0a0, 5d52e2d, 0b04905, f596671, 9f3d8cc, e1fc72b, 98de754, 199629c.
Schritt 9: Vollläufe (Standard-TZ UTC, Berlin, LA, Auckland, UTC) 871 Tests grün, Production-Build grün. Offen: manuelle Prüfliste, madge (nicht installiert).
Abweichungen: Ergebnis `busy` zusätzlich in `CloseResult`; `OpenEntryService.entryOf/prepareEnd` (Dialog-Daten) und `closedCount` ergänzt; Banner-Datum/Startzeit aus dem bei der Suche gefundenen Eintrag.

## Review (Web-Reviewer, 2026-10-04)
Keine Mutationsreste gefunden (Diff gegen `origin/develop` Datei für Datei geprüft). 52 eigene Mutationen, alle von Tests erkannt; "Tag aus `date`" nur in `America/Los_Angeles` (zonenabhängig, in UTC/Berlin äquivalent). Vollläufe 871 Tests grün in Standard-TZ, Berlin, LA, Auckland, UTC; Production-Build grün. Offen: madge (nicht installiert), manuelle Prüfliste (im PR-Body).
