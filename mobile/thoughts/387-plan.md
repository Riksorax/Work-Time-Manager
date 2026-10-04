# Mobile-Plan: #387 — Reports, Insights, Reflexion, Urlaub: Tageswechsel über `todayProvider`
Research: mobile/thoughts/387-research.md
Umsetzung als **zwei PRs nacheinander**: Teil A (Reports + Reflexion-Regressionstests, `Refs #387`), danach Teil B (Urlaub, Insights, Jahres-Tab, `Closes #387`). Teil B startet erst nach Merge von A (Konflikt-Hunks in `reports_page.dart` sind getrennt, Rebase unkritisch).

## Ziel
Reports-Auswahl, Urlaubsbilanz, Insights-Fenster und Jahres-Tab beziehen "heute" aus `todayProvider` statt `DateTime.now()`. Die Reports-Auswahl folgt dem Tageswechsel nur, wenn sie auf dem bisherigen heute stand (Pendant Web #383); manuell gewählte Tage bleiben.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein. `LeaveBalance.year` existiert bereits (`domain/utils/leave_balance_utils.dart:11`) | Damit ist Entscheidung 8 (Bilanz sofort leeren) umsetzbar |
| Repository-Interface ändern? | Nein | Keine Hybrid-/Firebase-/Local-/ApiDataSource-Änderung |
| Neuer Provider? | Nein. `leaveBalanceNowProvider` wird **entfernt** (Entscheidung 1). Alle VMs sind handgeschriebene `NotifierProvider` | Kein `@riverpod`, kein `build_runner` nötig. Nur falls ein `@GenerateMocks` neu hinzukäme (nicht geplant) |
| "heute" in Notifier-`build()` | `ref.listen(todayProvider, ...)`, **nie** `ref.watch` | `watch` baut den Notifier neu: State, gewählter Tag und `_monthlyEntries` gehen verloren (Muster `DashboardViewModel:52`) |
| Folgeregel Reports | Auswahl folgt nur, wenn `selectedDay` (Tagesvergleich) == bisheriges heute; `selectedMonth` folgt nur, wenn er auf dem Monat des bisherigen heute stand und `selectedDay` mitgezogen wurde (siehe Schritt A2); Multi-Select unangetastet (Entscheidung 7) | Web-Regel, Entscheidung 7 |
| `loadCurrentMonthData()` | Nur `DateTime.now()` -> `ref.read(todayProvider)`, Verhalten unverändert (Entscheidung 4); Inkonsistenz Monat/Auswahl nur als Nebenbefund im PR-Text | Kleinster Umfang |
| Kalender "heute"-Markierung | Nicht umsetzen (Entscheidung 3) | Neue UI, nicht Teil des Issues |
| Insights / Jahres-Tab | Nur `now`/`year` beim Laden aus `todayProvider`, kein Listener, kein Auto-Reload (Entscheidung 5) | Verhindert Reads für Nicht-Premium; "Auswahl bleibt" |
| Wochen-Reflexion | Keine Code-Änderung, nur Regressionstests; Schlüssel weiter über `isoWeekYear/isoWeekNumber(startOfWeek)` | Dialog ist modal und an `startOfWeek` gebunden; nie `date.year` verwenden |
| Urlaub Jahreswechsel | `ref.listen(todayProvider)` im `LeaveBalanceViewModel`; bei `next.year != previous.year`: `_last` verwerfen (Ladezustand ohne Balance), dann Reload | Entscheidung 8; Vorjahres-Resturlaub wäre falsch |
| Premium-Gate? | Unverändert (`isPremiumProvider`/`PremiumBlurGate`) | Kein neuer Ladeauslöser für Nicht-Premium |
| Pro Arbeitszeit-Profil? | Unverändert, `profileId` wird nicht berührt | Profilwechsel läuft über `workRepositoryProvider` |
| Backend-Änderung? | Nein | |
| Neue Texte? | Nein, keine ARB-Änderung | |
| Doku | `mobile/CLAUDE.md`, Abschnitt "Tageswechsel (#379)": Regel `ref.listen` statt `ref.watch` in Notifier-`build()` und "Auswahl folgt nur, wenn sie auf bisherigem heute stand"; `leaveBalanceNowProvider` entfällt. In PR B | Kein weiterer Doku-Eintrag |

## Test-Rahmen (gilt für alle Schritte)
- Vorbild: `test/core/providers/holiday_today_provider_test.dart` (`fakeAsync`, `FakeClock` aus `test/support/fake_clock.dart` per `bind(async)`/`jumpTo`, `clockProvider.overrideWithValue(clock.call)`, Container **innerhalb** `fakeAsync`, am Ende `dispose` + `async.pendingTimers` leer). `setUpAll(TestWidgetsFlutterBinding.ensureInitialized)` in jeder Datei, die `todayProvider` indirekt auslöst (Reports-, Leave-, Insights-, Yearly-VM-Tests).
- Feste Daten, nur lokale Konstruktoren `DateTime(y,m,d,h,m,s)`, kein `DateTime.now()`, keine Wochentags-Annahmen außer den festgelegten:
  - Tageswechsel: Fr 2026-10-02 23:59:30 -> Sa 2026-10-03 00:00:00
  - Monatswechsel: 2026-10-31 23:59:30 -> 2026-11-01
  - Jahres-/ISO-Wechsel: Do 2026-12-31 (2026-W53) 23:59:30 -> Fr 2027-01-01 (noch 2026-W53) -> Mo 2027-01-04 (2027-W01)
  - Wochenwechsel: So 2026-10-04 23:59:30 -> Mo 2026-10-05
- Rot-Nachweis je Schritt: Test zuerst schreiben, **gezielt ausführen und das Scheitern festhalten** (Testname + Fehlermeldung kurz im PR-Text/Implementierungsnotiz), erst dann implementieren, dann grün. Reine Regressionstests (A4, ggf. A5-Teile), die schon grün sind, als "Regression, bewusst grün" kennzeichnen.
- Lokal je Teil: `flutter test <Datei>` normal und mit `TZ=Europe/Berlin` (CI, `ci.yml:52`); zusätzlich einmal `TZ=UTC` und `TZ=America/Los_Angeles` (nicht CI). Kein Test auf den DST-Tag 2026-10-25 nötig.

---
# TEIL A — Reports + Reflexion-Regressionstests (PR A, `Refs #387`)

## Dateien (Teil A)
| Datei | neu/geändert | Zweck |
|---|---|---|
| `lib/presentation/view_models/reports_view_model.dart` | geändert | `ref.listen(todayProvider)`, `_onDayChange`, `init()`/Fallbacks/`loadCurrentMonthData()` auf `todayProvider` |
| `lib/presentation/state/reports_state.dart` | geändert | `ReportsState.initial(today)` ohne `DateTime.now()`, normalisiert |
| `lib/presentation/screens/reports_page.dart` | geändert | Fallbacks `?? DateTime.now()` (Zeilen ca. 209, 217, 283, 289, 698, 1132) auf `ref.read(todayProvider)`; **nicht** 1381 und 2833 (Teil B) |
| `test/presentation/view_models/reports_view_model_test.dart` | geändert | Neue Gruppe "Tageswechsel (#387)", Bestandstests auf feste Uhr |
| `test/presentation/view_models/weekly_reflection_view_model_test.dart` | geändert | Schlüssel-Regressionstests |
| `test/presentation/screens/reports_page_test.dart` | geändert | `DateTime.now()` (5 Stellen) prüfen/ersetzen |
| `test/presentation/screens/reports_page_widget_test.dart` | geändert (optional) | Widget-Test Tageswechsel/offener Reflexions-Dialog |

## Schritte (TDD)

### Schritt A0: Bestandsaufnahme Tests (vor allem anderen)
- [ ] `DateTime.now()` in `reports_view_model_test.dart` (17 Treffer) und `reports_page_test.dart` (5) einzeln prüfen: datums-/TZ-abhängige Erwartungen (Wochen-/Monatsgrenzen, `selectedDay`-Vergleiche) identifizieren. Ergebnis als Liste in den Implementierungsnotizen.
- [ ] `reports_page_widget_test.dart` und `reports_page_subscription_test.dart`: prüfen, ob `todayProvider`-Aufbau ohne Binding bricht (Binding-Setup ergänzen).
- [ ] Hilfsfunktion im Test: Container mit `clockProvider`-Override + Fake-Repos (`test/support/fake_repositories.dart`, sonst bestehende Mocks) bauen.

### Schritt A1: `ReportsState.initial(today)` und `init()`
- [ ] Test (rot): `init()` unter Fake-Uhr 2026-10-02 23:59:30 -> `selectedDay == DateTime(2026,10,2)` (ohne Uhrzeit, `hour==0`), `selectedMonth` entspricht Oktober 2026, `focusedDay` ebenso. (Ersetzt die Uhrzeit-behaftete Variante, R1.)
- [ ] Impl: `ReportsState.initial` bekommt `DateTime today` und normalisiert zu `DateTime(y,m,d)`; `build()` ruft `initial(ref.read(todayProvider))`; `init()` nutzt `ref.read(todayProvider)`.
- [ ] Bestandstests aus A0, die `DateTime.now()` erwarten, auf Fake-Uhr umstellen.

### Schritt A2: `_onDayChange` (Kern)
Tests zuerst (alle rot), in `fakeAsync` mit Fake-Uhr, Verify über Repository-Aufrufe:
- [ ] T1 Tageswechsel innerhalb Monat: Auswahl auf heute (2026-10-02) -> nach `elapse` auf 00:00 ist `selectedDay == 2026-10-03`, `selectedMonth` Oktober, Berichte neu berechnet; **kein** zusätzlicher Monats-Reload (Aufrufzähler `getWorkEntriesForMonth(2026,10)` unverändert).
- [ ] T2 Manuell gewählter Tag bleibt: `selectDate(2026-10-01)`, dann Wechsel -> `selectedDay` bleibt 2026-10-01.
- [ ] T3 Monatswechsel, Auswahl auf heute: 10-31 -> 11-01: `selectedDay == 2026-11-01`, `selectedMonth` November, `getWorkEntriesForMonth(2026,11)` genau einmal zusätzlich (`verify`).
- [ ] T4 Monatswechsel, Auswahl manuell (z. B. 2026-10-15): Auswahl und `selectedMonth` unverändert, **kein** Reload (`verifyNever(... (2026,11))`).
- [ ] T5 `selectedMonth` steht auf heutigem Monat, Auswahl manuell im selben Monat, Monat wechselt: nichts ändern (Auswahl != heute, Entscheidung laut Regel). Fester Erwartungswert, damit das Verhalten dokumentiert ist.
- [ ] T6 Wochenwechsel So 2026-10-04 -> Mo 2026-10-05: Auswahl folgt, Wochenbericht rechnet auf die Woche ab 2026-10-05 (Wochenstart-Wert prüfen).
- [ ] T7 Jahreswechsel: Auswahl auf 2026-12-31 -> 2027-01-01 folgt, `selectedMonth` Januar 2027, `getWorkEntriesForMonth(2027,1)` aufgerufen; Wochenstart bleibt Mo 2026-12-28 (Silvesterwoche durchgehend 2026-W53 über `isoWeekYear(startOfWeek)`); danach Mo 2027-01-04: Wochenstart 2027-01-04, `isoWeekYear/Number` = 2027/1.
- [ ] T8 Resume-Pfad: `clock.jumpTo(2026-10-03 00:00:05)` + `todayProvider.notifier.refresh()` -> Auswahl folgt wie T1.
- [ ] T9 Multi-Select aktiv (`multiSelectMode`, `selectedDates` gesetzt), Auswahl != heute: `selectedDates`/Modus bleiben nach Wechsel unverändert (Entscheidung 7). Zusatzfall: Auswahl == heute und Multi-Select aktiv -> `selectedDay` folgt, `selectedDates` bleiben unangetastet.
- [ ] T10 Kein Rebuild/Zustandsverlust: Zähler/`listen` auf den Provider; nach Tageswechsel wurde `build()` nicht erneut ausgeführt (z. B. `_monthlyEntries`/manueller Tag erhalten; `init`-Aufrufzahl unverändert).
- [ ] T11 Dispose: `container.dispose()` -> `async.pendingTimers` leer.
- Rot-Nachweis: T1-T3, T6-T8, T10 müssen rot sein (Auswahl bewegt sich heute nie); T2/T4/T5/T9 sind Schutztests, die nach naiver Umsetzung (immer folgen) rot würden, vor der Impl. als "grün, Schutz" vermerken.
- [ ] Impl in `ReportsViewModel`:
  - In `build()`: `ref.listen<DateTime>(todayProvider, _onDayChange)` zusätzlich zu den bestehenden `ref.watch`-Aufrufen.
  - `_onDayChange(previous, next)`: Tagesvergleich per `DateUtils.isSameDay`/normalisierte Werte (nicht per Uhrzeit). Wenn `selectedDay == previous`: `selectedDay`/`focusedDay` = `next`; bei Monatswechsel `selectedMonth` auf `DateTime(next.year,next.month)` und `_loadWorkEntriesForMonth` (unter Beachtung der Guard-Regel unten), sonst `_updateCalculatedReports()`. Sonst: nichts. Multi-Select-Felder nie schreiben.
  - Guard: `ref.mounted`-Prüfung nach `await` im Reload-Pfad, damit nach Dispose nicht in den State geschrieben wird. Kein Generationszähler (bestehendes Race bleibt, im PR-Text als bekannt notiert). Während `isLoading` kein zusätzlicher Sonderfall.
  - `_updateCalculatedReports`, `saveWorkEntry`, `deleteWorkEntry`, Batch-Pfade: Fallback `?? DateTime.now()` -> `?? ref.read(todayProvider)`.
  - `loadCurrentMonthData()`: `now` -> `ref.read(todayProvider)`, sonst unverändert (Entscheidung 4). Test (grün nach Impl.): Fake-Uhr 2026-11-01, Auswahl alt (2026-10-15): `selectedMonth` wird November, `selectedDay` bleibt (dokumentiert die bekannte Inkonsistenz als Charakterisierungstest).
- [ ] `reports_page.dart`: Fallbacks auf `ref.read(todayProvider)`; kein `ref.watch(todayProvider)` in der Page (Fallbacks tot). Kein Test nötig, abgedeckt durch bestehende Page-Tests (grün halten).

### Schritt A3: Page-/Widget-Tests (nur wenn Kalender steuerbar)
- [ ] `reports_page_widget_test.dart` (MaterialApp mit `AppLocalizations`-Delegates, `locale: Locale('de')`, `clockProvider`-Override, `tester.pump(Duration)` über Mitternacht): Wochen-Titel/KW wechselt am Montag 2026-10-05 bei Auswahl auf heute; Auswahl manuell: bleibt. Falls Steuerung im Widget-Test unverhältnismäßig aufwendig: weglassen, VM-Tests reichen (im PR-Text vermerken).
- [ ] Widget-Test Reflexions-Dialog (nur wenn mit vertretbarem Aufwand): Dialog offen (`startOfWeek` 2026-12-28), Tageswechsel/Wochenwechsel der Reports-Auswahl dahinter -> eingegebener Text und Wochenanzeige im Dialog unverändert (Verhalten festschreiben; Dialog darf nie `selectedDay`/`todayProvider` watchen).

### Schritt A4: Reflexion-Regressionstests (keine Logikänderung, bewusst grün)
- [ ] `weekly_reflection_view_model_test.dart`: `loadReflection(DateTime(2027,1,4))` -> Jahr 2027 / KW 1 (Repository-Aufruf mit Schlüsselteilen verifizieren); `loadReflection(DateTime(2026,12,28))` -> 2026 / 53; `loadReflection(DateTime(2024,12,30))` -> 2025 / 1.
- [ ] Test im Reports-Kontext (T7) deckt Folgekette Auswahl -> Wochenstart -> ISO-Schlüssel ab.

### Schritt A5: Abschluss Teil A
- [ ] `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test` und `TZ=Europe/Berlin flutter test`.
- [ ] Prüfen: kein `build_runner` nötig (`git status` zeigt keine `.g.dart`-Änderung).
- [ ] PR-Text: `Refs #387`; Nebenbefunde: `loadCurrentMonthData()` setzt nur `selectedMonth` (Inkonsistenz bleibt, Entscheidung 4); `edit_break_modal.dart:76` hat eigenes Issue; bekanntes Race `_loadWorkEntriesForMonth`/`_loadReportsFromApi` ohne Generationszähler.

---
# TEIL B — Urlaub, Insights, Jahres-Tab (PR B, `Closes #387`)
Voraussetzung: PR A gemergt, Branch von `develop` aktualisiert.

## Dateien (Teil B)
| Datei | neu/geändert | Zweck |
|---|---|---|
| `lib/presentation/view_models/leave_balance_view_model.dart` | geändert | `leaveBalanceNowProvider` entfernen; Jahr aus `todayProvider`; `ref.listen` auf Jahreswechsel |
| `lib/presentation/screens/reports_page.dart` | geändert | `YearlyLeaveRows` (ca. 2833) auf `todayProvider.select(year)`; `_loadIfNeeded` (ca. 1381) Jahr aus `todayProvider` |
| `lib/presentation/state/yearly_report_state.dart` | geändert | `initial()` ohne `DateTime.now().year` (Jahr als Parameter) |
| `lib/presentation/view_models/yearly_report_view_model.dart` | ggf. geändert | `build()` übergibt `ref.read(todayProvider).year` an `initial` |
| `lib/presentation/view_models/insights_view_model.dart` | geändert | `now` aus `ref.read(todayProvider)` |
| `lib/presentation/screens/settings_page.dart`, `dashboard_screen.dart` | prüfen | Nutzer von `leaveBalanceNowProvider`/Balance; vermutlich keine Änderung |
| `test/presentation/view_models/leave_balance_view_model_test.dart` | geändert | Override auf `clockProvider`, Jahreswechsel-Tests |
| `test/presentation/screens/yearly_leave_rows_test.dart` | geändert | Override auf `clockProvider`, Jahreswechsel im Widget |
| `test/presentation/screens/dashboard_screen_leave_test.dart` | geändert | Override umstellen |
| `test/presentation/view_models/insights_view_model_test.dart` | neu (falls nicht vorhanden; Bestand sichten) | Fensterberechnung |
| `test/presentation/view_models/yearly_report_view_model_test.dart` | geändert | Startjahr aus Fake-Uhr |
| `mobile/CLAUDE.md` | geändert | Abschnitt "Tageswechsel (#379)" ergänzen |

## Schritte (TDD)

### Schritt B0: Bestandsaufnahme
- [ ] `grep leaveBalanceNowProvider` über `lib` und `test` (erwartet: `leave_balance_view_model.dart`, `reports_page.dart` `YearlyLeaveRows`, plus Tests `leave_balance_view_model_test`, `yearly_leave_rows_test`, evtl. `dashboard_screen_leave_test`, `leave_balance_card_test`). `DateTime.now()` in den Teil-B-Tests prüfen. Insights-Test-Bestand klären (kein `insights_view_model_test.dart` in der Glob-Liste, nur `insights_utils_test.dart`).
- [ ] `leave_balance_view_model.dart` lesen: `_last`, `reload()`, `_load()`-Jahr, Zusammenspiel mit `ref.invalidate`.

### Schritt B1: Urlaub — `LeaveBalanceViewModel`
Tests zuerst (rot), `fakeAsync` + Fake-Uhr, `TestWidgetsFlutterBinding`:
- [ ] U1 Jahr aus Uhr: Fake-Uhr 2026-12-31 23:59:30 -> Laden ruft `getWorkEntriesForMonth(2026, 1..12)`; Balance-Jahr 2026.
- [ ] U2 Jahreswechsel: Elapse auf 2027-01-01 00:00 -> `getWorkEntriesForMonth(2027, 1..12)` aufgerufen; Zwischenzustand: `balance == null`/`isLoading: true` (Vorjahreswerte werden nicht weitergezeigt, Entscheidung 8; `LeaveBalance.year` ist verfügbar, also direkte Umsetzung ohne Ausnahmebegründung); nach Abschluss `balance.year == 2027`.
- [ ] U3 Tageswechsel innerhalb des Jahres (2026-10-02 -> 10-03): **kein** Reload (Aufrufzähler unverändert).
- [ ] U4 Resume-Pfad: `jumpTo(2027-01-01 00:00:05)` + `refresh()` -> Reload wie U2.
- [ ] U5 Dispose: keine pending Timer; `ref.mounted`-Guard: Dispose während des Reloads schreibt keinen State.
- [ ] Bestehende Tests: Override `leaveBalanceNowProvider` -> `clockProvider.overrideWithValue(clock.call)` mit fester Uhr.
- Impl: `leaveBalanceNowProvider` löschen; Jahr über `ref.read(todayProvider).year`; in `build()` `ref.listen(todayProvider, (p, n) { if (p.year != n.year) { _last = null; reload(); } })`. **Kein** `ref.watch(todayProvider)` in `build()` (12 Abfragen pro Tag, Zustandsverlust).

### Schritt B2: Urlaub — `YearlyLeaveRows` und Dashboard
- [ ] Test (rot): `yearly_leave_rows_test.dart`: Fake-Uhr 2026-12-31 23:59:30, Widget zeigt für `year == 2026` die Resturlaubszeilen; nach Pump über Mitternacht (2027-01-01) für `year == 2026` den Vorjahr-Hinweis. Widget-Setup mit `AppLocalizations`-Delegates, `locale: Locale('de')`.
- [ ] Test: `dashboard_screen_leave_test.dart` und ggf. `leave_balance_card_test.dart` auf `clockProvider` umgestellt, bleiben grün; zusätzlich Dashboard-Karte nach Jahreswechsel zeigt keinen Vorjahres-Resturlaub (nur falls im bestehenden Testaufbau leicht möglich).
- [ ] Impl: `YearlyLeaveRows` nutzt `ref.watch(todayProvider.select((d) => d.year))` statt `leaveBalanceNowProvider`. Es bleibt keine Referenz auf `leaveBalanceNowProvider` (grep leer).

### Schritt B3: Insights
- [ ] Test (rot): Fake-Uhr 2026-11-01 -> `loadInsights()` ruft `getWorkEntriesForMonth` für (2026,11), (2026,10), (2026,9) auf; Fake-Uhr 2027-01-01 -> (2027,1), (2026,12), (2026,11). Uhr wird per `clockProvider` injiziert (keine Annahme über heutiges Datum).
- [ ] Test (Schutz, Entscheidung 5): kein Repository-Zugriff beim bloßen Lesen des Providers und beim Tageswechsel (`verifyNever`), kein Auto-Reload nach Monatswechsel.
- [ ] Impl: `now = ref.read(todayProvider)`; **kein** Listener. `insights_utils.dart` unverändert.

### Schritt B4: Jahres-Tab
- [ ] Test (rot): `yearly_report_view_model_test.dart`: Startjahr des States kommt aus Fake-Uhr (2026-12-31 -> 2026; 2027-01-01 -> 2027); `loadYear` bekommt das Jahr aus `todayProvider` (Aufruf mit `2027`, wenn Uhr 2027-01-04).
- [ ] Test (Schutz, Entscheidung 5): vom Nutzer gewähltes Jahr (`year - 1`) bleibt nach Jahreswechsel bestehen, kein Auto-Reload.
- [ ] Impl: `YearlyReportState.initial(year)` ohne `DateTime.now()`; `_loadIfNeeded` nutzt `ref.read(todayProvider).year`. `reports_page_subscription_test.dart` grün halten (Nicht-Premium löst nichts aus).

### Schritt B5: Doku und Abschluss
- [ ] `mobile/CLAUDE.md`, "Tageswechsel (#379)": Absatz zu Reports/Urlaub/Insights ergänzen (`ref.listen` statt `ref.watch` in Notifier-`build()`; Reports-Auswahl folgt nur, wenn sie auf dem bisherigen heute stand; Urlaub reloadet nur beim Jahreswechsel; `leaveBalanceNowProvider` entfällt; Insights/Jahres-Tab ohne Auto-Reload).
- [ ] Gesamt-Checks wie Teil A (`dart format ...`, `analyze`, `custom_lint`, `flutter test`, `TZ=Europe/Berlin flutter test`, zusätzlich lokal `TZ=UTC`/`America/Los_Angeles`). `build_runner` nur, falls wider Erwarten Annotationen geändert wurden.
- [ ] Abschlusskontrolle: `grep -rn "DateTime.now()"` in den berührten Dateien: nur noch erlaubte Fälle (Zeitstempel/Dauer: `weekly_reflection_view_model:70`, `settings_view_model:235`, `nowToMinute()` u. ä., sowie `edit_break_modal:76` bewusst unberührt).

## Validierung (beide PRs)
- `dart format --set-exit-if-changed lib test`, `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test`, zusätzlich `TZ=Europe/Berlin flutter test`.
- Keine ARB-, Backend-, Web-, Firestore-Rules-Änderung.

## Risiken (Kurz)
- `ref.watch(todayProvider)` in Notifier-`build()` wäre ein Rückschritt (Zustandsverlust) -> Test T10.
- Reflexion-Schlüssel nie aus `date.year` ableiten; Dialog nicht an `selectedDay`/`todayProvider` koppeln.
- Insights/Jahres-Tab/Leave-Listener dürfen für Nicht-Premium/ausgeloggte Nutzer keine Reads auslösen (Leave nur Jahreswechsel; Insights/Jahr kein Listener).
- Binding-Assertion in Unit-Tests ohne `TestWidgetsFlutterBinding.ensureInitialized()`.

## Offene Fragen (an die Hauptsession)
1. T5/Regel für `selectedMonth`: Soll `selectedMonth` bei manueller Auswahl und Monatswechsel des heute **unverändert** bleiben (Plan-Annahme, folgt der Regel "nur wenn Auswahl auf heute stand") oder soll ein auf dem alten heutigen Monat stehender `selectedMonth` allein mitziehen (Research Abschnitt 2, 2. Spiegelstrich)? Plan nimmt: nicht mitziehen. Bitte bestätigen.
2. Reflexions-Dialog-Widget-Test (A3) und Reports-Page-Widget-Test: nur "wenn vertretbar aufwendig" einplanen oder verpflichtend? Plan: optional, VM-Tests verpflichtend.
3. Insights-ViewModel hat keinen vorhandenen Test (`insights_view_model_test.dart` nicht gefunden): neue Testdatei in B3 anlegen (Plan-Annahme) — ok?

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. `selectedMonth` bleibt bei manueller Auswahl und Monatswechsel unverändert (Plan-Annahme); er folgt nur, wenn er der bisherige „heute"-Monat war.
2. Widget-Tests (Reports-Page, Reflexions-Dialog) sind optional; nur ergänzen, wenn sie ohne großen Aufwand stabil laufen. VM-/Provider-Tests sind verpflichtend.
3. Neue Testdatei `insights_view_model_test.dart` ist erlaubt.
