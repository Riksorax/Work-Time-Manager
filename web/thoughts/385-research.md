# Web-Research: #385 — Offene Einträge vor heute (Web-Parität zu Mobile PR #405)
Datum: 2026-10-04
Feature-Ordner: web/src/app/features/dashboard/ (Service, Dialog), web/src/app/shared/components/open-entry-banner/ (Banner), web/src/app/domain/utils/ (reine Funktionen)

## Verbindliche Vorgaben
- Nur Hinweis (Banner) mit **Beenden** und **Später**. Kein automatisches Teilen/Schließen (#381 nicht Teil).
- **Fortsetzen** ist ein separater Folge-PR (Mobile PR 1b) und hier NICHT Teil.
- Backend ist bei der Rechenlogik kanonisch. Web rechnet wie das Backend, Mobile weicht bekannt ab (`server/CLAUDE.md`).
- Nicht Teil: Reparatur verfälschter Daten, Scan anderer Profile, Re-Check beim Zurückkehren in den Tab, Reports-Darstellung offener Einträge (#404).

## Wichtigster Befund vorab (entscheidungsrelevant, bitte zuerst lesen)

**Die Mobile-Zusage „`lastUpdated` wird beim Beenden NICHT gesetzt" gilt nur lokal (ausgeloggt), nicht für eingeloggte Nutzer. Das betrifft Web und Mobile.**

Belege aus dem Code:
- `server/.../Firestore/OvertimeRepository.cs`, `SaveAsync`: schreibt bei **jedem** `PUT /api/overtime` zusammen mit `minutes` immer `lastUpdated = jetzt (UTC)`. Es gibt keine Option, das zu unterlassen.
- Mobile Cloud-Pfad: `FirebaseOvertimeRepositoryImpl` bekommt in `providers.dart` die `apiDataSourceProvider`; `ApiDataSource.saveOvertime` ruft `PUT /overtime`, `saveLastOvertimeUpdate` ist dort ein No-op mit dem Kommentar „Das Backend setzt lastUpdated automatisch beim Speichern des Saldos". Das Beenden-Delta setzt also auch auf Mobile (eingeloggt) `lastUpdated = heute`.
- Web: `OvertimeService.saveOvertime` (eingeloggt) geht ebenfalls über `PUT /overtime`; `saveLastUpdateDate` ist eingeloggt ein No-op. Auch der Kommentar in `DashboardService.updateInitialOvertime` („kein lastUpdated-Update") stimmt eingeloggt nicht — ein bereits bestehendes Verhalten.

Folge (rechnerisch aus `calculateInitialOvertime` bzw. Mobile `_load` hergeleitet, nicht per Lauf bestätigt): Die Heuristik „`lastUpdated` ist heute ⇒ der gespeicherte Saldo enthält den Tagesanteil des geladenen heutigen Eintrags, also Basis = Saldo − Tagesanteil" greift dann fälschlich. Szenario: Sa 09:00 offenen Fr-Eintrag beenden (Saldo + Delta, `lastUpdated` = Sa), danach heute den Timer starten, später Seite neu laden (F5) bei laufendem Timer. Beim Reload gilt Basis = gespeicherter Saldo − (bisher gelaufene Zeit − Soll). Der Heute-Anteil (typisch −7 h bis −8 h kurz nach Start) wird zur Basis addiert; beim späteren Stop speichert das Dashboard Basis + Tagesergebnis und der Saldo ist um (Soll − bis zum Reload gelaufene Zeit) zu hoch. Unauffällig ist der Fall nur direkt nach dem Beenden (der Dashboard-Reload mit `dayChange: true` nimmt den gespeicherten Saldo ungefiltert als Basis) und wenn heute leer oder bereits abgeschlossen und gespeichert ist (`dailyAlreadyStored`).

Das ist kein Fehler der Web-Umsetzung allein; ein 1:1-Port erbt ihn, und Mobile PR #405 hat ihn im Cloud-Betrieb bereits. Optionen (Entscheidung nötig, siehe Offene Fragen 1):
- **A (empfohlen):** Backend-Erweiterung, abwärtskompatibel (`server/CLAUDE.md`: Felder nur hinzufügen): `PUT /api/overtime` bekommt ein optionales Feld bzw. einen optionalen Query-Parameter, der `lastUpdated` unangetastet lässt; Default = bisheriges Verhalten. Web (und danach Mobile als Folge-Issue) setzt es nur beim nachträglichen Beenden. Reihenfolge Backend vor Web (`/server-implement`). Keine neuen Firestore-Pfade, keine Rules-Änderung.
- **B:** Risiko akzeptieren und dokumentieren (gleiche Lage wie Mobile). Schwäche: Das Szenario ist realistisch (Beenden, dann heute arbeiten, dann Reload).
- **C:** Heuristik im Web/Mobile-Dashboard ersetzen (z. B. Basis immer aus dem gespeicherten Wert ohne Tagesabzug). Größerer Eingriff in die race-empfindliche Init-Logik, nicht Teil von #385.

## Flutter-Quelle (Mobile PR #405, gemergt)
Dateien: `mobile/lib/domain/usecases/get_open_past_work_entries.dart`, `close_open_work_entry.dart`, `mobile/lib/domain/utils/overtime_utils.dart` (`effectiveTargetForDate`, `suggestOpenEntryEnd`, `isValidOpenEntryEnd`, `openEntryMaxNowAge`), `mobile/lib/presentation/view_models/open_entry_view_model.dart`, `dashboard_view_model.dart` (`reloadAfterRetroClose`), Widgets `open_entry_banner.dart`, `open_entry_end_dialog.dart`, ARB-Keys `openEntry*` (app_de.arb/app_en.arb), Doku `mobile/CLAUDE.md` „Offene Einträge vor heute (#385)".
Screens/ViewModels: `DashboardScreen`/`OpenEntryBanner`, `OpenEntryViewModel`, `OpenEntryEndDialog`.

## Feature-Verständnis
Ein über Mitternacht laufender Timer bleibt nach Seiten-Reload als Eintrag mit Start und ohne Ende am Vortag stehen. Das Dashboard kennt nur „heute"; der Eintrag ist unsichtbar, fehlt im Gleitzeit-Saldo und bleibt offen. Der Banner meldet den neuesten offenen Eintrag vor heute (aktives Profil, aktueller + Vormonat). Der Nutzer legt Datum und Uhrzeit des Endes fest; der Eintrag wird geschlossen und der Saldo um (Netto − Soll am Eintragsdatum) fortgeschrieben. „Später" blendet den Banner für die Sitzung aus. Nichts ändert sich ohne Nutzeraktion.

## 1. Ist-Zustand Web

### Warum der offene Vortag nach Reload unsichtbar bleibt
- `DashboardService._initInner` lädt genau drei Dinge: `getTodayEntry(pid)`, Saldo und `lastUpdated` des Profils, Einstellungen. `WorkEntryService._firebaseToday` bildet Monats-ID und Tages-Schlüssel aus `new Date()` (heute); fehlt der Tag, kommt `null` und `emptyEntry(heute)`. Ein Rückblick existiert nirgends.
- Ablauf: Fr 22:00 Start, Autosave (30 s) schreibt den Eintrag mit `workStart`, ohne `workEnd`. Reload Sa 09:00 zeigt einen leeren Samstag. Startet der Nutzer dort den Timer, gibt es zwei offene Einträge.
- Was die vorhandenen Mechanismen (#372/#380) leisten und was nicht:
  - `TodayService` liefert nur den Tages-Schlüssel (Signal `today`, Mitternachts-Timer, `visibilitychange`/`focus`/`pageshow`). Er löst Reinit aus, schaut aber nie rückwärts. `_onDayChange` lässt einen im Dashboard **laufenden** Eintrag in Ruhe; nach einem Reload gibt es den gar nicht mehr im Speicher.
  - `_ensureCurrentDay`/`_isCurrentDay` entscheiden nur über den **geladenen** Eintrag (laufend oder heutiger Key). Ein nie geladener Vortag ist ihnen unbekannt.
  - `_initGen`/`_initRun` verwerfen überholte Läufe; ohne Rückblick-Abruf nichts zu verwerfen.
  - Profilwechsel (#380): Der Timer wird eingefroren, der Eintrag bleibt im alten Profil laufend. Beim Zurückwechseln an einem späteren Tag lädt `_init` den „heutigen" Eintrag des Profils; der eingefrorene Eintrag vom Vortag ist wieder unsichtbar. Das ist die dokumentierte Grenze (2) aus #388 (Mobile) und gilt für Web analog; der neue Banner löst sie für das aktive Profil.
  - `ActionCtx` (profileId + `_initGen` je Schreibaktion) schützt Writes des Dashboards. Eine Aktion außerhalb des Dashboard-Zustands (Beenden eines Vortags) hat keinen Kontext und braucht einen eigenen, analog gebauten.
- Zusätzliches Web-Detail: Ein laufender Timer, der **ohne** Reload über Mitternacht läuft, bleibt korrekt sichtbar (#372). Das Problem entsteht erst beim Neuladen, Tab-Schließen oder Gerätewechsel.

### Wo Web-Services einen Monatsabruf bieten
| Stelle | Eignung |
|---|---|
| `WorkEntryService.getEntriesForMonth(year, month)` | Observable über `combineLatest(auth.user$, activeProfileId$)`, eingeloggt `onSnapshot` (Dauer-Abo), **kein `profileId`-Argument**. Einziger Aufrufer: `ReportsService`. Für das Dashboard ungeeignet (Replay-Lag des Profil-Observables, siehe #380; Abo muss per `firstValueFrom` beendet werden). Offline kann `onSnapshot` einen leeren Cache-Snapshot als „Tag existiert nicht" liefern. |
| `ApiClient.getWorkEntriesForMonth(year, month, profileId?)` | Einmaliger HTTP-Abruf mit explizitem Profil, entspricht dem Mobile-Pfad (`GET /work-entries/{y}/{m}?profileId=`). Existiert, hat aber **keinen Aufrufer** in der App (ungetestet im Produktivpfad). Fehler (Offline, 5xx) werfen sauber. |
| `WorkEntryService._localGetMonth` | privat, synchron, lokal (ausgeloggt). |

Empfehlung: neue öffentliche Methode am `WorkEntryService` (Arbeitstitel `getEntriesForMonthOnce(year, month, profileId?)`, Promise): eingeloggt über `ApiClient.getWorkEntriesForMonth` (mit `profileIdForApi`), ausgeloggt `_localGetMonth`. `getEntriesForMonth` (Reports) bleibt unverändert. Vorteile: explizites Profil ohne Replay-Lag, Fehler statt falsch-leerem Ergebnis, derselbe Pfad für die Suche und das „frisch lesen" vor dem Schreiben, kein Abo. Alternative (nur optionales `profileId` an `getEntriesForMonth` plus `firstValueFrom`, so von der Mobile-Analyse vorgeschlagen) ist machbar, hat aber die Offline-Falschnegativ-Schwäche; siehe Offene Fragen 4.

### Tag eines Eintrags: `id` statt `date`
Der Tag eines Eintrags kommt in beiden Quellen sicher aus der `id` (`yyyy-MM-dd`; Backend `EntryId(year, month, day)`, Firestore-Reads bilden sie aus dem days-Map-Schlüssel, lokal aus dem Key). Das Feld `date` ist ein Zeitstempel: Web schreibt UTC-Mitternacht, Flutter lokale Mitternacht; beim Lesen in einer Zone westlich von UTC (z. B. America/Los_Angeles) ergibt `new Date(dto.date)` bei Web-geschriebenen Einträgen den **Vortag**. Folgerungen:
- Kalendertag eines Kandidaten (Vergleich mit „heute", Sortierung, „Später"-Schlüssel, Ausschluss des laufenden Dashboard-Eintrags) immer aus der `id`.
- Weekday für das Soll und die Darstellung aus einem lokalen Datum, das aus der `id` gebaut wird.
- Beim Zurückschreiben `date` auf dieses lokale Datum setzen, damit `ApiClient.toDto` (UTC-Mitternacht aus lokalen Y/M/D) denselben days-Map-Schlüssel trifft.
- Der bestehende Dashboard-Code nutzt an mehreren Stellen `toDateKey(e.date)` (`_isCurrentDay`, `_onDayChange`); die LA-Fragilität dort ist bestehend und nicht Teil von #385 (ggf. Folge-Issue).

## 2. Semantik: Mobile → Web (1:1, mit Abweichungen)

| Aspekt | Mobile (PR #405) | Web-Soll | Abweichung / Anmerkung |
|---|---|---|---|
| Suche | aktueller + Vormonat, Januar → Dezember Vorjahr, je Monat eigenes try/catch, nur aktives Profil | gleich; Profil explizit (`pid` zu Beginn festhalten), Monatsberechnung über `new Date(y, m-2, 1)`-Normalisierung | Lesepfad siehe oben |
| Filter | Typ work, `workStart != null`, `workEnd == null`, Tag < heute, nicht der im Dashboard laufende Tag | gleich; „heute" = `TodayService.today()`, Tag aus `id`; String-Vergleich `yyyy-MM-dd` genügt | Eintrag mit Datum in der Zukunft (Uhrsprung) fällt heraus |
| Sortierung | neuester zuerst | gleich | |
| Ausschluss laufender Dashboard-Eintrag | `excludeDate` + Listener auf Dashboard-State | computed aus `DashboardService.workEntry()` (laufend ⇒ dessen `id`-Tag aus der Liste) | Der Banner wird erst gezeigt, wenn das Dashboard nicht mehr lädt; sonst Aufblitzen |
| Später | blendet alle Kandidaten des Profils für die Sitzung aus; Schlüssel `profileId|yyyy-MM-dd`; nicht persistent | gleich, Speicher als Signal im Service (Sitzung = Seitenlebensdauer, kein localStorage) | **Schlüssel um die uid ergänzen** (`uid|pid|Tag`, ausgeloggt `anon`): in einer SPA ohne Reload kann sich ein anderer Nutzer anmelden, `default` wäre sonst gemeinsam |
| Mehrere Einträge | neuester zuerst, „Noch n weitere", nach Aktion Re-Check | gleich | Plural ohne ICU (siehe i18n) |
| Soll-Ende | Start + Soll + Summe **geschlossener** Pausen (Duration-Addition); Soll = 0 ⇒ keins | gleich, Millisekunden-Addition (DST-sicher) | |
| Vorschlag | Soll-Ende, falls vor jetzt; sonst „Jetzt" nur bei Alter ≤ 24 h (Grenze inklusive); sonst leer, Bestätigen gesperrt bis Zeit gewählt | gleich | Konstante 24 h |
| Gültiges Ende | nach Start, nicht nach jetzt, nicht vor Ende einer geschlossenen Pause bzw. Beginn der offenen Pause | gleich; Prüfung mit minutengenauem Ende (`roundToMinute`) und einer frischen „jetzt"-Zeit beim Bestätigen | Der Dialog kann lange offen stehen: Service prüft erneut und meldet `invalidEnd` |
| Weiche Warnung | Netto > 16 h, blockiert nicht | gleich | Netto im Dialog = Ende − Start − Summe geschlossener Pausen |
| Offene Pause | zum gewählten Ende geschlossen | gleich | |
| Auto-Pausen | `BreakCalculatorService.calculateAndApplyBreaks`, nur Typ work, nach dem Schließen der Pause | `calculateAndApplyBreaks` (Web) | siehe Rechenlogik-Vergleich |
| Saldo | `neu = alt + Netto − Soll(Eintragsdatum)`, Netto nach Auto-Pausen | gleich; Soll aus Einstellungen des **Profils des Eintrags**, Weekday aus dem `id`-Datum | `manualOvertimeMinutes`: Mobile ignoriert, Web-Dashboard rechnet es ein, siehe Offene Fragen 3 |
| `lastUpdated` | nicht setzen | lokal: `saveLastUpdateDate` nicht aufrufen. Eingeloggt: **nicht erreichbar ohne Backend-Änderung** | siehe „Wichtigster Befund" |
| Write-Reihenfolge | erst Saldo, dann Eintrag; bei Fehler Banner bleibt | gleich; zusätzlich **Rollback des Saldos** bei Fehler des Eintrag-Writes (best effort) | Mobile hat hier das Doppelzähl-Risiko beim Wiederholen (Saldo schon erhöht, Eintrag noch offen); Offene Fragen 2 |
| Frisch lesen | Eintrag des Monats neu lesen; bereits beendet ⇒ `alreadyClosed`, keine Writes | gleich, über den Einmal-Abruf | |
| Ergebnisse | `closed`, `alreadyClosed`, `invalidEnd`, `invalidEntry`, `failed` | gleiche Menge als String-Union; Fehlerfälle zeigen die Fehlermeldung | |
| Danach | `reloadAfterRetroClose()` (`_init(dayChange: true)`), laufender Vortag bleibt unangetastet, nur Basis erneuert; danach Re-Check | gleich, siehe unten | Web braucht den Sonderfall zwingend (kein Pinning in `_initInner`) |

### Dashboard-Reload nach dem Beenden (Web)
Neue öffentliche Methode am `DashboardService` (Arbeitstitel `reloadAfterRetroClose(pid)`), Aufruf nur wenn die Aktion nicht überholt wurde und das geladene Profil noch `pid` ist:
- Läuft im Dashboard ein Eintrag mit Starttag ≠ heute (Timer über Mitternacht, #372), darf **kein** `_init` laufen: `_initInner` lädt nur „heute", würde den Timer stoppen und den Vortag aus dem Zustand werfen (er wäre sofort wieder verwaist). Stattdessen nur `getOvertime(pid)` lesen, Generation prüfen, `initialOvertimeMs` erneuern und `_recalculateOvertime()` aufrufen.
- Sonst `_init(uid, { dayChange: true })`: die Basis ist der gespeicherte Saldo (der das Delta enthält); Ausnahme `dailyAlreadyStored` (heute abgeschlossen und danach gespeichert) bleibt über die bestehende Heuristik korrekt.
- Beobachtung: Ein Reload mit heute laufendem Timer setzt `elapsedMs` bis zum nächsten Sekunden-Tick auf 0 (kurzes Flackern der Anzeige). Beim stillen Tageswechsel besteht das schon; für diese Aktion ggf. sofort einen Tick auslösen.
- Der Reload ist ohne Spinner (dayChange) und wird von `_initGen` gegen Überholer geschützt. Der Aufruf geschieht ohne `_ensureCurrentDay`, weil er nichts schreibt.

### Rechenlogik: Web vs. Backend vs. Mobile (Unterschiede, die den Port berühren)
| Punkt | Backend (kanonisch) | Web | Mobile | Wirkung auf #385 |
|---|---|---|---|---|
| Offene Pause bei **beendetem** Eintrag | zählt 0 (`SumBreakMs` nur Pausen mit Ende), Reports/Break-Calculator ignorieren sie | Dashboard `_totalBreakMs(breaks, until)` zählt eine offene Pause **bis `workEnd`** (#390); `report-calculator`, `break-calculator`, `time-calculations`, `reports.service` ignorieren sie (wie Backend) | 0 | Keine, weil beim Beenden **alle offenen Pausen zuerst zum gewählten Ende geschlossen werden**. Die Netto-Rechnung des Beenden-Pfads nur über geschlossene Pausen (nicht über `_totalBreakMs`). Relevant erst für „Fortsetzen" (Folge-PR) |
| Auto-Pausen | `CalculateAndApply`: Brutto-Dauer, 6 h/9 h, Position 4 h nach Start, `AdjustExisting` setzt hinter die **späteste** Pause | `calculateAndApplyBreaks` identisch zum Backend | `AdjustExisting` setzt hinter die **zuletzt gelistete** Pause (Position kann abweichen, Summe gleich) | Netto-Summe identisch; nur die Lage einer ergänzten Pause kann je Plattform abweichen. Namen sind hartkodiert deutsch (`Mittagspause` etc.), `breakName`-Pipe lokalisiert die Anzeige |
| Tagessoll | `DailyTargetMs`: `Wochenstunden * 3_600_000 / Arbeitstage` ohne Minutenrundung | `roundMsToMinute(weeklyMs / Anzahl)` (auch im Dashboard) | auf Minuten gerundet | Das Delta nutzt wie das Dashboard die gerundete Web-Formel (so rechnet Stop heute). Das Backend rechnet das Tages-Soll in Reports ungerundet; Abweichung nur im Sekundenbruchteil-Bereich |
| Rundung Saldo | int Minuten | `toStoredMinutes` (kaufmännisch, symmetrisch) | gleich | Alle Zeitstempel minutengenau, Soll minutengerundet ⇒ Delta ganzzahlig |
| Zeitstempel | Minuten | `roundToMinute` schneidet ab (nie in die Zukunft) | schneidet ab | Ende wird abgeschnitten |
| `manualOvertimeMinutes` im Tagesergebnis | `ReportCalculator` kennt es für Wochen/Monat | Dashboard: `Netto − Soll + manual` | Mobile-Beenden: ohne | Offene Fragen 3 |

## Domain-Mapping
| Flutter Entity/Service | Angular Äquivalent | Datei |
|---|---|---|
| `GetOpenPastWorkEntries` | Methode „Suche" im `OpenEntryService` (Signal `candidates`) | features/dashboard/open-entry.ts (Dateiname ohne Typ-Suffix nach AGENTS.md; Namenskollisionen sind hier nicht gegeben) |
| `CloseOpenWorkEntry` + `CloseOpenEntryResult` | Methode `endEntry(end)` + String-Union | ebenda |
| `OpenEntryViewModel` + `OpenEntryState` | Signals `entries` (computed, gefiltert), `current`, `moreCount`, `busy`, `saveError` | ebenda |
| `openEntryDismissedProvider` | Signal-Set im Service | ebenda |
| `suggestOpenEntryEnd`, `isValidOpenEntryEnd`, `effectiveTargetForDate`, `openEntryMaxNowAge` | pure Funktionen und Konstanten | domain/utils/open-entry.utils.ts (neu; `overtime.utils.ts` hat bisher keine Spec) |
| Tag aus Eintrag | pure Funktion „lokales Datum aus `id`" | ebenda |
| `getWorkEntriesForMonth` | `getEntriesForMonthOnce(year, month, profileId?)` | core/services/work-entry.ts |
| `reloadAfterRetroClose` | `DashboardService.reloadAfterRetroClose(pid)` | features/dashboard/dashboard.service.ts |
| `OpenEntryBanner` | `OpenEntryBannerComponent` (rein darstellend: Inputs Datum/Zeit/weitere/busy, Outputs end/later), Muster `HolidayBannerComponent` | shared/components/open-entry-banner/ |
| `OpenEntryEndDialog` | `OpenEntryEndDialogComponent` (MatDialog, Reactive Form) | features/dashboard/components/open-entry-end-dialog/ |
| `settingsRepository` (Soll) | `SettingsService.getSettings()` mit **explizitem Profil**-Lesen beim Beenden (siehe Risiken) | core/services/settings.ts |
| Provider-Wiring | `providedIn: 'root'`, `inject()`, Signals, `effect` für Trigger | |

## Daten-Layer / Service-Design
- **Trigger der Suche** (kein Signal-Lag-Problem, weil alle Reads ein explizites `pid` tragen und danach gegen das aktuelle Signal und eine Suchgeneration geprüft werden): Auth-Zustand (erst suchen, wenn `AuthService.user()` nicht mehr `undefined` ist; `toSignal` ohne Anfangswert liefert bis zur ersten Emission `undefined`), `WorkProfileService.activeProfileId()`, `TodayService.today()`. Ein überholtes Ergebnis wird verworfen (Muster `_initGen`).
- **Sichtbarkeit** = Kandidaten ohne den Dashboard-Lauftag, ohne „Später"-Treffer, nur wenn das Dashboard nicht lädt. Das vermeidet Flackern (Ladezustand, anonyme Vorsuche vor dem Login-Ereignis).
- **Beenden-Aktionskontext:** `pid` und eine Epoche (Zähler, der bei Auth-/Profil-/Tageswechsel steigt) zu Beginn festhalten; Reads und Writes nur mit diesem `pid`; Ergebnis und Reload nur, wenn nicht überholt (analog `ActionCtx`).
- **Writes:** `OvertimeService.saveOvertime(ms, pid)` und `WorkEntryService.saveEntry(entry, pid)` mit explizitem Profil (nie „aktives Profil zum Aufrufzeitpunkt"). Der Eintrag wird mit lokalem Datum aus der `id` geschrieben (siehe oben).
- **Einstellungen:** Das Soll muss aus den Einstellungen des Profils stammen, in dem der Eintrag liegt. `SettingsService.getSettings()` folgt dem aktiven Profil per Observable (Lag-Fenster). Empfehlung: Soll-Rechnung beim Beenden mit den Einstellungen lesen, die zum festgehaltenen Profil passen; praktisch heißt das, den Beenden-Pfad bei einem Profilwechsel mitten im Lauf abzubrechen statt falsche Einstellungen zu nutzen (das Dashboard hat dasselbe Problem und führt `_settingsMaybeStale`). Plan-Phase: entscheiden, ob ein Einmal-Abruf `ApiClient.getSettings(profileId)` (eingeloggt) bzw. lokal genutzt wird.
- **Keine neuen Firestore-Pfade**, keine Änderung an `web/firestore.rules`, kein Premium-Gate (Datensicherheit, keine Zusatzfunktion).
- **Offline-Fallback:** ausgeloggt lokal (`localStorage`, Flutter-kompatible Keys); der lokale Pfad kennt kein `lastUpdated`-Problem. `DataSyncService` nimmt offene lokale Einträge bei Login mit; nach dem Login sucht der Service neu (Auth-Trigger).

## UI-States
| State | Flutter-Widget | Angular-Lösung |
|---|---|---|
| Dashboard lädt | Ladezustand | Banner nicht gerendert (liegt im `@else` hinter `svc.isLoading()`) |
| Kein offener Eintrag / „Später" | `SizedBox.shrink` | nichts gerendert |
| Offener Eintrag | Banner `secondaryContainer`, Icon, Titel, optional „Noch n weitere", Buttons Später/Beenden | `app-open-entry-banner` über `@if (openEntry.current(); as e)` |
| Beenden läuft (`busy`) | Buttons deaktiviert | `[disabled]` an beiden Buttons; Doppelklick wird zusätzlich im Service ignoriert |
| Dialog offen | `AlertDialog` mit Chips und Pickern | `MatDialog` mit Titel, Text, zwei Vorschlags-Buttons, Datum + Zeit |
| Ende ungültig | Fehlertext mit Icon | `mat-error`/Hinweis mit `role="alert"`, Text nicht nur farbig, Bestätigen deaktiviert |
| > 16 h Netto | weicher Hinweis | Hinweiszeile (kein Blocker), `role="status"` |
| Speichern fehlgeschlagen | Snackbar `openEntrySaveError` | `MatSnackBar` (Muster `ProfileSwitchConfirmService.notifySaveFailed`: `snackBar.open(translate.instant(...), 'OK', { duration: 5000 })`), Banner bleibt |
| Premium-gesperrt | nicht vorhanden | nicht vorhanden |

## 3. UI-Konzept

### Banner im Dashboard-Template
- Platz: im `@else` von `dashboard.html`, im `.dashboard-wrapper` direkt vor oder nach `app-holiday-banner`. Empfehlung: **vor** dem Feiertagsbanner (Handlungsbedarf zuerst, Feiertag ist rein informativ). Mobile: „neben". Minimale Wirkung auf das Grid: der Wrapper ist eine Flex-Spalte (`.dashboard-wrapper` mit Kommentar „Feiertags-Banner liegt über dem Grid").
- Komponente analog `HolidayBannerComponent`: `ChangeDetectionStrategy.OnPush`, `input()`/`output()`, kein `standalone`, `host` statt `HostBinding`, `MatButtonModule` + `MatIconModule` + `TranslatePipe`, Layout-Maße wie Holiday-Banner (max 1200 px, Radius 12 px, Abstand 16 px nach unten).
- Farben ausschließlich als M3-System-Tokens: `--mat-sys-secondary-container` / `--mat-sys-on-secondary-container` (unterscheidet sich vom Feiertag `tertiary`). `styles.scss` überschreibt die System-Tokens in `.dark-theme`, Kontrast kommt aus dem Rollenpaar. Keine hartkodierten Farben (der Dashboard-SCSS nutzt zwar lokale Hex-Werte für Überstunden-Farben; hier nicht nachahmen).
- Layout: Zeile mit Icon + Text links und Aktionen rechts; unter 600 px Spalte, Buttons umbrechend (`flex-wrap`), Mindest-Trefferfläche 44–48 px.
- A11y:
  - Text `role="status"` nur am Textblock (das Muster des Feiertagsbanners), Buttons außerhalb der Live-Region. Weil der Banner nach asynchroner Suche per `@if` eingefügt wird, sind eingefügte Live-Regionen nicht überall zuverlässig; Ergänzung: einmalige polite Ansage über `LiveAnnouncer` (CDK ist vorhanden; heute nirgends genutzt) beim ersten Erscheinen je Eintrag.
  - Icon `aria-hidden="true"`.
  - Button-Namen sichtbar „Beenden"/„Später"; Datum über `aria-describedby` auf den Titeltext statt eigener `aria-label` (vermeidet Label-in-Name-Abweichung und zwei Keys). Alternative wie Mobile: `openEntryEndAria`/`openEntryLaterAria` mit Datum.
  - Tastatur: normale Tab-Reihenfolge, Enter/Space auf nativen Buttons, keine Fokusfalle.
  - Fokus nach dem Beenden: Der Banner verschwindet samt fokussiertem Button. Der Dialog gibt den Fokus an den Auslöser zurück, der danach entfällt. Empfehlung: bei Erfolg den Fokus programmatisch auf einen stabilen Anker setzen (z. B. Überschrift/Timer-Bereich mit `tabindex="-1"`) oder auf den Banner des nächsten Eintrags.
  - Kein Hover-/Pointer-Only-Bedienweg, kein Zeitlimit.

### Dialog Datum + Zeit
- Vorbilder: `EditEntryDialogComponent` (Reactive Forms, `mat-form-field appearance="outline"`, natives `matInput type="time"`, `mat-dialog-actions align="end"`), `ConfirmSwitchWhileRunningDialogComponent`/`RestartSessionDialogComponent` (kleine Dialoge mit `cdkFocusInitial`), `ProfileSwitchConfirmService` (Dialog über Service).
- Aufbau: `h2 mat-dialog-title`, Textzeile „Wann hast du am {Datum} aufgehört?", zwei Vorschlags-Buttons (Soll-Ende mit Uhrzeit, „Jetzt"; je nur wenn zulässig), Datumsfeld und Zeitfeld, Fehler-/Hinweiszeile, Aktionen „Abbrechen" (`common.cancel`) und „Eintrag beenden" (`mat-flat-button`, disabled solange ungültig).
- Eingabe: **natives** `type="date"` (mit `min` = Starttag, `max` = heute) und `type="time"`; kein Datepicker-Modul (Projekt nutzt `MatDatepicker` nirgends, Bundlegröße, native A11y, Browser-Locale). `min`/`max` erzwingen bei Tastatureingabe nichts, deshalb ein Gruppen-Validator mit `isValidOpenEntryEnd`. Leere Zeit (kein sinnvoller Vorschlag) ⇒ Bestätigen gesperrt, Pflichtfeld-Hinweis.
- 12 h/24 h: Das Web hat keine `use24HourFormat`-Einstellung; angezeigte Zeiten im Dashboard sind `HH:mm`; das native Zeitfeld folgt der Browser-Locale, der Wert ist intern immer `HH:mm`. Eine Einstellung ist nicht nötig.
- Breite: kein festes `min-width: 400px` (der Edit-Dialog hat es und bricht auf kleinen Phones); Dialog mit `maxWidth` relativ zur Viewport-Breite, Felder untereinander unter 480 px.
- Ergebnis: das gewählte lokale `Date` (Datum + Zeit, Minuten), `undefined` bei Abbruch/Esc/Backdrop.

### i18n (`web/public/i18n/de.json` + `en.json`, Keys unter `dashboard.*`, Platzhalter `{{...}}`, Deutsch duzen)
Textvorlage = Mobile-ARB, nur Syntax angepasst:

| Key | de | en |
|---|---|---|
| `dashboard.openEntryBannerTitle` (`date`, `time`) | Dein Eintrag vom {{date}} läuft noch seit {{time}}. | Your entry from {{date}} has been running since {{time}}. |
| `dashboard.openEntryBannerMoreOne` | Noch 1 weiterer offener Eintrag | 1 more open entry |
| `dashboard.openEntryBannerMoreOther` (`count`) | Noch {{count}} weitere offene Einträge | {{count}} more open entries |
| `dashboard.openEntryEnd` | Beenden | End |
| `dashboard.openEntryLater` | Später | Later |
| `dashboard.openEntryEndDialogTitle` | Ende des Eintrags festlegen | Set the end of the entry |
| `dashboard.openEntryEndDialogBody` (`date`) | Wann hast du am {{date}} aufgehört? | When did you stop on {{date}}? |
| `dashboard.openEntryEndSuggestionExpected` (`time`) | Soll-Ende ({{time}}) | Target end ({{time}}) |
| `dashboard.openEntryEndSuggestionNow` | Jetzt | Now |
| `dashboard.openEntryEndDateLabel` / `...TimeLabel` | Datum / Uhrzeit | Date / Time |
| `dashboard.openEntryEndTimeRequired` (neu, Web) | Bitte wähle eine Uhrzeit. | Please choose a time. |
| `dashboard.openEntryEndInvalid` | Das Ende muss nach dem Start und vor jetzt liegen. | The end must be after the start and before now. |
| `dashboard.openEntryEndLongWarning` | Das ergibt mehr als 16 Stunden. Stimmt das? | That is more than 16 hours. Is that correct? |
| `dashboard.openEntryEndDialogConfirm` | Eintrag beenden | End entry |
| `dashboard.openEntrySaveError` | Eintrag konnte nicht beendet werden. | Could not end the entry. |

- Plural: ngx-translate liefert hier kein ICU (kein MessageFormat-Compiler im Projekt, kein bestehendes Plural-Muster). Zwei Keys, die Komponente wählt nach `count === 1`; neue Abhängigkeit nicht nötig.
- Datum im Text: `DatePipe` ist über `LOCALE_ID` fest auf `de-DE` gesetzt (bewusst, #221), eine englische UI bekäme sonst deutsche Wochentage. Deshalb `Intl.DateTimeFormat` mit `LanguageService.locale()` auf ein aus der `id` gebautes lokales Datum (Wochentag kurz, Tag, Monat). Zeit als `HH:mm` wie im restlichen Dashboard.
- Mobile-Semantik-Keys (`openEntryEndSemantics`/`LaterSemantics`) nur nötig, falls `aria-label` statt `aria-describedby` gewählt wird.
- `openEntryContinue` kommt erst mit dem Fortsetzen-PR. Rechtstexte unberührt.

## 4. Testplan (Vitest, `ng test`)

Rahmen: feste lokale Daten über `vi.useFakeTimers()` + `vi.setSystemTime(new Date(2026, 9, 3, 9, 0))` (Sa 2026-10-03 09:00), Bezugstage Fr 2026-10-02, Sa 10-03, So 10-04, Mo 10-05; Monatsgrenze 2026-10-31/11-01; Jahreswechsel 2026-01-05 → 2025-12; DST-Invarianten 2026-10-25 und 2026-03-29 (Berlin), 2026-11-01 und 2026-03-08 (LA), 2026-09-27 und 2026-04-05 (Auckland). Keine `new Date()`-Abhängigkeit, kein Wochentag-/Zonen-Hartcode; DST-Fälle als Invarianten (absolute Differenzen, Duration-Addition). Läufe: `TZ=Europe/Berlin npm test -- --watch=false` (CI), zusätzlich `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland` (LA ist die Zone, in der `date` vs. `id` unterscheidet; Auckland deckt +13 ab). Mit `--include` auf die neuen Specs eingrenzbar (Plan-Phase prüfen).

Fallen aus dem Repo, die jede neue Spec beachtet:
- **Vite-SSR-Transform (web/CLAUDE.md, „Test-Falle"):** nackte importierte Werte nie als Klassenfeld-Initializer (`x = KONSTANTE;`), sondern im Constructor zuweisen oder in `signal(...)`/Array/Ausdruck einbetten. Betrifft vor allem `DEFAULT_WORK_PROFILE_ID`, die 24-h-/16-h-Konstanten und `WorkEntryType.Work` im neuen Service. Test-Fakes ohne `vi`-Import (siehe `shared/testing/work-profile-fake.ts`, `tsconfig.app.json` kompiliert Nicht-Spec-Dateien mit `types: []`).
- **`setTimeout` im Flush:** Der Hinweis steht nicht in `web/CLAUDE.md`, sondern in den Specs (`settings.service.spec.ts` ab Zeile 146, `profile-switch-confirm.spec.ts` ab Zeile 18, Ursache #392): Im Vollauf steht teils ein fremder Fake-Timer. Deshalb Flush nur mit Microtasks (`for` über `await Promise.resolve()` und `TestBed.tick()`), kein `setTimeout`. Specs mit eigenem Fake-Timer (Dashboard) nutzen wie `dashboard.profile.spec.ts` `vi.advanceTimersByTimeAsync(0)` und räumen in `afterEach` (`vi.useRealTimers`, `TestBed.resetTestingModule`) auf.
- Bestehende Dashboard-Specs (`dashboard.spec.ts`, `dashboard.switch.spec.ts`, `dashboard.profile.spec.ts`, `dashboard.service.spec.ts`) müssen unverändert grün bleiben; sie stubben `DashboardService`/Dienste teils mit `useValue: {}`. Eine neue `inject(OpenEntryService)` in `DashboardComponent` braucht dort einen Stub-Provider (kleiner Pflegeaufwand, im Plan einplanen).

Neue Specs und Fälle:
1. **`open-entry.utils.spec.ts` (rein):** Soll-Ende = Start + Soll + geschlossene Pausen (Millisekunden), Soll = 0 ⇒ keins, Soll-Ende vor/nach jetzt, „Jetzt" exakt bei 24 h erlaubt und bei 24 h + 1 min nicht, kein Vorschlag bei > 24 h; `isValidOpenEntryEnd` (Ende = Start, nach jetzt, vor Pausenende bzw. offenem Pausenbeginn, Randwerte); `effectiveTargetForDate` (Arbeitstag, Nicht-Arbeitstag, keine Arbeitstage, Minutenrundung, Wochenende = Zusatztag); lokales Datum aus `id` (Monatsgrenze, 1-stellige Tage); DST-Tage.
2. **`work-entry.spec.ts` (Erweiterung) / Einmal-Abruf:** ausgeloggt `_localGetMonth` mit localStorage-Fixture (Flutter-Keys), eingeloggt `ApiClient.getWorkEntriesForMonth` mit explizitem Profil (`'default'` ⇒ ohne Query, sonst ID), Fehler wirft, Reports-Methode unverändert. Der bislang ungenutzte `ApiClient`-Aufruf bekommt einen HTTP-Test (Pfad, Query, DTO-Mapping inkl. LA-Zone: `id` bleibt maßgeblich).
3. **`open-entry.spec.ts` (Suche + Zustand):** Fr 22:00 offen, jetzt Sa 09:00 ⇒ 1 Treffer; heute offen/Zukunft/abgeschlossen/ohne Start/Typ vacation, sick, holiday ⇒ keiner; Monatsgrenze (2026-11-01 liest 2026-10), Jahreswechsel (Januar liest Dezember Vorjahr), Vor-Vormonat wird nicht gelesen; mehrere Treffer neuester zuerst (auch bei unsortierter Antwort); Lesefehler eines Monats ⇒ anderer Monat liefert weiter, beide ⇒ leer, kein Wurf; im Dashboard laufender Eintrag erzeugt keinen Banner, nach dessen Stop kommt er nicht zurück; „Später" je uid + Profil + Tag, Profilwechsel A→B→A, neue Sitzung (neuer TestBed) zeigt wieder; Trigger: Profilwechsel (überholtes Ergebnis wird verworfen), Tageswechsel (`vi.setSystemTime` + `TodayService.refresh`), Auth `undefined` ⇒ keine Suche, Logout/Login; Banner erst nach Dashboard-Laden.
4. **Beenden (im selben Spec oder eigener):** Ende gesetzt (Minuten), offene Pause zum Ende geschlossen, geschlossene Pausen unverändert, Auto-Pausen nur bei Typ work (10 h brutto ohne Pause ⇒ erwartete Pausen; kurz ⇒ keine), Saldo = alt + (Netto − Soll am **Eintragstag**) mit Samstag (Soll 0) und Arbeitstag (z. B. 8 h), Soll aus dem Profil des Eintrags; `saveLastUpdateDate` wird nie aufgerufen (lokal) und `getLastUpdateDate` nicht gelesen; Write-Reihenfolge Saldo vor Eintrag (Log), beide mit explizitem `pid`; Eintrag wird mit `date` = lokaler Tag aus `id` geschrieben (LA-Lauf); Validierung ohne Writes (`invalidEnd`), Typ ≠ work/ohne Start (`invalidEntry`); frisch lesen: schon beendet/fehlt ⇒ `alreadyClosed`, keine Writes, zweiter Aufruf nach Erfolg doppelt keinen Saldo; Fehler: Lesefehler ⇒ `failed` ohne Writes, Saldo-Write fehlschlägt ⇒ kein Eintrag-Write, Eintrag-Write schlägt nach Saldo fehl ⇒ Rollback-Write des alten Saldos, `failed`; Doppelklick (`busy`); Profilwechsel mitten in der Aktion ⇒ Writes im Profil des Beginns, kein Reload, kein State im neuen Profil; Soft-Warnung blockiert nicht.
5. **`dashboard.service.spec.ts`-Ergänzung (`reloadAfterRetroClose`):** mit heute laufendem Timer: läuft weiter, Basis = neuer gespeicherter Saldo, Stop danach speichert „neuer Saldo + Tagesanteil"; mit heute abgeschlossenem und gespeichertem Eintrag (kein Doppelzählen, `dailyAlreadyStored`); mit im Dashboard laufendem **Vortag** (kein `_init`, Timer und Eintrag unangetastet, nur Basis erneuert, `_initGen` unverändert); leerer heutiger Tag; Aufruf nach Profilwechsel ⇒ no-op; Regression: `dayChange`-/Profil-Tests unverändert grün.
6. **`open-entry-banner.spec.ts`** (Muster `holiday-banner.spec.ts`: `provideTranslateService`, `setTranslation` de/en): Text de/en mit Datum und Startzeit, „Noch n weitere" nur bei n > 0 und Plural 1/n, Buttons lösen `end`/`later` aus, `busy` deaktiviert, Icon `aria-hidden`, `role="status"` am Textblock, Beschreibung der Buttons (`aria-describedby`), Dark-Mode nur über Tokens (Quelltext-Test: keine Hex-Werte in der SCSS ist optional).
7. **`open-entry-end-dialog.spec.ts`** (Muster `profile-switch-confirm.spec.ts`: `NoopAnimationsModule`, Overlay-Container, Microtask-Flush): Vorbelegung Soll-Ende, „Jetzt" nur ≤ 24 h, Chips setzen Datum + Zeit, `min`/`max` am Datumsfeld, Validierungen (Ende ≤ Start, nach jetzt, vor Pause) mit Text (nicht nur Farbe) und `role="alert"`, leere Zeit sperrt Bestätigen, > 16 h Hinweis blockiert nicht, Rückgabewert = lokales `Date`, Abbrechen/Esc ⇒ `undefined`, Fokus startet im Dialog.
8. **`dashboard.spec.ts`-Ergänzung:** Banner steht im `@else` (nicht beim Laden), über/neben dem Feiertagsbanner, Beenden → Dialog (gemockt) → Service-Aufruf, Fehlerergebnis ⇒ Snackbar und Banner bleibt, „Später" blendet aus, Timer-Start-Button bleibt bedienbar (nicht modal).
9. **i18n-Parität:** kleiner Test, dass die neuen `dashboard.openEntry*`-Keys in `de.json` und `en.json` vorkommen und die Platzhalter gleich sind (es gibt noch keinen allgemeinen Paritätstest).

Rot-Nachweis je Schritt (Test zuerst, Fehlschlag festhalten, dann implementieren). Mutationsproben (jeweils muss mindestens ein Test rot werden): Filter `workEnd` entfernen; `< heute` → `<= heute`; Typfilter entfernen; Vormonat weglassen; Sortierung umdrehen; Tag aus `date` statt `id`; 24-h-Grenze `<=` → `<`; Pausen im Soll-Ende nicht addieren; Saldo `+` → `−`; Soll vom heutigen statt vom Eintragstag; offene Pause nicht schließen; Auto-Pausen weglassen; Reihenfolge Eintrag vor Saldo; Rollback entfernen; Frisch-lesen-Guard entfernen; `saveLastUpdateDate` einbauen; explizites `pid` weglassen (Aktion nutzt aktives Profil); Später-Filter entfernen; Schlüssel ohne uid/Profil; Ausschluss des laufenden Dashboard-Tags entfernen; Reload nach Beenden weglassen; Sonderfall „laufender Vortag" im Reload entfernen.

## 5. Aufteilung, PR-Größe, Reihenfolge
Mobile ist gemergt (Entscheidung 11: Web = getrennter PR, gleiches Konzept). Vorschlag:
0. **Optional vorgelagert, nur wenn Offene Fragen 1 = Option A:** Backend-PR (`PUT /api/overtime` mit optionalem „lastUpdated nicht setzen", abwärtskompatibel, Tests in `server/tests`), danach Web nutzt ihn nur beim Beenden. Mobile-Follow-up separat.
1. **Web-PR (ein PR gegen `develop`, Commits entlang der Schichten, geschätzt M–L):**
   1. reine Funktionen (`open-entry.utils.ts` + Spec)
   2. `WorkEntryService`-Einmalabruf (+ ggf. `ApiClient`-Test)
   3. `DashboardService.reloadAfterRetroClose` (+ Spec, Regressionen)
   4. `OpenEntryService` (Suche, Später, Beenden) + Spec
   5. i18n-Keys
   6. Banner + Dialog + Dashboard-Einbindung + Specs
   7. Doku: `web/CLAUDE.md` neuer Abschnitt „Offene Einträge vor heute (#385)" und Einträge in der Struktur-/Feature-Service-Tabelle; Hinweis „Mobile: Fortsetzen = PR 1b".
   Wird der PR zu groß, Schnitt nach Schritt 3: **PR W1 (ohne UI):** Utils, Einmalabruf, Service, Reload, Specs; **PR W2 (UI):** i18n, Banner, Dialog, Einbindung. Beide in Reihenfolge, weil W2 die Service-API braucht.
2. **Folge-PRs (nicht hier):** Fortsetzen (Mobile 1b, danach Web), Mobile-Follow-up zu `lastUpdated`/`manualOvertimeMinutes`, Reports-Darstellung offener Einträge (#404; Backend zählt 0, Web-Reports ignorieren offene Pausen).
Checks vor PR: `npm test -- --watch=false && npm run build -- --configuration production` (aus `web/`), zusätzlich TZ-Läufe der neuen Specs. Kein Backend-Build nötig, außer Option A. Keine Rules-Änderung.

## 6. Risiken
| Risiko | Bewertung / Umgang |
|---|---|
| **`lastUpdated` eingeloggt (siehe oben)** | Hoch; Entscheidung 1 vor der Plan-Phase. Betrifft auch Mobile PR #405 |
| **Mehrere offene Einträge** | Realistisch (Wochenende, bereits ignorierter Eintrag). Neuester zuerst, „Noch n weitere", nach jeder Aktion Re-Check, „Später" blendet alle für die Sitzung aus |
| **Sehr alter Eintrag** | Jenseits des Vormonats nie gefunden (akzeptierte Grenze, Reports-Bearbeiten bleibt). „Jetzt" nur ≤ 24 h, Vorschlag sonst leer, weiche Warnung ab 16 h Netto, Datumsfeld auf [Starttag, heute] |
| **Profilwechsel (#380)** | Suche und Beenden mit explizitem `pid`; Epoche + Abgleich mit dem aktiven Profil vor jedem Zustandswechsel; Soll aus den Einstellungen des Profils des Eintrags (Settings-Observable hat Lag-Fenster, ggf. Einmalabruf mit Profil); bei Profilwechsel mitten im Lauf keine Zustandsänderung und kein Reload (das Dashboard lädt über `activeProfileId$` ohnehin neu); Später-Schlüssel mit Profil |
| **Race beim Beenden** | Doppelklick (`busy`), frisch lesen + `alreadyClosed`, Dashboard-Lauftag nie Kandidat. Bekannte Rest-Races: zweiter Tab/Gerät lässt denselben Eintrag laufen (Autosave schreibt dort das Ende wieder weg, Last-Write-Wins), zwei Tabs mit Banner (zweite Aktion trifft `alreadyClosed`) |
| **Teilfehler Saldo/Eintrag (wie #394/#402)** | Saldo zuerst (Parität), bei Eintrag-Fehler best-effort Rollback des Saldos, damit ein Wiederholen nicht doppelt zählt; schlägt auch der Rollback fehl, ist der Saldo um das Delta zu hoch bei offenem Eintrag (Log ohne Eintragsinhalte, Nutzer kann über „Überstunden anpassen" korrigieren). Alternative Reihenfolge Eintrag zuerst: stiller Verlust des Deltas, Banner weg |
| **Zeitzonen/DST** | Tag nur aus `id`, „heute" nur aus `TodayService`; Soll-Ende und Pausen per Millisekunden-Addition; lokale Datumskonstruktion; LA-Fall (UTC-Mitternacht ergibt Vortag) per Test abgesichert; Browser-Zeitzone ≠ Schreib-Zone der Daten bleibt über die `id` stabil |
| **Reload bei laufendem heutigen Timer** | `_init(dayChange: true)` lädt den zuletzt gespeicherten heutigen Eintrag (jede Aktion speichert sofort, Autosave alle 30 s; verloren geht höchstens die Anzeige-Sekunde); kurzes Flackern von `elapsedMs` |
| **Laufender Vortag im Dashboard** | Kein `_init` (würde den Timer verwerfen und einen neuen Orphan erzeugen); nur Basis erneuern |
| **Auth-Zustand `undefined`/anonyme Vorsuche** | Keine Suche vor der ersten Auth-Emission; Banner erst nach Dashboard-Laden; Auth-Wechsel erhöht die Epoche und verwirft Altergebnisse |
| **Offline** | Einmalabruf über API wirft ⇒ keine Treffer bzw. `failed` mit Snackbar; kein falsches „bereits beendet" |
| **Bestehende Tests/Specs** | Neue Abhängigkeit der `DashboardComponent` erfordert Stub-Provider in bestehenden Dashboard-Specs; kein inhaltlicher Umbau |
| **Dashboard-Service-Größe** | `dashboard.service.ts` bleibt bis auf eine öffentliche Methode unverändert; die Logik liegt im neuen Service |
| **Doppelte Rechenlogik** | Soll-Formel liegt in `_targetDailyMs` (privat) und neu als reine Funktion. Kein Refactor des Dashboards in #385; ein Test sichert die Gleichheit beider ab |
| **A11y/Fokus** | Fokus nach Entfall des Banners (siehe oben), Live-Ansage einmalig, Fehlertext mit `role="alert"`, Kontrast über System-Tokens; Axe-Prüfung manuell im Browser (Hell/Dunkel, 320 px, 200 % Zoom) |
| **`manualOvertimeMinutes`** | Offene Fragen 3 |

## Offene Fragen (mit Empfehlung; ich lege nichts davon selbst fest)
1. **`lastUpdated` bei eingeloggtem Beenden (Backend setzt es bei jedem Saldo-PUT).** Optionen A/B/C siehe oben. Empfehlung: **A** (kleine, abwärtskompatible Backend-Erweiterung vor dem Web-PR; Mobile als Folge-Issue nachziehen), weil das Szenario (beenden, heute arbeiten, neu laden) im Cloud-Betrieb realistisch ist und nur so die Mobile-Zusage „lastUpdated nicht setzen" auch eingeloggt gilt. Lokal bleibt es ohne Eingriff korrekt.
2. **Write-Reihenfolge und Rollback.** Parität Saldo → Eintrag, ergänzt um best-effort Rollback des Saldos bei Fehler des Eintrag-Writes (Mobile hat das nicht). Empfehlung: ja.
3. **`manualOvertimeMinutes` im Delta.** Web-Dashboard und Backend-Reports rechnen es ein, Mobile-Beenden nicht. Empfehlung: im Web einrechnen (gleiches Ergebnis wie ein normaler Stop) und Mobile als Folge-Issue angleichen; alternativ strikt 1:1 ohne. Der Fall ist selten (manuelle Korrektur an einem offenen Eintrag über den Reports-Dialog).
4. **Lesepfad.** Neuer Einmalabruf am `WorkEntryService` über `ApiClient` (eingeloggt) bzw. lokal (Empfehlung) statt optionalem `profileId` an `getEntriesForMonth` plus `firstValueFrom` (Mobile-Analyse). Der bislang unbenutzte `ApiClient.getWorkEntriesForMonth` bekommt dabei erstmals einen Aufrufer und einen Test.
5. **Tag aus `id` statt `date`** als Regel für den ganzen neuen Code (siehe oben); die bestehende `date`-Nutzung im Dashboard (LA) als eigenes Folge-Issue? Empfehlung: ja, nicht in #385 anfassen.
6. **Position und Reihenfolge des Banners:** vor dem Feiertagsbanner (Empfehlung) oder danach?
7. **Rückmeldung nach dem Beenden:** wie Mobile ohne Snackbar (Banner verschwindet), dafür Fokus auf einen stabilen Anker und einmalige Live-Ansage? Empfehlung: ja, kein zusätzlicher sichtbarer „Eintrag beendet"-Text.
8. **Plural:** zwei Keys (`...MoreOne`/`...MoreOther`) statt neuer MessageFormat-Abhängigkeit. Empfehlung: ja.
9. **Buttons-Beschriftung für Screenreader:** `aria-describedby` mit Titeltext (Empfehlung, weniger Keys) oder `aria-label` mit Datum wie Mobile (zwei Zusatzkeys)?
10. **PR-Schnitt:** ein PR mit Commits je Schicht (Empfehlung) oder W1 (ohne UI) + W2 (UI)? Backend-PR nur bei Frage 1 = A.
11. **Soll aus den Einstellungen des Eintragsprofils:** Einmalabruf mit Profil (eingeloggt `ApiClient.getSettings(pid)`) oder bei Profilwechsel mitten im Lauf abbrechen? Empfehlung: bei Aktionsbeginn die Einstellungen des Profils lesen und danach nur noch mit diesen rechnen; Details in der Plan-Phase.
12. **„Später" nach Auth-Wechsel:** Schlüssel mit uid (Empfehlung) oder Sitzungs-Reset bei Logout/Login?

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. **lastUpdated:** Option A. Abwärtskompatible Backend-Erweiterung zuerst (Tracking-Issue #406), danach der Web-PR; Mobile zieht als Folge-PR nach. Der Web-PR darf erst nach dem Backend-PR geplant/umgesetzt werden, da er das neue Feld nutzt. Bis dahin ist Web-Plan/-Umsetzung blockiert.
2. **Write-Reihenfolge:** Parität Saldo → Eintrag, mit best-effort Rollback des Saldos bei Fehler des Eintrag-Writes (ja).
3. **manualOvertimeMinutes:** im Web einrechnen (wie ein normaler Stop); Abweichung zu Mobile im PR-Text nennen, Mobile in #406-Folge-PR bzw. eigenem Issue angleichen.
4. **Lesepfad:** neuer Einmalabruf am `WorkEntryService` (eingeloggt `ApiClient.getWorkEntriesForMonth`, lokal localStorage) statt optionalem `profileId` an `getEntriesForMonth`; `ApiClient.getWorkEntriesForMonth` bekommt einen Test.
5. **Tag aus `id`:** Regel für den gesamten neuen Code; bestehende `date`-Nutzung im Dashboard als eigenes Issue (#407), nicht in #385 anfassen.
6. **Banner-Position:** unter dem Feiertagsbanner, über dem Timer (wie Mobile).
7. **Rückmeldung nach dem Beenden:** keine Snackbar, Banner verschwindet; Fokus auf stabilen Anker, einmalige Live-Ansage; kein zusätzlicher „Eintrag beendet"-Text.
8. **Plural:** zwei Keys (`…MoreOne`/`…MoreOther`), keine neue MessageFormat-Abhängigkeit.
9. **Buttons für Screenreader:** `aria-describedby` mit Titeltext (weniger Keys).
10. **PR-Schnitt:** ein Web-PR mit Commits je Schicht (Utils, Service, Reload, i18n, UI, Doku), sofern der Umfang es zulässt; sonst W1/W2 wie vorgeschlagen.
11. **Soll aus den Einstellungen des Eintragsprofils:** bei Aktionsbeginn die Einstellungen des Profils lesen, danach nur noch damit rechnen.
12. **„Später":** Schlüssel mit uid + Profil + Datum.
