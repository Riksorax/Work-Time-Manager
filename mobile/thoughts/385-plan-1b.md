# Mobile-Plan: #385 PR 1b — „Fortsetzen" eines offenen Eintrags im Banner
Research: mobile/thoughts/385-research.md (Abschnitt „Entscheidungen zu den offenen Fragen (Hauptsession)" gilt zuerst)
Vorgänger: mobile/thoughts/385-plan.md (PR 1: Banner mit Beenden/Später, gemergt als #405; Reports #404 gemergt)
Branch: claude/week-number-display-bug-x5xq8r (auf origin/develop), PR gegen `develop`

## Ziel
Der Banner (`OpenEntryBanner`) bietet für den **neuesten** offenen Eintrag vor heute zusätzlich „Fortsetzen" an, wenn der
heutige Eintrag leer ist und der offene Eintrag höchstens 24 h alt ist. Fortsetzen lädt den Vortag ins Dashboard
(„Pinning"), der Timer läuft über Mitternacht weiter (#379-Zustand), Stop speichert am Starttag und schaltet auf heute um.
Nichts ändert sich ohne Nutzeraktion; Fortsetzen schreibt selbst nichts (erst Autosave/Stop).

Nicht Teil: Web-Parität (eigener PR 2), Backend, Splitten (#381), Fortsetzen für ältere/nicht-neueste Einträge,
`resumed`-Re-Check, Scan anderer Profile.

## Ist-Stand (geprüft im Code)
- `DashboardViewModel._load(gen, dayChange)` lädt immer `getTodayWorkEntry.call()`; `_init({dayChange})` erhöht `_initGen`
  und setzt `_initRun`. `_isRunning` schützt laufende Vortage vor `_onDayChange`/`_ensureCurrentDay`. Stop eines Vortags
  macht schon `refresh()` + `_init(dayChange: true)`. `reloadAfterRetroClose()` hat bereits einen Zweig für einen laufenden
  Vortag (nur Saldo-Basis erneuern) -> bleibt unverändert und wird durch Fortsetzen erst realistisch.
- Basis: `_load` mit `dayChange: true` nimmt `storedOvertime`; bei offenem Eintrag ist `dailyAlreadyStored` immer `false`.
  Fortsetzen nutzt also genau diesen Pfad (nicht die `lastUpdated == heute`-Heuristik).
- `OpenEntryViewModel` hat `_publish()`, `_epoch`, `_loadGen`, `_candidates`, Listener auf `dashboardViewModelProvider`
  (`select(_runningDay)`); entfernt einen im Dashboard gestoppten Eintrag aus den Kandidaten. Banner: `Wrap` mit
  Später/Beenden, `busy` sperrt Buttons, 24-h-Konstante `openEntryMaxNowAge` existiert in `overtime_utils.dart`.
- Keine `GetWorkEntry`-UseCase-Klasse; der Lesezugriff auf ein Datum geht über `WorkRepository.getWorkEntry(date)`.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein | Kein Schema-Feld |
| Repository-Interface ändern? | Nein (`WorkRepository.getWorkEntry(date)` genügt) | Hybrid-, Firebase-, Local-, ApiDataSource unberührt |
| Neuer Provider? | Nein | VM-Methoden an bestehenden Notifiern; kein `@riverpod`, kein build_runner |
| Pinning-Technik | `_load(gen, dayChange, {DateTime? pinnedDate})` und `_init({dayChange, DateTime? pinnedDate})`. Mit `pinnedDate` wird statt `getTodayWorkEntry.call()` `ref.read(workRepositoryProvider).getWorkEntry(pinnedDate)` gelesen (Repo vor dem ersten `await` festhalten, wie die UseCases). Rest von `_load` unverändert, `dayChange: true` erzwungen | Kleinster Eingriff; Gen-/Stale-Prüfungen von `_load` gelten automatisch |
| Frisch lesen | Der gepinnte Eintrag wird frisch gelesen. Ist er nicht mehr `type == work && workStart != null && workEnd == null` (anderes Gerät beendet/gelöscht), wird **nicht** gepinnt; `_load` fällt auf den normalen heutigen Ladepfad zurück, `resumePastEntry` liefert `false` | Nie einen beendeten Eintrag als laufend anzeigen/überschreiben |
| Neue öffentliche VM-Methode | `Future<bool> resumePastEntry(WorkEntryEntity entry)` im `DashboardViewModel` (`true` = gepinnt, Timer läuft) | Einziger Einstieg; Banner-VM ruft sie |
| Zulässigkeit (Single Source) | Reine Funktion `canResumeOpenEntry({entry, now, todayIsEmpty})` in `domain/utils/overtime_utils.dart`: `type == work`, `workStart != null`, `workEnd == null`, Kalendertag < heute, `now - workStart <= openEntryMaxNowAge` (Grenze inklusiv wie „Jetzt"), `todayIsEmpty`. Wird im Banner-VM (Anzeige) **und** im Dashboard-VM (Durchsetzung, Zeitpunkt der Aktion) verwendet | Zwei Prüfstellen, eine Regel; Zeit kann zwischen Anzeige und Tap vergehen |
| „Heute leer" | Dashboard fertig geladen (`!isLoading`), `state.workEntry` = Tageseintrag von heute (`_dayOf(date) == today`), `workStart == null`, `type == work`. Ein heutiger Urlaub/Krank-Eintrag (`type != work`) zählt **nicht** als leer | Sonst würde ein Urlaubstag im Dashboard durch den Vortag überdeckt |
| Wann prüft `resumePastEntry` | (1) `await _initRun` (laufender Ladelauf), (2) `ref.mounted`, (3) synchron, ohne `await` dazwischen: `_loadedOk`, „heute leer", `canResumeOpenEntry`, dann `_init(pinned)`. Kein `_ensureCurrentDay()` (würde bei leerem heutigen Tag ohnehin nur nachladen und `refresh()` auslösen) | Lücke zwischen Prüfung und `_initGen`++ ist null: ein Start-Tap kann nicht dazwischen laufen. Läuft nach dem Pin ein Start-Tap, wartet seine `_ensureCurrentDay` auf `_initRun` und sieht dann einen laufenden Vortag (`startOrStopTimer` würde stoppen!) -> siehe „Race Start-Tap" |
| `_beginAction()` / `_ActionCtx` | **Nicht** nötig für Fortsetzen: kein Write (Eintrag/Saldo). Überholung läuft ausschließlich über `_initGen`/`stale()` in `_load`. Autosave/Stop nutzen danach ihre eigenen Kontexte. Im Plan/Doku ausdrücklich festhalten | Regel #388 gilt für Writes; neue Schreibaktionen gäbe es nur, wenn Fortsetzen speichern würde (tut es nicht) |
| Race Start-Tap | `resumePastEntry` setzt vor `_init` `state = state.copyWith(isLoading: true)`, damit Dashboard-Buttons während des Pinnings gesperrt sind (**vor Implementierung prüfen**, ob `dashboard_screen.dart` Buttons über `state.isLoading` sperrt; sonst entfällt der Schutz hier und der Test „Start-Tap während Pinning" dokumentiert das Verhalten). `_load` setzt `isLoading: false` per Konstruktor-State bzw. im Fehlerfall `copyWith(isLoading: false)` | Verhindert, dass ein Tap in der Ladelücke einen frisch gepinnten Lauf sofort stoppt |
| Profilwechsel | Wechsel mitten im Pinning: `onDispose` erhöht `_initGen`, `stale()` verwirft das Ergebnis, kein Write. Banner-VM: `_epoch`-Check nach dem `await`, danach kein `state=`/`_publish` | #388 |
| Saldo-Basis | gespeicherter Saldo (dayChange-Pfad); Tagesanteil = Netto(Vortag) − `_getEffectiveTargetDailyHours(entry.date)` | Entscheidung Research |
| Timer über Mitternacht | Unverändert #379: `_onDayChange`/`_ensureCurrentDay` lassen den laufenden Vortag in Ruhe | Entscheidung Research |
| Offene Pause | läuft weiter (`_calculateTotalBreakDuration` nimmt `b.end ?? now`), nichts anfassen | Entscheidung Research |
| Stop -> Reinit | bestehender Pfad (`_recalculateStateAndSave` -> `refresh()` + `_init(dayChange: true)`), nur Regressionstest | Entscheidung Research |
| Banner-Zustand | `OpenEntryState` bekommt `bool canResume` (neuester Eintrag zulässig). Berechnet in `_publish()`. Listener auf Dashboard erweitert: `select` liefert Record `(runningDay, todayEmpty)` statt nur `runningDay`, damit „heute leer" Änderungen (Start heute, Stop) den Button ein-/ausblenden | Button darf nur sichtbar sein, wenn er wirkt |
| Banner-VM-Aktion | `Future<bool> resume()`: Eintrag = `state.current`, `busy` setzen (Doppeltippen ignoriert, `null`-Entry -> `false`), `epoch`/Dashboard-Notifier **vor** dem `await` festhalten, `canResumeOpenEntry` erneut mit aktueller Uhr/Dashboard-State prüfen, `await dashboard.resumePastEntry(entry)`, nach dem `await` bei Überholung nichts tun, sonst `busy: false` + `_publish()`. Bei Erfolg blendet der bestehende Listener (`_runningDay` == Entry-Tag) den Banner aus; **kein** `_load()` (keine Zusatz-Reads), „Später"-Schlüssel nicht anfassen | Kein Re-Check nötig: Eintrag ist jetzt der laufende Dashboard-Eintrag |
| Fehler/Ablehnung | `false` ohne Snackbar und ohne neuen Text: Banner wird neu veröffentlicht (Button verschwindet, wenn nicht mehr zulässig); Ladefehler werden vom Dashboard-VM geloggt. Dokumentierte Grenze | Kein zusätzlicher ARB-Key über den Research-Umfang hinaus; (falls gewünscht: Snackbar mit vorhandenem Text wäre irreführend) |
| Premium-Gate? | Nein | Datensicherheit |
| Pro Arbeitszeit-Profil? | Implizit über `workRepositoryProvider` (aktives Profil) | #388 |
| Backend-Änderung? | Nein; keine Firestore-Pfade, keine Rules | |
| Neue Texte? | Ja: `openEntryContinue` („Fortsetzen"/„Continue") und `openEntryContinueSemantics` (`{date}`, Muster der bestehenden `openEntryEndSemantics`/`openEntryLaterSemantics`) | #221; das Semantics-Label ist Folge des Banner-Musters |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `lib/domain/utils/overtime_utils.dart` | geändert | `canResumeOpenEntry(...)` (nutzt `openEntryMaxNowAge`) |
| `lib/presentation/view_models/dashboard_view_model.dart` | geändert (heikel) | `pinnedDate` in `_init`/`_load`, `resumePastEntry`; sonst nichts |
| `lib/presentation/view_models/open_entry_view_model.dart` | geändert | `canResume` im State, `_publish`, Listener-Select, `resume()` |
| `lib/presentation/widgets/open_entry_banner.dart` | geändert | Button „Fortsetzen" (nur bei `canResume`) |
| `lib/l10n/app_de.arb`, `app_en.arb` (+ generierte `app_localizations*.dart`) | geändert | 2 Keys |
| `mobile/CLAUDE.md` | geändert | Abschnitt #385: Fortsetzen, Grenzen aktualisieren |
| `test/domain/utils/open_entry_resume_utils_test.dart` | neu | Zulässigkeit |
| `test/presentation/view_models/dashboard_view_model_resume_test.dart` | neu | Pinning, Saldo, Races |
| `test/presentation/view_models/open_entry_view_model_test.dart` | geändert | `canResume`, `resume()` |
| `test/presentation/widgets/open_entry_banner_test.dart` | geändert | Button, A11y |
| `test/presentation/screens/dashboard_screen_open_entry_test.dart` | geändert | Ende-zu-Ende mit echtem VM |
| `test/l10n/open_entry_arb_test.dart` | geändert | neue Keys de/en |

## Test-Rahmen
Wie PR 1: feste Daten (Fr 2026-10-02, Sa 2026-10-03, So 2026-10-04, Monatsgrenze 2026-10-31/11-01, DST-Invarianten
2026-10-25/2026-03-29), `FakeClock`, In-Memory-Repos, `Harness(profiles: true)` (`h.switchProfile`, `holdReads`,
`holdSaves`, `holdOvertimeLoad`, `failSaveOvertime`, `writeLog`), VM-Tests in `fakeAsync`, am Ende dispose + Timer-Zähler.
`TestWidgetsFlutterBinding.ensureInitialized()`. Läufe unter `TZ=Europe/Berlin`, am Ende zusätzlich `UTC`,
`America/Los_Angeles`, `Pacific/Auckland`. Rot-Nachweis je Schritt (Test zuerst, Fehlschlag festhalten), Mutationsproben
in Schritt 6. Screen-Tests, die `DashboardScreen` pumpen, überschreiben weiter `openEntryViewModelProvider` (außer dem
Ende-zu-Ende-Test mit echtem VM).

## Schritte (TDD)

### Schritt 1: Domain — `canResumeOpenEntry`
- [x] Tests `open_entry_resume_utils_test.dart`:
  - Fr 22:00 offen, jetzt Sa 09:00, heute leer -> `true`
  - heute nicht leer -> `false`; Typ vacation/sick/holiday -> `false`; `workStart == null` -> `false`; `workEnd != null` -> `false`
  - Eintrag heute (nicht vor heute) -> `false`
  - Alter genau 24 h -> `true`; 24 h + 1 min -> `false` (Grenze inklusiv wie `suggestOpenEntryEnd`)
  - Kalendertag-Vergleich um Mitternacht (jetzt 00:30 vs. 23:30 am Eintragstag+1) TZ-invariant; DST-Tag 2026-10-25: Alter über absolute Differenz
- [x] Impl in `overtime_utils.dart` (Konstante wiederverwenden).

### Schritt 2: Dashboard-VM — Pinning und `resumePastEntry`
- [x] Tests `dashboard_view_model_resume_test.dart` (Harness `profiles: true`, `fakeAsync`; Fr-Eintrag 22:00 offen im Repo, Uhr Sa 09:00, heute leer):
  - **Happy Path:** `resumePastEntry` -> `true`; `state.workEntry` = Freitag, Timer läuft (`isTimerRunning`), `elapsedTime` ab Fr 22:00 (nach `tick`), `isExtraDay`/Soll vom **Starttag** (Fr Arbeitstag vs. Sa-Start Zusatztag als zweiter Fall)
  - **Saldo-Basis:** `initialOvertime == storedOvertime`, auch wenn `lastUpdated == heute` (Heuristik-Falle); `totalOvertime = stored + (Netto bis jetzt − Soll(Fr))`
  - **Offene Pause** (Pause 23:00 ohne Ende): bleibt offen, Pausenzeit wächst mit der Uhr
  - **Über Mitternacht weiter:** `FakeClock.jumpTo` auf Folgetag + `todayProvider`-Wechsel -> kein Reinit, Eintrag/Timer bleiben (Regression #379)
  - **Autosave:** nach 30 s `elapsed` wird der **Freitags**-Eintrag (nicht Samstag) gespeichert, `writeLog` Label A
  - **Stop:** `startOrStopTimer` -> Saldo `stored + Tagesanteil`, Eintrag am Freitag mit `workEnd`, danach Reinit auf heute (leerer Samstag, `initialOvertime` = neuer gespeicherter Saldo)
  - **Ablehnung ohne Zustandsänderung:** heute schon Eintrag mit `workStart` -> `false`; heute `type == vacation` -> `false`; Eintrag 24 h + 1 min alt -> `false`; Dashboard noch nicht erfolgreich geladen (`holdReads`/`failReads`) -> `false`; Vorfall: State/Timer/`writeLog` unverändert
  - **Frisch lesen:** Repo liefert den Eintrag inzwischen beendet (anderes Gerät) -> `false`, Dashboard zeigt heute (leer), nichts gepinnt, `writeLog` leer
  - **Lesefehler** beim Pinnen (`failReads` nur auf dem Vortags-Read): `false`, Dashboard bleibt benutzbar (`isLoading == false`), geloggt, `_loadedOk`-Pfad: nächste Aktion lädt heute nach
  - **Wartet auf Ladelauf:** `resumePastEntry` während laufendem `_init` (`holdReads`) wartet ab, prüft danach „heute leer"
  - **Profilwechsel mitten im Pinnen** (`holdReads` auf dem Vortags-Read, `h.switchProfile('b')`, Read freigeben): Ergebnis verworfen, State gehört dem Profil B (leer/heute), kein Timer aus A, `writeLog` ohne Write
  - **Doppelter Aufruf:** zweiter `resumePastEntry` direkt danach -> `false` (heute nicht mehr „leer", Dashboard-Eintrag ist der Vortag), ein Timer
  - **Race Start-Tap:** `startOrStopTimer` während das Pinnen läuft (`holdReads`) stoppt den gepinnten Lauf **nicht** (Buttons gesperrt bzw. Aktion wartet und lässt den Lauf unangetastet; Erwartung an das tatsächliche Verhalten anpassen und festschreiben)
  - **Folge `reloadAfterRetroClose()`** mit gepinntem Vortag: bestehender Zweig erneuert nur `initialOvertime` (Regression)
  - Regression: `dashboard_view_model_day_change_test.dart`, `_profile_test.dart`, `_save_error_test.dart`, `_switch_test.dart`, `dashboard_view_model_reload_test.dart` unverändert grün
- [x] Impl: `_init({bool dayChange = false, DateTime? pinnedDate})`, `_load(gen, dayChange, {pinnedDate})` (Read per `workRepositoryProvider.getWorkEntry(pinnedDate)`, Pinned-Validierung, Fallback auf heute), `resumePastEntry`. `onDispose`/`_ensureCurrentDay`/`_onDayChange`/Stop-Pfad **nicht** ändern. `_loadedOk`/`isLoading`-Verhalten wie oben festgelegt. Keine `ref.read(...)` nach `await`, die ein Write-Ziel bestimmen (es gibt keine Writes).
- [x] Mutationsproben: (a) `dayChange: true` beim Pinnen entfernen -> Saldo-Basis-Test mit `lastUpdated == heute` rot, (b) Soll von `now` statt `entry.date`, (c) 24-h-Prüfung im VM entfernen, (d) „heute leer"-Prüfung entfernen, (e) Frisch-Lesen-Validierung entfernen, (f) `stale()`-Prüfung nach dem Pinned-Read entfernen (Profilwechsel-Test rot).

### Schritt 3: Banner-VM — `canResume` und `resume()`
- [x] Tests (Ergänzung `open_entry_view_model_test.dart`, Harness `profiles: true`):
  - Vortag offen, heute leer, <= 24 h -> `state.canResume == true`; > 24 h -> `false` (Beenden bleibt); heute nicht leer -> `false`; Dashboard lädt noch -> `false`
  - Start heute (Dashboard-VM startet Timer) -> `canResume` wird `false`, Stop heute -> bleibt `false` (heute nicht leer); Uhrsprung über die 24-h-Grenze + Neuveröffentlichung (Tageswechsel via `FakeClock.jumpTo`) -> `false`
  - Mehrere Kandidaten: `canResume` bezieht sich auf `current` (neuesten); Älterer wird erst nach Auflösung des neuesten angeboten
  - `resume()` Erfolg: Dashboard pinnt den Eintrag, Banner verschwindet (läuft im Dashboard, `_runningDay`), `busy` zurück `false`, **keine** zusätzlichen Monats-Reads (`monthReads` unverändert), Dismissed-Set unverändert
  - Nach Stop im Dashboard: Eintrag nicht mehr Kandidat, Banner leer (Regression der bestehenden Listener-Logik), nächster offener (älterer) Eintrag erscheint erst nach `_load` (Tageswechsel/Re-Check) -> Verhalten festschreiben
  - `resume()` abgelehnt (Dashboard sagt `false`): `busy: false`, Banner bleibt sichtbar, `canResume` neu berechnet, kein `saveError`
  - `resume()` ohne Kandidat -> `false`; Doppeltippen (`busy`) -> zweiter Aufruf ignoriert (genau ein `resumePastEntry`-Aufruf)
  - Profilwechsel mitten im `resume()` (`holdReads`): kein State-/`_publish`-Schreiben im neuen Profil, kein Fehlerzustand; neuer Suchlauf für Profil B
  - „Später" gedrückt -> Banner weg; `resume()` danach (kein Kandidat sichtbar) -> `false`
- [x] Impl: State-Feld `canResume` (in `copyWith`/`props`), `_publish`, erweiterter Listener-Select, `resume()`. `ref.watch(todayProvider)` weiterhin nicht (nur `listen`).
- [x] Mutationsproben: (a) `canResume` ignoriert „heute leer", (b) `resume()` ohne `busy`-Sperre, (c) nach `await` ohne `overtaken()`-Prüfung publizieren, (d) zusätzlicher `_load()` nach Erfolg -> Read-Zähler-Test rot.

### Schritt 4: Texte
- [x] ARB-Keys `openEntryContinue` („Fortsetzen"/„Continue", `@key`-Beschreibung) und `openEntryContinueSemantics` (`{date}`; de duzend/neutral, z. B. „Eintrag vom {date} fortsetzen"/„Continue entry from {date}") in `app_de.arb` + `app_en.arb`.
- [x] `flutter gen-l10n`; `open_entry_arb_test.dart` um beide Keys erweitern (de/en vorhanden, Platzhalter `date`).

### Schritt 5: Presentation — Banner
- [x] Widget-Tests (`open_entry_banner_test.dart`, `MaterialApp` mit `AppLocalizations`-Delegates, `Locale('de')`/`en`, feste Fake-VM-States):
  - `canResume == true` -> Button „Fortsetzen"/„Continue" neben Beenden/Später; `false` -> kein Button
  - Tap ruft `resume()` genau einmal; `busy` deaktiviert alle drei Buttons
  - Semantik: eigenes Label mit Datum, `button: true`, Mindestgröße 48 dp, einzeln fokussierbar, Reihenfolge Später, Beenden, Fortsetzen
  - schmale Breite 320 px, Textskalierung 2.0: kein Overflow (`Wrap` bricht um); Dark Mode ohne hartcodierte Farben (Rollen wie bisher)
  - Fortsetzen löst keinen Dialog und keine Snackbar aus
- [x] Screen-Test (`dashboard_screen_open_entry_test.dart`, echtes `DashboardViewModel` + `OpenEntryViewModel` mit Fakes, de): Banner mit Fortsetzen -> Tap -> Dashboard zeigt laufenden Timer mit Vortag-Startzeit, Banner weg, Stop-Button sichtbar; Banner ohne Fortsetzen bei vorhandenem heutigen Eintrag; Dashboard bleibt bedienbar
- [x] Impl in `open_entry_banner.dart`: `FilledButton.tonal`/`FilledButton` für „Fortsetzen" (Beenden bleibt sekundär; Hierarchie: Später Text, Beenden Outlined/Tonal, Fortsetzen Filled — endgültige Wahl im UI-Review), `l10n` am Anfang von `build()`.

### Schritt 6: Doku und Gesamtvalidierung
- [x] `mobile/CLAUDE.md`, Abschnitt „Offene Einträge vor heute (#385)": Fortsetzen (Bedingungen, Pinning in `_load`, Basis `dayChange`, kein Write/kein `_ActionCtx`, Frisch-Lesen, Race-Schutz), Grenze „Fortsetzen kommt als PR 1b" ersetzen; in „Tageswechsel (#379)" einen Satz: ein laufender Vortag kann auch über „Fortsetzen" ins Dashboard kommen. Bekannte Grenzen: nur der neueste Eintrag, nur bei leerem heutigen Tag und <= 24 h, stiller Fehlschlag ohne Hinweis, Web-Parität folgt.
- [x] Mutationstabelle abgearbeitet (jede Mutation rot, dann zurückgenommen; Ergebnis im Review-Protokoll).
- [x] Zeitzonenläufe der neuen/geänderten Tests: `Europe/Berlin`, `UTC`, `America/Los_Angeles`, `Pacific/Auckland`.


### Umsetzungsprotokoll
- Befund `isLoading`: `dashboard_screen.dart` sperrt Start/Stop **nicht** über `state.isLoading`. `resumePastEntry` setzt `isLoading: true` trotzdem (Banner-VM wertet es aus); der Test „Tap in der Ladelücke" in `dashboard_view_model_resume_test` schreibt fest, dass ein Tap während des Pinnens auf den Pin wartet und den gepinnten Lauf dann stoppt (offene Grenze).
- Mutationsproben Dashboard: (a) dayChange, (b) Soll von now, (c) 24-h-Prüfung, (d) „heute leer", (e) Frisch-Lesen jeweils rot. (f) `stale()` direkt nach dem Pinned-Read ist redundant (die nächste Zeile `stale()` fängt es ab), daher nicht unterscheidbar.
- Mutationsproben Banner-VM: (a) „heute leer" ignorieren und (d) zusätzliches `_load()` rot. (b) `busy`-Sperre und (c) `overtaken()`-Prüfung bleiben grün: das Dashboard (`isLoading` -> Neuprüfung scheitert) bzw. Equatable-Gleichheit des State machen sie unbeobachtbar; sie bleiben als Defensive.
- Beenden ist bei `canResume` ein `OutlinedButton` (Banner-Farben), sonst unverändert `FilledButton`; Fortsetzen ist `FilledButton`.
- Bestandstest geändert: `open_entry_arb_test` hatte `isNot(contains('openEntryContinue'))` (PR-1b-Platzhalter), jetzt Gegenteil.
- Checks: format ok, analyze Exit 0 (24 Infos, keine warning), custom_lint ok, `flutter test` 1145 grün unter Europe/Berlin, UTC, America/Los_Angeles, Pacific/Auckland.
## Risiken
| Risiko | Umgang |
|---|---|
| Race-sensibles `DashboardViewModel` (#379/#388) | Eine neue Methode + ein optionaler Parameter; Prüfung und `_init` ohne `await` dazwischen; alle bestehenden Dashboard-Tests als Regression |
| Stop in der Ladelücke (Start-/Stop-Tap vs. Pinning) | `isLoading` während Pinning (nach Prüfung des Screens), Test legt Verhalten fest |
| Profilwechsel während Pinnen | `_initGen`-/`stale()`-Prüfung, `_epoch` im Banner-VM, Tests mit `holdReads` + `switchProfile` |
| Saldo falsch durch `lastUpdated`-Heuristik | `dayChange: true`, Test mit `lastUpdated == heute` + Mutationsprobe |
| Anderes Gerät hat den Eintrag beendet/fortgesetzt | Frisch lesen; Last-Write-Wins des Autosaves bleibt bekannte Grenze |
| Stille Ablehnung ohne Rückmeldung | Bewusst (kein neuer Text); Button verschwindet; dokumentiert |
| Frozen-Eintrag aus Profilwechsel (#388) | Rückkehr ins Profil zeigt Banner mit Fortsetzen (wenn <= 24 h), sonst nur Beenden |

## Validierung
- `dart format --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`
- `dart run custom_lint`
- `flutter test` (CI-TZ Europe/Berlin) + neue Tests unter UTC/LA/Auckland
- `flutter gen-l10n` ohne Diff danach; build_runner nicht nötig (kein `@riverpod` geändert)

## Offene Fragen
Keine blockierenden. Zur Kenntnis (Plan-Defaults, in der Implementierung zu bestätigen):
1. Stille Ablehnung/Fehler ohne Snackbar (kein zusätzlicher ARB-Key); bei Bedarf eigener Key `openEntryContinueError`.
2. Zweiter neuer Key `openEntryContinueSemantics` (Research nennt nur `openEntryContinue`).
3. Heutiger Eintrag mit `type != work` ohne `workStart` gilt nicht als „leer".
