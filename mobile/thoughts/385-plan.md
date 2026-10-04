# Mobile-Plan: #385 — Banner für verwaiste offene Einträge (PR 1: „Beenden" + „Später")
Research: mobile/thoughts/385-research.md (Abschnitt „Entscheidungen zu den offenen Fragen (Hauptsession)" gilt vor allem anderen)

## Ziel
Beim Start, bei Profil-/Auth-Wechsel und bei Tageswechsel zeigt das Dashboard einen nicht-modalen Banner für den
neuesten offenen Eintrag vor heute (aktives Profil, aktueller + Vormonat). Der Nutzer beendet ihn mit gewähltem
Ende (Saldo korrekt fortgeschrieben) oder wählt „Später" (nur Sitzung). Nichts ändert sich ohne Nutzeraktion.

Nicht Teil: Fortsetzen (PR 1b), Web-Parität, Backend, Reports-Darstellung (#404), Scan anderer Profile, `resumed`-Re-Check,
Splitten (#381).

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein. Ergebnis-Typen (`CloseOpenEntryResult` Enum) nur im Use Case | Kein Schema-Feld, kein Backend-/Web-Vertrag |
| Repository-Interface ändern? | Nein. Nur `WorkRepository.getWorkEntriesForMonth`, `saveWorkEntry`, `OvertimeRepository.ensureOvertimeLoaded/saveOvertime` | Hybrid-, Firebase-, Local- und ApiDataSource bleiben unberührt |
| Neuer Provider? | UseCase-Provider per `@riverpod` in `providers.dart` (`getOpenPastWorkEntriesUseCase`, `closeOpenWorkEntryUseCase`, watchen `workRepositoryProvider`/`overtimeRepositoryProvider`/`clockProvider`) -> `build_runner`. ViewModel `OpenEntryViewModel` manuell als `NotifierProvider` in `presentation/view_models/open_entry_view_model.dart` (nicht codegen) | Regel aus `mobile/CLAUDE.md`. Profilbindung kommt automatisch über das Repo des aktiven Profils |
| „Später"-Speicher | Eigener kleiner `NotifierProvider<Set<String>>` (`openEntryDismissedProvider`), Schlüssel `profileId|yyyy-MM-dd`, ohne Abhängigkeit zu Repo/Profil | Überlebt den Rebuild des VM bei Profil-/Auth-/Tageswechsel sicher (keine Annahme über Notifier-Felder bei Rebuild); nicht persistent |
| Soll am Eintragsdatum | Use Case bekommt `dailyTarget` als Parameter; der VM berechnet es aus `settingsRepositoryProvider` + `getEffectiveDailyTarget(date: entry.date)` (gleiche Formel wie `_getEffectiveTargetDailyHours`, nicht aus dem Dashboard-VM aufrufbar -> kleine reine Funktion `effectiveTargetForDate(settings, date)` in `domain/utils/overtime_utils.dart`; `DashboardViewModel` bleibt unverändert) | Domain bleibt ohne Settings-Abhängigkeit; Eingriff im Dashboard-VM minimal |
| Eingriff `DashboardViewModel` | Genau eine öffentliche Methode `reloadAfterRetroClose()` = `_init(dayChange: true)` (Signatur vor Implementierung gegen `_init` prüfen) plus Guard-Test. Kein Pinning | Saldo-Basis `initialOvertime` muss den neuen Saldo enthalten, sonst überschreibt der nächste Stop das Delta |
| Premium-Gate? | Nein | Datensicherheit, keine Zusatzfunktion (Entscheidung 13) |
| Pro Arbeitszeit-Profil? | Ja, implizit: Suche über `workRepositoryProvider`; Beenden hält Repos/Settings am Aktionsbeginn fest (Muster `_ActionCtx`, kein `ref.read` nach `await`) | #388 |
| Backend-Änderung nötig? | Nein | Keine neuen Firestore-Pfade, keine Rules-Änderung |
| Neue Texte? | Ja, ARB de (duzen) + en, Keys aus Research Abschnitt (4) ohne `openEntryContinue` (kommt in PR 1b) | #221 |
| Reihenfolge Writes beim Beenden | Saldo zuerst, dann Eintrag (wie Stop-Pfad) | Bei Fehler bleibt Eintrag offen, Banner bleibt, Aktion wiederholbar |
| Abweichung von Layer-Reihenfolge | ARB-Keys (Schritt 5) vor den Widgets (Schritt 6), weil Widgets `AppLocalizations` kompilieren müssen | Sonst nicht kompilierbar |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `lib/domain/usecases/get_open_past_work_entries.dart` | neu | Suche (aktueller + Vormonat), Filter, Sortierung, Clock-Konstruktor |
| `lib/domain/usecases/close_open_work_entry.dart` | neu | Beenden ohne Dashboard-State, Saldo-Delta |
| `lib/domain/utils/overtime_utils.dart` | geändert | `effectiveTargetForDate(...)`, `suggestOpenEntryEnd(...)` (reine Funktionen: Soll-Ende, „Jetzt"-Zulässigkeit) |
| `lib/core/providers/providers.dart` (+ `providers.g.dart` generiert) | geändert | UseCase-Provider |
| `lib/presentation/view_models/open_entry_view_model.dart` | neu | State, Dismissed-Provider, Aktionen `load`, `later`, `endEntry` |
| `lib/presentation/view_models/dashboard_view_model.dart` | geändert (minimal) | `reloadAfterRetroClose()` |
| `lib/presentation/widgets/open_entry_banner.dart` | neu | Banner |
| `lib/presentation/widgets/open_entry_end_dialog.dart` | neu | Dialog Datum + Zeit |
| `lib/presentation/screens/dashboard_screen.dart` | geändert | Banner neben `HolidayBanner` (Zeilen ~185, ~217) |
| `lib/l10n/app_de.arb`, `app_en.arb` (+ generierte `app_localizations*.dart`) | geändert | Texte |
| `mobile/CLAUDE.md` | geändert | Abschnitt „Offene Einträge vor heute (#385)", Grenze (2) in #388 aktualisieren |
| Tests: `test/domain/usecases/get_open_past_work_entries_test.dart`, `close_open_work_entry_test.dart`, `test/domain/utils/open_entry_end_suggestion_test.dart`, `test/presentation/view_models/open_entry_view_model_test.dart`, `dashboard_view_model_reload_test.dart`, `test/presentation/widgets/open_entry_banner_test.dart`, `open_entry_end_dialog_test.dart`, `test/presentation/screens/dashboard_screen_open_entry_test.dart` | neu | siehe Schritte |

## Test-Rahmen (gilt für alle Schritte)
- Feste Daten: Fr 2026-10-02, Sa 2026-10-03, So 2026-10-04; Monatsgrenze 2026-10-31/2026-11-01; DST-Invarianten 2026-10-25 / 2026-03-29. Kein `DateTime.now()`, `FakeClock` (`test/support/fake_clock.dart`), In-Memory-Repos (`fake_repositories.dart`), `Harness` für VM-Tests.
- VM-/Provider-Tests in `fakeAsync`, `TestWidgetsFlutterBinding.ensureInitialized()`, am Ende dispose + Timer-Zähler.
- Lauf je Schritt: `flutter test <Datei>` unter `TZ=Europe/Berlin` (CI); vor Abschluss zusätzlich `TZ=UTC`, `America/Los_Angeles`, `Pacific/Auckland` für die gesamte neue Testmenge.
- **Rot-Nachweis:** Je Schritt Tests zuerst schreiben, laufen lassen und das Fehlschlagen (Symbol fehlt / Assertion rot) im Thoughts-/Commit-Protokoll festhalten, erst dann implementieren, dann grün.
- **Mutationsproben:** je Kernlogik eine gezielte Mutation, Test muss rot werden, danach Mutation zurücknehmen (siehe Schritt 7 Tabelle).

## Schritte (TDD)

### Schritt 1: Domain — Suche `GetOpenPastWorkEntries`
- [ ] Tests (`test/domain/usecases/get_open_past_work_entries_test.dart`, FakeWorkRepository, FakeClock):
  - Fr 22:00 offen, jetzt Sa 09:00 -> 1 Treffer
  - heute offen -> kein Treffer; Eintrag mit Datum morgen/Zukunft -> kein Treffer (Uhrsprung)
  - abgeschlossen -> kein Treffer; `workStart == null` -> kein Treffer; Typ vacation/sick/holiday mit `workEnd == null` -> kein Treffer
  - Monatsgrenze: jetzt 2026-11-01 08:00, offen 2026-10-31 -> Treffer (Vormonat gelesen); jetzt 2026-01-05 liest 2025-12 (Jahreswechsel); Vor-Vormonat wird nicht gelesen (Lese-Log des Fakes prüfen)
  - mehrere offene Einträge in beiden Monaten -> Sortierung neuester zuerst (auch bei unsortierter Repo-Antwort)
  - Tag-Vergleich per Kalendertag: Eintrag `date` mit Uhrzeitanteil/UTC-Offset nahe Mitternacht zählt als sein Kalendertag; „heute" um 00:30 vs. 23:30 gleiches Ergebnis (TZ-Invariante)
  - Lesefehler eines Monats: anderer Monat liefert weiter Treffer, kein Crash, `logger.e` ohne Eintragsinhalte; beide Fehler -> leere Liste
  - Parameter `excludeDate` (laufender Dashboard-Eintrag) wird nicht zurückgegeben
- [ ] Impl: Konstruktor `(WorkRepository, {DateTime Function() clock = DateTime.now})` wie `GetTodayWorkEntry`; `call({DateTime? excludeDate})` -> `List<WorkEntryEntity>`; Monate parallel oder nacheinander lesen, jeder Monat in eigenem try/catch.
- [ ] Mutationsproben: (a) `workEnd == null`-Filter entfernen, (b) `< today` auf `<= today`, (c) Typfilter entfernen, (d) Vormonat weglassen, (e) Sortierung umdrehen. Jeweils muss mindestens ein Test rot werden.

### Schritt 1b: Domain — reine Funktionen
- [ ] Tests (`test/domain/utils/open_entry_end_suggestion_test.dart`):
  - Soll-Ende = `workStart + Soll + Summe geschlossener Pausen`, per Duration-Addition (DST-Tag 2026-10-25: Invariante über absolute Differenz, nicht Wanduhr)
  - Soll-Ende < jetzt -> Vorschlag Soll-Ende; Soll-Ende >= jetzt und Eintrag <= 24 h alt -> Vorschlag „Jetzt"; Soll-Ende >= jetzt und > 24 h -> Soll-Ende gekappt/Picker ohne „Jetzt" (siehe offene Frage 1)
  - Soll = 0 (Wochenende/Zusatztag): kein sinnvolles Soll-Ende -> Vorschlag „Jetzt" nur bei <= 24 h, sonst Start + keine Vorbelegung (Picker leer-nah, Validierung greift)
  - „Jetzt" zulässig bei genau 24 h (Grenze), unzulässig bei 24 h + 1 min
  - `effectiveTargetForDate`: Arbeitstag -> Tagessoll, Nicht-Arbeitstag -> 0, leere Arbeitstage -> 0, Runden wie Dashboard
- [ ] Impl in `overtime_utils.dart`.
- [ ] Mutationsprobe: 24-h-Grenze (`<=` -> `<`), Pausen nicht addieren.

### Schritt 2: Domain — `CloseOpenWorkEntry`
- [ ] Tests (`test/domain/usecases/close_open_work_entry_test.dart`; FakeWork-/FakeOvertimeRepository mit gemeinsamem `writeLog`):
  - Ende gesetzt (auf Minute gerundet wie `roundToMinute`), gespeicherter Eintrag hat `workEnd == end`
  - offene Pause: `end` der Pause = gewähltes Ende; geschlossene Pausen unverändert
  - Auto-Pausen: Typ work, 10 h brutto ohne Pause -> Auto-Pause(n) wie `BreakCalculatorService.calculateAndApplyBreaks`; Ergebnis identisch zum Stop-Pfad (Vergleich gegen direkten Aufruf); kein Auto-Break bei kurzem Eintrag
  - Saldo: `neu = alt + (netto - Soll)` mit Netto nach Auto-Pausen und geschlossener Pause; Soll des **Eintragsdatums** (Samstag/Zusatztag: Soll 0 -> volle Netto-Dauer; Arbeitstag mit Soll 8 h)
  - `saveLastUpdateDate` wird **nie** aufgerufen und `getLastUpdateDate` bleibt unverändert (writeLog enthält kein `lastUpdate`)
  - Reihenfolge writeLog: `overtime` vor `entry`
  - Validierung ohne Writes: `end <= workStart`, `end > now`, `end < letzter Pausenstart` -> Ergebnis `invalidEnd`, writeLog leer
  - Soft-Warnung > 16 h blockiert nicht (Use Case schließt; Warnung ist UI)
  - Frisch lesen: Repo liefert beim erneuten Lesen schon `workEnd != null` (anderes Gerät/Doppelklick) -> `alreadyClosed`, keine Writes; zweiter Aufruf nach Erfolg -> `alreadyClosed`, Saldo wird nicht doppelt gezählt
  - Fehlerpfade: `failSaveOvertime` -> Eintrag bleibt offen (kein Entry-Write), Ergebnis `failed`, Exception wird gefangen und geloggt; Entry-Save schlägt nach erfolgreichem Saldo fehl -> Ergebnis `failed` (Rest-Risiko Teilfehler dokumentieren, wie #402); Lesefehler beim frischen Lesen -> `failed` ohne Writes
  - Offline (Repo wirft Netzwerk-Exception): `failed`, kein Teilzustand außer oben benanntem Rest-Risiko
  - Typ != work oder `workStart == null` -> `invalidEntry`, keine Writes
  - Profil-Kapselung: UseCase mit Repo A konstruiert, danach „Profilwechsel" (Repo B existiert) -> Writes landen ausschließlich in A (writeLog-Labels)
- [ ] Impl: Konstruktor `(WorkRepository, OvertimeRepository, {clock})`, `call(entry, end, dailyTarget)` -> `CloseOpenEntryResult` (`closed`, `alreadyClosed`, `invalidEnd`, `invalidEntry`, `failed`). Ablauf: validieren -> Eintrag frisch lesen (`getWorkEntriesForMonth` des Eintragsmonats, per Datum finden) -> Pause schließen -> Auto-Pausen -> Saldo lesen (`ensureOvertimeLoaded`) -> `saveOvertime` -> `saveWorkEntry`. Keine Logs mit Eintragsinhalten.
- [ ] Mutationsproben: (a) `saveLastUpdateDate` einbauen -> Test rot, (b) Saldoformel `+` -> `-` bzw. Soll vom heutigen Tag statt Eintragsdatum, (c) Pause nicht schließen, (d) Auto-Pause-Aufruf entfernen, (e) Reihenfolge Entry vor Saldo, (f) Frisch-lesen-Guard entfernen.

### Schritt 3: Provider
- [ ] Verdrahtung in `lib/core/providers/providers.dart`: `getOpenPastWorkEntriesUseCase(Ref)` und `closeOpenWorkEntryUseCase(Ref)` mit `workRepositoryProvider`, `overtimeRepositoryProvider`, `clockProvider`.
- [ ] `dart run build_runner build --delete-conflicting-outputs`
- [ ] Test: Provider-Test mit `ProviderContainer(overrides)`: Profilwechsel (`Harness(profiles: true)`, `h.switchProfile`) liefert neue UseCase-Instanz mit Repo des neuen Profils.

### Schritt 4: ViewModel-Zustand + Dashboard-Reload
- [ ] Tests `open_entry_view_model_test.dart` (Harness, FakeClock, `fakeAsync`):
  - Start mit offenem Vortag -> State enthält Eintrag, Zähler `moreCount == n-1`, Reihenfolge neuester zuerst
  - „Später" blendet den aktuellen aus, der nächste (falls vorhanden) wird sichtbar? **Entscheidung:** „Später" blendet den Banner komplett für diese Sitzung aus (alle Kandidaten des Profils), siehe offene Frage 2; Test entsprechend
  - Später gilt je Profil + Eintrag: Profilwechsel A->B->A hält A weiter ausgeblendet, B ist unabhängig; nach Neuerstellung des `ProviderContainer` (neuer Start) erscheint er wieder
  - Profilwechsel (`h.switchProfile`) sucht im neuen Profil (Reads im richtigen Repo), alter Zustand verworfen, spätes Ergebnis des alten Profils überschreibt nicht (`holdReads`, Generationsprüfung)
  - Tageswechsel (`FakeClock.jumpTo` + `todayProvider`): Einträge werden neu gesucht; `ref.listen`, kein `ref.watch(todayProvider)` (Zustand/Dismissed bleibt)
  - im Dashboard laufender Eintrag (`state.workEntry` mit `workStart != null`, `workEnd == null`, Datum Vortag, #379 Lauf über Mitternacht) erzeugt keinen Banner; nach Stop erscheint er nicht (abgeschlossen)
  - `endEntry(end)` erfolgreich: Use-Case-Aufruf mit Soll vom Eintragsdatum, danach Re-Check (nächster offener wird sichtbar), `dashboardViewModel.reloadAfterRetroClose()` aufgerufen
  - `endEntry` Fehler/`failed`: Banner bleibt, Fehlerzustand (`saveError`) gesetzt für Snackbar, kein Reload
  - Aktion hält Use Case/Settings am Aktionsbeginn fest: Profilwechsel mitten in `endEntry` (`holdSaves`) -> Writes im Profil des Beginns, State des neuen Profils unverändert, kein Reload des neuen Dashboards
  - Doppeltippen: zweiter `endEntry` während laufender Aktion wird ignoriert (`busy`-Flag)
  - Lesefehler der Suche -> kein Banner, kein Crash
- [ ] Tests `dashboard_view_model_reload_test.dart` (nutzt Harness):
  - Beenden mit **heute laufendem Timer**: nach `reloadAfterRetroClose()` Timer läuft weiter, `initialOvertime` = neuer gespeicherter Saldo, Stop danach speichert `neuer Saldo + Tagesanteil` (Delta des Vortags bleibt erhalten)
  - Beenden mit **heute bereits abgeschlossenem und gespeichertem Eintrag**: kein Doppelzählen (`dailyAlreadyStored`-Pfad)
  - `lastUpdated == heute` (nach heutigem Stop gesetzt) bleibt nach Retro-Beenden unverändert, Reload zieht heute nicht doppelt ab
  - Reload bei leerem heutigen Eintrag: Zustand = leerer Tag, Saldo = neuer Wert
  - Regression: bestehende `dashboard_view_model_day_change_test.dart` und `_profile_test.dart` unverändert grün
- [ ] Impl: `open_entry_view_model.dart` (State-Klasse, `OpenEntryViewModel`, `openEntryViewModelProvider`, `openEntryDismissedProvider`); in `build()` `ref.watch(workRepositoryProvider)`/UseCase, `ref.watch(activeWorkProfileIdProvider)`, `ref.listen(todayProvider, ...)`, `ref.listen(dashboardViewModelProvider.select(laufender Eintrag-Datum), ...)` (nur Auslöser einer Neubewertung, kein Reload der Repo-Reads: Ausschluss per `excludeDate`-Filter im Speicher, damit keine zusätzlichen Reads); eigene Generationszählung gegen späte Ergebnisse. Im `DashboardViewModel` nur `reloadAfterRetroClose()` ergänzen (ohne Gen-/Action-Logik zu ändern).
- [ ] Mutationsproben: (a) Später-Filter entfernen -> Banner trotz „Später" sichtbar -> Test rot, (b) Dismissed-Schlüssel ohne Profil-ID, (c) Ausschluss laufender Dashboard-Eintrag entfernen, (d) Reload nach Beenden weglassen -> Saldo-Test rot, (e) `ref.watch(todayProvider)` statt listen -> Dismissed-/Zustandsverlust-Test rot (optional).

### Schritt 5: Texte
- [ ] ARB-Keys in `app_de.arb` (mit `@key`-Beschreibung, `{date}`/`{time}`/`{count}`-Platzhalter) und `app_en.arb`: `openEntryBannerTitle`, `openEntryBannerMore`, `openEntryEnd`, `openEntryLater`, `openEntryEndDialogTitle`, `openEntryEndDialogBody`, `openEntryEndSuggestionExpected`, `openEntryEndSuggestionNow`, `openEntryEndInvalid`, `openEntryEndLongWarning`, `openEntrySaveError`, plus Dialog-Aktionen (`openEntryEndDialogConfirm`, Abbrechen falls kein vorhandener Key wiederverwendbar) und Semantik-Labels (`openEntryEndSemantics` mit `{date}`). `openEntryContinue` NICHT in PR 1.
- [ ] `flutter gen-l10n`; Test: l10n-Test, dass de/en dieselben Keys haben (falls vorhandener Paritätstest, sonst Widget-Tests in Schritt 6 decken ab).

### Schritt 6: Presentation
- [ ] Widget-Tests `open_entry_banner_test.dart` (Muster `holiday_banner_test.dart`, `MaterialApp` mit `AppLocalizations`-Delegates, `locale: Locale('de')` und `en`):
  - Text mit Datum + Startzeit (de/en, Datumsformat über `Localizations.localeOf`, Uhrzeit respektiert `use24HourFormat`)
  - „Noch 2 weitere offene Einträge" nur bei n > 0
  - Buttons „Beenden"/„Später" einzeln fokussierbar, Mindestgröße 48 dp, Semantics-Label enthält das Datum, `Semantics(container, liveRegion)` am Banner
  - schmale Breite (z. B. 320 px, Textskalierung 2.0): kein Overflow, Buttons umbrechen (`Wrap`)
  - Dark Mode: Theme `ThemeData.dark` pumpen, Farben aus `ColorScheme` (Rollenpaar `secondaryContainer`/`onSecondaryContainer`, unterscheidet sich von `tertiaryContainer` des Feiertag-Banners), kein hartcodiertes `Color`
  - nichts gerendert bei leerem State / „Später" gedrückt (Banner verschwindet)
  - Busy-Zustand deaktiviert Buttons
- [ ] Widget-Tests `open_entry_end_dialog_test.dart`: Vorschlag Soll-Ende vorbelegt; „Jetzt" nur bei <= 24 h sichtbar (feste Uhr); Datumsbereich [Starttag, heute]; Validierungsfehler `openEntryEndInvalid` (Text, nicht nur Farbe) bei Ende <= Start / > jetzt / vor letzter Pause, Bestätigen deaktiviert; Warnung bei > 16 h Netto (soft, bestätigbar); Rückgabewert = gewähltes `DateTime`; Fokus-Reihenfolge, Titel als Semantics-Header
- [ ] Screen-Test `dashboard_screen_open_entry_test.dart` (Muster `dashboard_screen_holiday_test.dart`): Banner steht neben/unter `HolidayBanner` in schmaler und breiter Variante; Beenden -> Dialog -> Bestätigen ruft ViewModel; Fehler zeigt `openEntrySaveError`-Snackbar und Banner bleibt; „Später" blendet aus; Dashboard bleibt bedienbar (Timer-Start-Button tappbar, nicht modal)
- [ ] Impl: `open_entry_banner.dart` (`ConsumerWidget`, `l10n` am Anfang von `build()`), `open_entry_end_dialog.dart` (Datum + Zeit per `showDatePicker`/`showTimePicker` oder ein Dialog mit beiden Feldern; Eingaben auf Minuten), Einbindung in `dashboard_screen.dart` an beiden `HolidayBanner`-Stellen.

### Schritt 7: Dokumentation + Gesamtvalidierung
- [ ] `mobile/CLAUDE.md`: neuer Abschnitt „Offene Einträge vor heute (#385)": Suche (aktueller + Vormonat, aktives Profil), Banner/Später-Semantik (nur Sitzung, Schlüssel Profil+Datum), `CloseOpenWorkEntry` (Saldo-Delta, `lastUpdated` bewusst nicht gesetzt wegen `_load`-Heuristik, Reihenfolge Saldo -> Eintrag, frisch lesen), Reload via `reloadAfterRetroClose()`, Grenzen (älter als Vormonat, andere Profile, kein `resumed`-Re-Check, Fortsetzen = PR 1b, Reports #404); in #388 Grenze (2) um Verweis ergänzen. `web/CLAUDE.md` bleibt für den Web-PR.
- [ ] Mutations-Tabelle abgearbeitet (jede Mutation: Test rot, danach zurückgenommen, Ergebnis im Review-Protokoll).
- [ ] Zeitzonenläufe der neuen Tests: `TZ=Europe/Berlin`, `UTC`, `America/Los_Angeles`, `Pacific/Auckland`.

## Risiken und Umgang
| Risiko | Umgang im Plan |
|---|---|
| Mehrere offene Einträge | Neuester zuerst, „+ n weitere", nach jedem Beenden Re-Check (VM-Test). „Später" ist sitzungsweit je Profil (Frage 2) |
| Sehr alter Eintrag (Wochen) | „Jetzt" nur <= 24 h, Soll-Ende/Picker, 16-h-Soft-Warnung; Eintrag älter als Vormonat wird nicht gefunden (dokumentiert) |
| Profilwechsel | Suche am aktiven Repo; Dismissed mit Profil-Schlüssel; Aktion hält Use Case + Settings am Beginn fest; Gen-Prüfung gegen späte Ergebnisse; Tests mit `holdReads`/`holdSaves` |
| Race Beenden (Doppeltipp, anderes Gerät, Autosave des Dashboards) | `busy`-Flag, frisch lesen + `alreadyClosed`, laufender Dashboard-Eintrag ist nie Kandidat; Last-Write-Wins des Autosaves auf anderem Gerät bleibt bekannt |
| Reload während heutiger Timer läuft | Reload liest den zuletzt gespeicherten heutigen Eintrag (Autosave bis 30 s alt). Test „heute laufender Timer" sichert Zustand und Saldo; verbleibendes Risiko: nicht gespeicherte Sekunden-Änderung zwischen Autosaves (Frage 3) |
| `lastUpdated`-Heuristik in `_load` | Beenden setzt `lastUpdated` nie (Test + Mutationsprobe) |
| Teilfehler Saldo/Entry | Saldo zuerst; Rest-Risiko wie #402 dokumentiert |
| Offline | `failed`, Banner bleibt, Snackbar, wiederholbar |
| Dashboard-VM Race-Sensibilität | Nur eine neue öffentliche Methode, bestehende Day-Change-/Profil-Tests als Regression |
| Lesekosten | 2 Monats-Reads je Start/Profil-/Auth-/Tageswechsel plus Re-Check nach Aktion; Ausschluss des laufenden Eintrags im Speicher ohne Zusatz-Read |

## Validierung
- `dart format --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`
- `dart run custom_lint`
- `flutter test` (CI-TZ Europe/Berlin) + Wiederholung der neuen Tests mit UTC/LA/Auckland
- `dart run build_runner build --delete-conflicting-outputs` und `flutter gen-l10n` ohne Diff danach

## Offene Fragen an die Hauptsession
1. Soll-Ende bei Soll = 0 (Wochenende) oder wenn das Soll-Ende nach „jetzt" liegt und der Eintrag > 24 h alt ist: Vorschlag dann leer lassen (Picker ohne Vorbelegung, Bestätigen gesperrt) oder Start + 8 h? Plan-Default: keine Vorbelegung.
2. „Später" bei mehreren offenen Einträgen: blendet den gesamten Banner für die Sitzung aus (Plan-Default) oder nur den aktuellen, sodass der nächste sofort erscheint? Plan-Default entspricht „Später = nicht jetzt".
3. Reload nach Beenden bei laufendem heutigen Timer: Plan nutzt `_init(dayChange: true)` laut Entscheidung 8. Falls Reload während laufender Dashboard-Aktion (Start/Stop in Flug) unerwünscht ist, soll `reloadAfterRetroClose()` dann verzögert werden? Plan-Default: nicht verzögern, Gen-Logik von `_init` verwirft Überholtes.
4. Nach dem Beenden Hinweis-Snackbar „Eintrag beendet" nötig? Würde einen weiteren ARB-Key (`openEntryClosedInfo`) brauchen; Plan-Default: nein, der Banner verschwindet als Rückmeldung.

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Plan-Default: Ist das Soll-Ende nicht sinnvoll (Soll = 0 oder Soll-Ende liegt nach „jetzt" und der Eintrag ist älter als 24 h), bleibt die Zeit im Dialog leer, der Nutzer muss sie wählen (Bestätigen erst mit gültiger Eingabe; Ende muss nach dem Start liegen). Kein Start + 8 h.
2. „Später" blendet den ganzen Banner für die Sitzung aus (Plan-Default), Schlüssel wie geplant je Profil|Datum.
3. `reloadAfterRetroClose()` nicht verzögern (Plan-Default); Aktionen laufen ohnehin über `_ensureCurrentDay`/Aktionskontext.
4. Keine Snackbar nach dem Beenden (Plan-Default); das Verschwinden des Banners ist die Rückmeldung. Kein zusätzlicher ARB-Key.
