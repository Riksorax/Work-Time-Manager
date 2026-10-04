# Mobile-Research: #387 — Reports, Insights, Wochen-Reflexion und Urlaub nutzen weiter ein eigenes „heute" (kein Tageswechsel)
Datum: 2026-10-04
Typ: Bug-Analyse (reine Code-Analyse, nicht auf Gerät reproduziert)
Referenzen: #379/PR #384 (Mobile-Dashboard, `todayProvider`), Web #382/PR #383 (gemergt: Kalender + Reports-Vorauswahl folgen `TodayService.today`, manuell gewählter Tag bleibt). `web/thoughts/382-*` existiert nicht (nur `372-*`, `390-research.md`), PR #383 hat 4 Dateien, +101/−3.

## Aufgabe

Seit #379 gibt es `todayProvider` (`lib/core/providers/today_provider.dart`: lokaler Tag als `DateTime(y,m,d)`, Mitternachts-Timer, Resume-Observer, `refresh()`, Uhr aus `clockProvider`). Genutzt von `DashboardViewModel` (`ref.listen`) und `holidayTodayProvider`. Andere Stellen bestimmen „heute" selbst und wechseln bei offener App nicht.

Akzeptanzkriterien (Issue):
1. Stellen auflisten, soweit sinnvoll auf `todayProvider` umstellen.
2. Reports-Vorauswahl nicht ungefragt verschieben, wenn der Nutzer einen anderen Tag gewählt hat.
3. Tests mit Fake-Uhr, festen Daten, auch unter `TZ=Europe/Berlin`.

Nicht Teil: Dashboard (fertig), Splitten/Timer, Profilwechsel-Verhalten, neue Texte (keine ARB-Änderung), Backend, Firestore-Pfade/Rules, Premium-Logik.

## 1. Bestandsaufnahme „heute" in `mobile/lib` (grep `DateTime.now`, `.now`, `year`-Bezug)

Wirkt der fehlende Tageswechsel real? Wichtig vorab: `HomeScreen` baut nur den aktiven Tab (`_widgetOptions.elementAt`, kein IndexedStack). `ReportsPage` wird bei jedem Tabwechsel neu aufgebaut (`initState` → `loadCurrentMonthData()`), die ViewModels sind **nicht** autoDispose (State überlebt). Reale Wirkung entsteht also nur, wenn der Nutzer die Seite **über Mitternacht offen lässt** bzw. App-Resume/Tabwechsel ohne Neuaufbau des Providers.

| # | Stelle | Verhalten heute | Real sichtbar? |
|---|---|---|---|
| R1 | `ReportsState.initial()` (`reports_state.dart:39`): `focusedDay/selectedDay/selectedMonth = DateTime.now()` (mit Uhrzeit, nicht normalisiert) | einmalig bei `build()` des ReportsViewModel (Provider lebt bis Logout/Repo-Wechsel, da `ref.watch(workRepository/settingsRepository)`) | ja, aber nur als Zwischenzustand: `init()` überschreibt sofort |
| R2 | `ReportsViewModel.init()` (`:38`): `now = DateTime.now()` → `selectedDay: now`, `selectedMonth` | einmal beim Aufbau per `Future.microtask` | **ja**: App mit Berichte-Tab über Nacht im Hintergrund (ViewModel bleibt am Leben) zeigt weiter gestern als Auswahl. Wochen-/Tagesbericht und Monat bleiben „gestern" |
| R3 | `ReportsViewModel.loadCurrentMonthData()` (`:215`): `now`, setzt nur `selectedMonth`, **lässt `selectedDay`** | bei jedem Öffnen der ReportsPage (postFrame) | **ja, Inkonsistenz**: nach Mitternacht + Tabwechsel springt `selectedMonth` auf neuen Monat, `selectedDay` bleibt alter Tag/Monat. Bei Monatswechsel (30.→1.) zeigt Kalender (basiert auf `selectedDay`, `reports_page.dart:2116`) den alten Monat, Monatsbericht den neuen. Existiert bereits heute (auch ohne Mitternacht, wenn Nutzer im Monat zurückgeblättert hat: Tabwechsel setzt selectedMonth zurück, selectedDay nicht). Eigenes Verhalten, bewusst klären (Frage 4) |
| R4 | `ReportsViewModel._updateCalculatedReports/saveWorkEntry/deleteWorkEntry/saveBatch…` (`:50, :157, :174, :550`): `state.selectedDay ?? DateTime.now()` | reiner Fallback, `selectedDay` ist praktisch nie null (nur `copyWith(null)` ignoriert Null → nie null nach `initial()`) | nein (toter Fallback), aber mit `todayProvider` angleichen |
| R5 | `reports_page.dart` `:209, :217, :283, :289, :698, :1132`: `selectedDay/selectedMonth ?? DateTime.now()` | wie R4, Fallback | nein (tot) |
| R6 | Kalender-Grid `_Calendar` (`:1829ff`) | **kennt keine „heute"-Markierung** (nur `isSelected`/`isMultiSelected` via `DateUtils.isSameDay`). Das im Issue genannte „heute"-Markieren im Kalender existiert in Mobile gar nicht (anders als Web #382 `isToday`) | nein. Keine UI-Änderung nötig, sofern nicht als Feature gewünscht (Frage 3) |
| R7 | `reports_page.dart:1381` `_loadIfNeeded()` Jahresbericht: `loadYear(DateTime.now().year)` einmalig (`_loadTriggered`) + `YearlyReportState.initial()` (`yearly_report_state.dart:23`: `DateTime.now().year`) | Jahr beim ersten Sichtbarwerden; danach navigiert der Nutzer selbst (`year ± 1`) | gering: nur bei Berichte-Tab > Jahres-Tab offen über Silvester; Nutzer sieht „altes" Jahr, kann selbst weiterblättern. Wird die ReportsPage neu aufgebaut (Tabwechsel), setzt `_loadTriggered` neu zurück, der State `year` wird aber nur durch `loadYear` überschrieben → neu geladen mit aktuellem Jahr (also nach Tabwechsel schon korrekt) |
| I1 | `InsightsViewModel.loadInsights()` (`insights_view_model.dart:40`): `now = DateTime.now()` → letzte 3 Kalendermonate | Laden einmalig pro Sichtbarwerden des Tabs (`_loadTriggered`, `reports_page.dart:1625`) | gering-mittel: Zeitraum ist „letzte 3 Monate"; Fenster verschiebt sich nur bei Monatswechsel. `insights_utils.dart` selbst enthält **kein** „heute"/`now` (reine Funktionen auf Einträgen) → dort keine Änderung; das Issue-Stichwort trifft nur das ViewModel. Burnout-Streak (`detectOvertimeStreak`) bekommt nur die Einträge, kein Referenzdatum |
| W1 | Wochen-Reflexion: **kein eigenes „aktuelle KW"**. Dialog bekommt `startOfWeek` der in Reports **gewählten** Woche (`reports_page.dart:698-758`, `weekly_reflection_dialog.dart:36` → `loadReflection(startOfWeek)`, Schlüssel aus `isoWeekYear/isoWeekNumber(startOfWeek)`) | folgt dem `selectedDay` der Reports, nicht „jetzt" | **indirekt**: erbt Fehler R2 (Auswahl bleibt gestern → Woche bleibt bis Sonntag-Nacht dieselbe, dann falsche Woche). Eigene Umstellung nicht nötig. Der Dialog selbst ist modal und fest an seine `startOfWeek` gebunden |
| W2 | `WeeklyReflectionViewModel.saveReflection` (`:70`): `updatedAt: DateTime.now()`; `FirestoreDataSource.saveWeeklyReflection` (`:501`): Fallback `DateTime.now()` | Zeitstempel des Speicherns, kein „heute"-Bezug | nein (korrekt, soll Systemzeit sein) |
| L1 | `leaveBalanceNowProvider` (`leave_balance_view_model.dart:11`): `Provider<DateTime Function()>((ref) => DateTime.now)`; `_load()` liest `.year` einmalig (`:44`) | Lädt bei `build()` (Auth/Profil/Settings-Wechsel) und `ref.invalidate` (Einträge geändert) | **ja, real**: Dashboard (`dashboard_screen.dart:117`, `LeaveBalanceCard.compact`) und Settings (`settings_page.dart:103`) zeigen nach dem 31.12. weiter Resturlaub des Vorjahres, bis zufällig invalidiert wird. Karte steht dauerhaft auf dem Dashboard → am ehesten sichtbar |
| L2 | `YearlyLeaveRows` (`reports_page.dart:2833`): `ref.watch(leaveBalanceNowProvider)().year` | `year != currentYear` → Hinweis „Vorjahr" | wie L1; nach Silvester zeigt Jahres-Tab 2026 fälschlich die Resturlaubszeilen, obwohl `balance` (aus `_last`) noch das alte Jahr ist – konsistent, aber alt. Muss zusammen mit L1 mitgezogen werden, sonst Mismatch Jahr/Balance |
| S1 | `SettingsViewModel.setOvertimeBalance` (`settings_view_model.dart:235`): `lastOvertimeUpdate: now` | Zeitstempel der manuellen Eingabe | nein (Systemzeit korrekt; Clock-Injektion nur Test-Hygiene) |
| S2 | `edit_break_modal.dart:76` | `DateTime.now()` nur für Datumsanteil der Uhrzeit-Auswahl beim Bearbeiten einer Pause | **ja, Randfall**: Pause bearbeiten ruft Jahr/Monat/Tag von „jetzt" statt vom Eintragsdatum – Dialog über Mitternacht oder Bearbeiten eines Vortags (!) erzeugt Pausenzeit am falschen Tag. Prüfen, ob `_startTime`-Datum stattdessen genommen werden sollte; **nicht Teil von #387**, nur als Nebenbefund (Frage 6) |
| D1 | `dashboard_screen.dart:66`: `b.end ?? DateTime.now()` | Anzeige laufende Pause | nein (Dauer, nicht Datum); in #379 auditiert |
| D2 | `dashboard_state.dart:36-39` `initial({now})`, `time_precision.dart:33` `nowToMinute()` | Zeitstempel/Default | nein |
| D3 | `reports_page.dart:224` `nowToMinute()` für laufende Einträge im Tagesbericht | Dauer eines noch laufenden Eintrags | nein (Dauer) |
| X1 | `notification_service.dart:182` `tz.TZDateTime.now(tz.local)`, `app_lock_service.dart:43` (`_now` injizierbar) | Plan-/Sperrzeiten | nicht betroffen |

Zusammenfassung Wirkung: **real** = R2/R3 (Reports-Auswahl, inkl. Wochen-/Monatsbericht und damit Reflexion-Woche), L1/L2 (Urlaubskarte Jahreswechsel). **gering** = I1 (Fenster nur bei Monatswechsel, einmalig pro Tab-Sichtbarkeit), R7 (Jahres-Tab). **kein Eingriff** = Fallbacks R4/R5, `insights_utils.dart`, W2, S1, D*, X1.

## 2. Umstellung auf `todayProvider`

### Reports (ReportsViewModel, `Notifier`, nicht autoDispose)
- `build()` hat bereits `ref.watch(workRepositoryProvider/settingsRepositoryProvider)`. **Nicht** `ref.watch(todayProvider)` in `build()` verwenden: Tageswechsel würde den ganzen Notifier neu bauen (State weg, manuell gewählter Tag verloren, `_monthlyEntries` weg, unnötiger Neuladen-Lauf). Stattdessen in `build()` `ref.listen<DateTime>(todayProvider, _onDayChange)` — selbes Muster wie `DashboardViewModel` (`dashboard_view_model.dart:52`), Subscription wird mit dem Notifier entsorgt, kein Rebuild.
- `init()`/`ReportsState.initial()`: `today = ref.read(todayProvider)` statt `DateTime.now()`. `initial()` ist ein Factory ohne `ref` → Parameter `today` ergänzen (oder `init()` setzt ohnehin alles; `initial()` bekäme `DateTime`-Argument). Ergebnis normalisiert (`DateTime(y,m,d)`), behebt nebenbei Uhrzeit-in-`selectedDay` (R1), vgl. `selectDate` normalisiert bereits (#362).
- `_onDayChange(previous, next)`: Regel „Auswahl folgt nur, wenn sie auf dem bisherigen heute stand" (identisch Web #383):
  - `selectedDay == previous` (Tagesvergleich) → `selectedDay = next`; wenn Monat anders → `selectedMonth = DateTime(next.year,next.month)` + `_loadWorkEntriesForMonth`; sonst nur `_updateCalculatedReports()` (Wochen-/Tagesbericht neu, Monatsdaten sind schon geladen; bei Monatswechsel des „heute" neu laden).
  - `selectedMonth` folgt separat nur, wenn `selectedMonth == Monat(previous)` (Nutzer blättert den heutigen Monat an) → `Monat(next)` (nur Wechsel wenn Monat tatsächlich wechselt). Wenn Auswahl manuell, aber Monat = heutiger Monat und Monat wechselt: Auswahl bleibt, Monat bleibt (Auswahl ≠ heute → nichts).
  - Sonst nichts ändern („manuell gewählter Tag bleibt").
  - Während `isLoading`/laufender Multi-Select (`multiSelectMode`, `selectedDates`): Auswahl der Mehrfachselektion nicht anfassen; nur wenn `selectedDay == previous` nachziehen. Frage: ob laufenden Multi-Select-Modus beim Tageswechsel unangetastet lassen (Empfehlung ja).
  - Race: `_loadWorkEntriesForMonth` ist `async` ohne Generationszähler; Tageswechsel während Laden kann überholte Ergebnisse schreiben (gibt es heute schon bei schnellem `selectDate`). Für #387 reicht dasselbe Verhalten, ggf. kleiner Guard (`ref.mounted`) — im Plan prüfen.
- Rest der `DateTime.now()`-Fallbacks (R4/R5): auf `ref.read(todayProvider)` bzw. `selectedDay ?? ref.read(todayProvider)`. In der Page: `ref.watch(todayProvider)` ist nicht nötig (Fallbacks tot) → ggf. Fallbacks ganz auf Notifier-Getter `reportsNotifier.today` o. ä.; Entscheidung im Plan, minimal: ReportsViewModel-Methoden bekommen `_today` Getter, Page nutzt `selectedDay`/`selectedMonth` aus State (nie null machen: `selectedDay`/`selectedMonth` in State nicht-nullable? → `copyWith` ignoriert null, deshalb Fallback-Code bewusst belassen und auf `ref.read(todayProvider)` umstellen).
- `loadCurrentMonthData()` (R3): bei Tabwechsel soll der Nutzer **seine Auswahl behalten** (Web-Regel) oder auf heute zurück? Aktuelles Verhalten ist inkonsistent (nur Monat). Optionen: (a) unverändert lassen, nur `now → todayProvider` (kleinster Eingriff, Inkonsistenz bleibt); (b) Auswahl beibehalten und `selectedMonth` aus `selectedDay` ableiten (macht Konsistenz, verändert Verhalten – „Tabwechsel springt zurück auf aktuellen Monat" wäre weg); (c) bei Seiteneintritt auf heute zurücksetzen. Empfehlung (a) für #387, Inkonsistenz als Nebenbefund melden (Frage 4).

### Insights
- `InsightsViewModel.loadInsights()`: `now` aus `ref.read(todayProvider)` statt `DateTime.now()`. Nicht reaktiv machen (Daten sind einmal pro Tab-Sichtbarkeit geladen, `_loadTriggered`). Optional `ref.listen(todayProvider)` nur bei **Monatswechsel** (`next.month != previous.month`) und nur wenn bereits geladen (`state` ≠ initial) → `loadInsights()` erneut. Premium-Gating bleibt: das Laden wird erst durch die Premium-Page ausgelöst; ein Listener darf nicht laden, solange nie geladen wurde (Flag `_loaded`). Sonst Firestore-Reads für Nicht-Premium.
- `insights_utils.dart`: keine Änderung.

### Wochen-Reflexion
- Keine eigene Umstellung. Folgt `selectedDay` aus Reports (W1). `loadReflection(startOfWeek)` ist rein parametrisch. Schlüssel `yyyy-Www` aus `isoWeekYear/isoWeekNumber(startOfWeek)` bereits korrekt (Montag der Woche → Donnerstag der Woche ergibt ISO-Jahr; `iso_week.dart` TZ-unabhängig via UTC). Ein Wochenwechsel passiert nur, wenn die Reports-Auswahl wandert (R2 Regel), nie direkt im Dialog.

### Urlaub
- `leaveBalanceNowProvider` (`Provider<DateTime Function()>`) ist ein zweiter Zeitgeber neben `clockProvider` (Tests überschreiben ihn in `leave_balance_view_model_test.dart:32`, `yearly_leave_rows_test.dart:23`). Zwei Wege:
  - (A) **Abschaffen**: `LeaveBalanceViewModel` und `YearlyLeaveRows` lesen `ref.watch(todayProvider).year`; Tests auf `clockProvider.overrideWithValue` umstellen (Testanpassung in 2 Dateien + evtl. `dashboard_screen_leave_test.dart`).
  - (B) `leaveBalanceNowProvider` behalten, aber defaultmäßig aus `todayProvider` speisen (`(ref) { final t = ref.watch(todayProvider); return () => t; }`) — bestehende Overrides bleiben gültig, Tageswechsel kommt automatisch. Nachteil: Provider ändert sich bei jedem Tageswechsel → jeder Watcher wird jedes Mal neu gebaut; Aussage „Funktion" wird zur Fassade.
  - Empfehlung (A), da `leaveBalanceNowProvider` laut Issue ausdrücklich genannt ist und nur 3 Fundstellen hat.
- Reaktion auf den Jahreswechsel im `LeaveBalanceViewModel`: `ref.listen(todayProvider)` und bei `next.year != previous.year` → `reload()` (nicht `ref.watch` in `build()`: würde `_last` zwar behalten, aber jeden Tag neu laden: 12 Monats-Abfragen pro Tageswechsel). In `YearlyLeaveRows` genügt `ref.watch(todayProvider.select((d) => d.year))` → Rebuild nur zum Jahreswechsel.
- Während des Reloads zeigt `LeaveBalanceState(isLoading:true, balance:_last)` kurz das alte Jahr (Anzeige flackert nicht auf „leer"); Sollte das Ladejahr nicht zum Jahr der Balance passen, besser `_last` verwerfen (Resturlaub Vorjahr ist falsche Info). `LeaveBalance` enthält Jahr? (`calculateLeaveBalance(entries, year, entitlement)` — im Plan prüfen, ob `balance.year` existiert für den Abgleich; sonst `_last=null` bei Jahreswechsel).

### Autodispose/Rebuilds
- `todayProvider` ist `NotifierProvider` ohne autoDispose, wird nur bei Lesern gebaut; Timer wird bei Dispose des Containers abgebrochen. Mehr Leser ändern nichts am Timer (ein Timer pro Container). `ref.listen` in `ReportsViewModel`/`InsightsViewModel`/`LeaveBalanceViewModel` hält `todayProvider` am Leben, solange diese VMs gebaut sind (sind nicht autoDispose, gebaut ab erstem Zugriff, z. B. LeaveBalance auf dem Dashboard ab Start). Harmlos, ein Timer.
- `ref.watch(todayProvider)` nur in reinen Anzeige-Providern/Widgets verwenden (wie `holidayTodayProvider`); in Notifier-`build()` immer `ref.listen`, sonst Neuaufbau mit Zustandsverlust.
- Tests, die `todayProvider` indirekt auslösen, brauchen `TestWidgetsFlutterBinding.ensureInitialized` (Observer, siehe `holiday_today_provider_test.dart` `setUpAll`). Bestehende `reports_view_model_test.dart`, `leave_balance_view_model_test.dart`, `insights`-/`yearly`-Tests laufen bisher evtl. ohne Binding → `setUpAll` ergänzen oder `todayProvider` überschreiben.

## 3. Testplan

Infrastruktur vorhanden: `test/support/fake_clock.dart` (`FakeClock(base)`, `bind(async)`, `jumpTo`), Vorbild `holiday_today_provider_test.dart` (fakeAsync, `clockProvider.overrideWithValue(clock.call)`, `async.pendingTimers`, `container.dispose()`), `dashboard_view_model_day_change_test.dart`. CI: `TZ=Europe/Berlin flutter test` (`ci.yml:52`) zusätzlich zum normalen Lauf. Nur Konstruktor `DateTime(y,m,d,…)` lokal, **kein** `DateTime.now()`, keine Wochentags-/Datums-Abhängigkeit; Datumswerte so wählen, dass sie in beiden TZ gelten (lokale Konstruktoren sind TZ-stabil). Sommerzeit-Wechsel (Sonntag 25.10.2026 03:00 → 02:00 in Berlin) **bewusst nicht** als Testzeitpunkt (Midnight-Timer rechnet über `DateTime(y,m,d+1)`, sicher), aber ein Test „Tageswechsel am Tag der Umstellung" wäre optional.

Feste Daten (Vorschlag):
- Tageswechsel innerhalb Monat: Fr 2026-10-02 23:59:30 → Sa 2026-10-03 00:00:00.
- Monatswechsel: 2026-10-31 23:59:30 → 2026-11-01.
- Jahres-/ISO-Wechsel: 2026-12-31 (Do, ISO 2026-W53) 23:59:30 → 2027-01-01 (Fr, **noch 2026-W53**) → Mo 2027-01-04 (**2027-W01**). 2026 hat 53 ISO-Wochen (Do 1. Januar).
- Wochenwechsel: So 2026-10-04 23:59:30 → Mo 2026-10-05 (Woche 40 → 41).

### Reports (`reports_view_model_test.dart`, neue Gruppe „Tageswechsel (#387)")
1. Auswahl auf heute → um 00:00 `selectedDay == nächster Tag`, `selectedMonth` stimmt, Wochenbericht auf neue Woche bei Montag.
2. Manuell gewählter anderer Tag bleibt (z. B. 2026-10-01 gewählt, Wechsel auf 03.10.).
3. Auswahl auf heute + Monatswechsel → `selectedMonth` neuer Monat, `getWorkEntriesForMonth(2026, 11)` aufgerufen (Mock-Verify), `selectedDay` 1.11.
4. Auswahl manuell + Monatswechsel: Auswahl und Monat unverändert, kein Reload.
5. `selectedMonth` blättert heutigen Monat an, Auswahl manuell im selben Monat, heute wechselt Monat: Verhalten laut Entscheidung (Empfehlung: nichts ändern).
6. Resume-Pfad: `clock.jumpTo` + `todayProvider.notifier.refresh()` (Standby-Fall) → Auswahl folgt.
7. Multi-Select aktiv → `selectedDates` bleibt.
8. `selectedDay` ohne Uhrzeit (normalisiert) in `init()`.
9. Dispose: `c.dispose()` → `async.pendingTimers` leer (kein Timer-Leak).
10. Bestehende Reports-Tests so anpassen, dass `init()` über `clockProvider` feste Daten bekommt (heute nutzen sie vermutlich `DateTime.now()` → TZ-/datumsabhängig; im Plan prüfen).
Widget-Test (`reports_page_widget_test.dart`): Tageswechsel im `fakeAsync`/`tester.pump(Duration)` → Kalenderauswahl-Tag und Wochen-Titel (KW) wechseln; nur wenn der Kalender im Test sinnvoll steuerbar ist, sonst VM-Tests ausreichend.

### Insights
- `loadInsights` mit Fake-Uhr 2026-11-01: Verify, dass `getWorkEntriesForMonth` für (2026,11),(2026,10),(2026,9) aufgerufen wird; Jahreswechsel 2027-01-01 → (2027,1),(2026,12),(2026,11).
- Falls Listener: nach Monatswechsel + bereits geladen → erneuter Ladevorgang; nie geladen (nicht premium) → kein Repository-Zugriff (`verifyNever`).

### Reflexion
- `weekly_reflection_view_model_test.dart`: Schlüssel-Test (keine Logikänderung, Regression): `loadReflection(DateTime(2027,1,4))` → year 2027/week 1; `loadReflection(DateTime(2026,12,28))` → 2026/53; `loadReflection(DateTime(2024,12,30))` → 2025/1. Dazu Reports-Test: Auswahl folgt über Wochen-/Jahreswechsel, `startOfWeek` der Page ergibt 2027-01-04.
- Widget-Test Dialog: bei Reports-Tageswechsel bei **offenem** Dialog bleibt Text und Woche unverändert (Verhalten festschreiben).

### Urlaub
- `leave_balance_view_model_test.dart`: Fake-Uhr 2026-12-31 23:59:30; nach Jahreswechsel `getWorkEntriesForMonth(2027, 1…12)` aufgerufen, `_last` nicht mit Vorjahresdaten weitergezeigt; Tageswechsel innerhalb des Jahres → **kein** Reload (`verifyNever` / Aufrufzähler).
- `yearly_leave_rows_test.dart`: Jahreswechsel im Widget → `year` 2026 vom Resturlaub auf Vorjahr-Hinweis.
- `dashboard_screen_leave_test.dart`: Overrides umstellen.

### Zusatz
- `fake_clock_test.dart`/`today_provider`-Tests existieren schon (siehe `test/support`); `today_provider_test.dart` nicht ersichtlich im Grep, ggf. vorhanden unter `test/core/providers`.
- Lokal beide Läufe: `flutter test` und `TZ=Europe/Berlin flutter test`; zusätzlich ein Lauf mit `TZ=America/Los_Angeles`/`UTC` zur Absicherung (nicht CI).

## 4. Aufteilung in PRs — Empfehlung

Alle Teile berühren verschiedene Dateien, sind unabhängig voneinander mergebar. Empfohlen **zwei PRs** (kleine Diffs, ein Review-Thema je PR), ein Issue (#387) → PR A `Closes #387` erst nach B, oder A „Refs #387" und B „Closes #387":

| PR | Inhalt | Dateien (Richtwert) | Risiko |
|---|---|---|---|
| **A: Reports** (+ Reflexion indirekt) | `ReportsViewModel` (init, `_onDayChange`, Fallbacks), `ReportsState.initial(today)`, `reports_page.dart` Fallbacks, Tests; Reflexion nur Regressionstests | `reports_view_model.dart`, `reports_state.dart`, `reports_page.dart`, 2–3 Tests | mittel (meiste Logik, Zustandsregel) |
| **B: Urlaub + Insights (+ Jahres-Tab)** | `LeaveBalanceViewModel` Jahres-Listener, `leaveBalanceNowProvider` abschaffen, `YearlyLeaveRows`, `InsightsViewModel` `todayProvider`, `YearlyReportState.initial()`/`_loadIfNeeded` Jahr | `leave_balance_view_model.dart`, `reports_page.dart` (kleine Stellen 1381, 2833), `insights_view_model.dart`, `yearly_report_state.dart`, Tests | gering–mittel |

Alternative: Urlaub (L1/L2, am deutlichsten sichtbar, Dashboard) als eigener, kleinster PR zuerst. Konflikt-Risiko `reports_page.dart` (beide PRs): Fallback-Zeilen (209…1132) in A, 1381/2833 in B – getrennte Hunks, rebase unkritisch. Kein Backend/Web, keine Doku außer `mobile/CLAUDE.md` Abschnitt „Tageswechsel (#379)" ergänzen (Reports/Urlaub/Insights-Regel „`ref.listen` statt `ref.watch` in Notifier-`build()`; Auswahl folgt nur, wenn sie auf bisherigem heute stand").

Voraussetzungen: `dart run build_runner build` **nicht** nötig, wenn kein `@riverpod`-Annotation neu (alle drei VMs sind handgeschriebene `NotifierProvider`; `leaveBalanceNowProvider` ist handgeschrieben). Falls (B) → `clockProvider` wird nur gelesen. Keine ARB-Änderung.

## 5. Risiken

- **Premium-Gating:** `ReportsPage` Tabs (`:661, :1108, :1426, :1671`) gaten per `isPremiumProvider` + `PremiumBlurGate`. Insights/Jahresbericht-Laden erst bei Sichtbarkeit. Ein `todayProvider`-Listener im `InsightsViewModel`/`YearlyReportViewModel` darf **nicht** unbedingt `loadInsights()` auslösen → nur wenn schon geladen (sonst Reads für Nicht-Premium und ausgeloggte Nutzer, `permission-denied`-Logs). Regressionstest `reports_page_subscription_test.dart` im Blick behalten.
- **Wochen-Reflexion-Schlüssel beim Jahreswechsel:** Schlüssel ist bereits ISO-korrekt (#354, Test `iso_week_test.dart`). Gefahr nur bei neuen Berechnungen aus `selectedDay.year` + KW statt `isoWeekYear`. In der Umsetzung `isoWeekYear(startOfWeek)` weiterverwenden, nie `date.year`. Folge der Reports-Regel: Silvesterwoche (Mo 28.12.2026 – So 3.1.2027) ist durchgehend `2026-W53`; die Auswahl wechselt um Mitternacht 31.12.→1.1. Tag/Monat/Jahr, die Reflexions-Woche bleibt `2026-W53`. Test fixieren.
- **Datenverlust ungespeicherter Reflexions-Eingabe beim Wochenwechsel:** Der Dialog ist an `widget.startOfWeek` gebunden, Controller werden einmalig (`_controllersInitialized`) befüllt, `loadReflection` wird nur in `initState` aufgerufen. Wochenwechsel in den Reports hinter dem modalen Dialog ändert den Dialog **nicht** (kein `ref.watch(selectedDay)`), Text bleibt, Speichern geht in die ursprüngliche Woche. Risiko entsteht nur, wenn der Dialog künftig auf `selectedDay`/`todayProvider` reagiert → **nicht tun**. Nebenrisiko: `WeeklyReflectionViewModel` ist ein einziger globaler State (nicht pro Dialog): öffnet der Nutzer nach Mitternacht (Auswahl gefolgt) den Dialog neu, wird der State überschrieben; ungespeicherter Text eines **geschlossenen** Dialogs ist ohnehin weg (kein Draft). Kein neues Risiko, sollte aber nicht verschlechtert werden.
- **Zustandsverlust durch `ref.watch(todayProvider)` in `build()`** der VMs (siehe 2). Test: manuell gewählter Tag bleibt.
- **Multi-Select/Laden während Tageswechsel:** `_loadWorkEntriesForMonth` ohne Generationszähler (überholte Ergebnisse können `_monthlyEntries` überschreiben); Mitternachts-Wechsel + gleichzeitiges Laden → ggf. kleiner Guard. Siehe auch `saveWorkEntry` nach Mitternacht lädt Monat von `selectedDay` (nicht heute) – korrekt.
- **Eingeloggt mit API-Report:** `_loadReportsFromApi(day)` mit neuem Tag nach Tageswechsel (Netzaufruf, async, kein Race-Schutz: späteres Ergebnis eines alten Tags kann den State überschreiben). Bestehendes Risiko, durch Tageswechsel leicht erhöht (zusätzlicher Auslöser).
- **Jahresübergang Urlaub:** Reload = 12 Monats-Abfragen (Firestore/API), einmal pro Jahr, vertretbar. Profilwechsel (#138/#239) ist über `workRepositoryProvider` abgedeckt, nicht über `todayProvider`.
- **Tests/Binding:** `todayProvider` registriert `WidgetsBindingObserver`; bestehende Unit-Tests ohne `TestWidgetsFlutterBinding.ensureInitialized()` brechen sonst (`WidgetsBinding.instance`-Assertion). Betrifft Tests von Reports-, Leave-, Insights-ViewModel.
- **Doppelte Uhr-Quellen:** Nach Umstellung darf es nur `clockProvider`/`todayProvider` geben; `leaveBalanceNowProvider` abschaffen (A), sonst driften Tests auseinander.
- Backend/Rechenlogik: unberührt (keine Pausen-/Überstundenlogik).

## Offene Fragen (mit Empfehlung)

1. **Urlaub:** `leaveBalanceNowProvider` abschaffen und auf `todayProvider`/`clockProvider` umstellen (A) oder als Fassade behalten (B)? Empfehlung: **(A)** abschaffen, Tests auf `clockProvider` umstellen.
2. **PR-Schnitt:** zwei PRs (A Reports, B Urlaub+Insights+Jahres-Tab) oder drei (Urlaub einzeln, da am deutlichsten sichtbar)? Empfehlung: **zwei PRs**, A zuerst; Urlaub bei Bedarf als erster Mini-PR.
3. **Kalender-„heute"-Markierung:** In Mobile existiert keine (nur Auswahl). Soll sie als eigenes Feature ergänzt werden (analog Web `isToday`) oder nicht? Empfehlung: **nein**, nicht Teil von #387 (neue UI, ggf. Design/Barrierefreiheit); ggf. eigenes Issue.
4. **`loadCurrentMonthData()` bei Tabwechsel** (setzt Monat, nicht Auswahl): so lassen (a), Auswahl beibehalten und Monat daraus ableiten (b) oder auf heute zurücksetzen (c)? Empfehlung: **(a)** für #387, Inkonsistenz Monat/Auswahl als separates Issue notieren; nur `now → todayProvider`.
5. **Insights/Jahres-Tab bei Wechsel (Monat/Jahr) automatisch neu laden** (nur wenn bereits geladen) oder nur beim nächsten Öffnen? Empfehlung: **Insights**: nur `now → todayProvider`, kein Listener (Fenster 3 Monate, Neuladen beim nächsten Tab-Öffnen genügt). **Jahres-Tab**: nur `todayProvider.year` beim Laden, kein Auto-Wechsel des vom Nutzer gewählten Jahres (konsistent zur „Auswahl bleibt"-Regel; nur wenn die Anzeige auf dem bisherigen aktuellen Jahr stand, folgt sie – optional).
6. **Nebenbefund `edit_break_modal.dart:76`** (Pausenzeit bekommt Datum von „jetzt" statt vom Eintrag): separates Bug-Issue anlegen, nicht in #387 anfassen? Empfehlung: **separates Issue**, prüfen ob real reproduzierbar (Pause bei Vortags-Eintrag bearbeiten).
7. **Reports bei laufendem Multi-Select** beim Tageswechsel: Mehrfachauswahl unangetastet lassen? Empfehlung: **ja**.
8. **Verhalten bei Urlaubs-Jahreswechsel**: alte Bilanz bis Reload behalten (kurz angezeigt) oder sofort leeren (`isLoading`-Spinner)? Empfehlung: **leeren** (Vorjahres-Resturlaub ist als aktuelles Jahr falsch), nach Prüfung ob `LeaveBalance` ein Jahr trägt.

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. `leaveBalanceNowProvider` abschaffen, Tests auf `clockProvider`/`todayProvider` umstellen.
2. Zwei PRs: A Reports (+ Reflexion-Regressionstests), B Urlaub + Insights + Jahres-Tab. A zuerst.
3. Keine neue „heute"-Markierung im Mobile-Kalender (nicht Teil von #387).
4. `loadCurrentMonthData()` beim Tabwechsel so lassen, nur `now` → `todayProvider`; Inkonsistenz im PR-Text als Nebenbefund.
5. Insights und Jahres-Tab: kein Auto-Reload bei Monats-/Jahreswechsel; Insights nimmt `now` nur aus `todayProvider` beim Laden, Jahres-Tab ohne Auto-Wechsel des gewählten Jahres.
6. `edit_break_modal.dart:76`: eigenes Bug-Issue (Hauptsession legt es an, ist angelegt).
7. Laufenden Multi-Select in Reports beim Tageswechsel unangetastet lassen.
8. Urlaub-Jahreswechsel: Bilanz sofort leeren/Ladezustand statt Vorjahreswerte zeigen, sofern `LeaveBalance` das Jahr trägt; sonst Reload ohne Zwischenzustand mit kurzer Begründung.
