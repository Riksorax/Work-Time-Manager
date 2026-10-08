# Web-Research: #372 — Dashboard: Tageswechsel (Mitternacht) + anonymer visibilitychange-Listener
Datum: 2026-10-04
Typ: BUG-Analyse (kein Flutter-Port)
Feature-Ordner: web/src/app/features/dashboard/ (+ ggf. neuer Core-Service `core/services/today.ts`)

## Quellen
- `web/src/app/features/dashboard/dashboard.service.ts` (516 Z.), `dashboard.ts`/`dashboard.html` (reine Darstellung, keine Datumslogik)
- `web/src/app/core/services/work-entry.ts`, `overtime.ts`, `domain/utils/overtime.utils.ts`
- Mobile-Referenz: `mobile/lib/presentation/view_models/dashboard_view_model.dart`, `widgets/holiday_banner.dart`, `holiday_today_provider.dart`
- Issue #372 (Label `bug`), Vorarbeit `web/thoughts/279-plan.md`, `371-research.md`

## 1. Ist-Stand: wie „heute“ heute geladen wird
- `DashboardService` ist `providedIn: 'root'` (lebt praktisch die ganze Sitzung). Ein `effect()` (Z. 115) reagiert nur auf `authSvc.user()` und ruft `_init(uid)`.
- `_init` (Z. 169): `new Date()` einmalig als `today`; `firstValueFrom(workSvc.getTodayEntry())`. `getTodayEntry()` berechnet den Datumsschlüssel **zum Abo-Zeitpunkt** (`_firebaseToday`: `monthId` + `String(today.getDate())`; anonym `_localGet(new Date())`). Wegen `firstValueFrom` gibt es genau eine Momentaufnahme, kein Live-Abo; selbst ein Live-Abo bliebe auf dem Tag des Abos fixiert.
- Danach: `getOvertime()`, `getLastUpdateDate()`, Settings, Tagessoll `getEffectiveDailyTarget(today, ...)`, `calculateInitialOvertime(stored, lastUpdate, initialDaily)` (vergleicht `lastUpdate` mit `new Date()`: gleicher Tag = Base = Stored − Daily).
- Die Entry-Id/`date` kommen aus `workSvc.emptyEntry(today)` bzw. aus dem geladenen Eintrag. `initialState()`/`emptyEntry()` am Dateianfang duplizieren das und werden einmalig bei Service-Konstruktion ausgewertet (harmlos, `_init` überschreibt).

## 2. Was vom „heute“ abhängt (alles an `new Date()` hängend, nie reaktiv)
| Stelle | Datumsbezug | Verhalten nach Mitternacht |
|---|---|---|
| `_s.workEntry` (`id`, `date`) | Tag des Ladezeitpunkts | bleibt Vortag |
| `_targetDailyMs()` (Z. 496) | `getEffectiveDailyTarget(new Date(), ...)` **jedes Mal frisch** | wechselt auf den Wochentag des neuen Tags, obwohl der Eintrag noch der Vortag ist |
| `_recalculateOvertime` (jeder Tick), `_recalculateState` | über `_targetDailyMs` | Soll springt (z. B. Fr -> Sa: Soll 0, Daily +8 h; So -> Mo: Soll 8 h) |
| `isExtraDay` | nur in `_init` gesetzt | bleibt Vortag (inkonsistent zum frischen Soll) |
| `_tick` / `_totalBreakMs(…, now)` | `now`-basiert, absolut in ms | läuft einfach weiter (>24 h möglich) |
| `_autoSave` (alle 30 Ticks) | speichert `_s().workEntry` unverändert | schreibt weiter in den Vortag (Tag aus `entry.date`) |
| `calculateInitialOvertime` / `_saveOvertime` | `isSameDay(lastUpdate, new Date())`, `saveLastUpdateDate(new Date())`, Backend setzt `lastUpdated` = jetzt | siehe Risiko 4 |
| `holidayToday` | `_today`-Signal (#279) | **einziges** Stück mit Tageswechsel-Handling |
| `_parseTime(e.date, ...)` | Basis = `entry.date` | manuelle Zeiten landen auf dem Vortag |

## 3. Der zweite `visibilitychange`-Listener (Z. 146)
- Anonyme Arrow-Function, `document.addEventListener('visibilitychange', …)`, nie entfernt (kein `removeEventListener`, kein `destroyRef.onDestroy`).
- Zweck (Kommentar „Flow 4“): Tab-Refokus bei laufendem Timer -> `_recalculateOvertime()`, weil Browser `setInterval` in Hintergrund-Tabs drosseln. Wirkung ist gering: aktualisiert nur Daily/Total/ExpectedEnd, **nicht** `elapsedMs`/`grossMs` (das macht erst der nächste `_tick`, <= 1 s später). Faktisch durch den 1-s-Tick redundant, kann aber bleiben oder in den neuen Tageswechsel-Handler wandern.
- „Leck“: Im Browser lebt der Root-Service ewig, praktisch relevant ist es in Tests: jedes `TestBed.resetTestingModule()` lässt einen Listener auf dem globalen `document` zurück, der bei späteren `visibilitychange`-Events (z. B. im #279-Test „aktualisiert bei visibilitychange“) auf zerstörten Services `_recalculateOvertime()` ausführt. Der Destroy-Test (`dashboard.service.spec.ts` Z. 155) prüft nur „irgendein `removeEventListener('visibilitychange')`“ und deckt das nicht ab.
- Daneben: ungenutztes Feld `_timerSub` (Z. 109).

## 4. Mitternachts-Mechanismus aus #279 (wiederverwendbar?)
Z. 76-166: `_today = signal(toDateKey(new Date()))`, benannter `onVisible`-Listener (nur bei `visible`: `_refreshToday` + `_scheduleMidnight`), `setTimeout` bis `new Date(y, m, d + 1)` (min. 1000 ms, kein Drift, DST-sicher da lokal berechnet), Cleanup über `destroyRef.onDestroy`. `_today` ist ein reiner String-Key (`YYYY-MM-DD`, lokale Felder), nur von `holidayToday` gelesen (`private`).
- Ja, wiederverwendbar: als eigener kleiner Service (Vorschlag `core/services/today.ts`, `TodayService`, root) mit `readonly today = signal<string>` (Key) + `readonly now()`-freier API, Timer + Listener + `DestroyRef` dort gekapselt. `DashboardService` und später Reports/Kalender („today“-Markierung, `CalendarComponent` nutzt eigenes `new Date()`) konsumieren es. `holidayToday` liest dann `todayService.today()`.
- Lücken des #279-Mechanismus, die für einen echten Tageswechsel zu schließen sind: (a) kein Handler bei Rechner-Standby/Wiederaufwachen ohne Tab-Wechsel (`setTimeout` feuert nach Sleep meist beim Aufwachen, aber nicht garantiert zeitnah) -> zusätzlich `focus`/`pageshow` oder Key-Vergleich im 1-s-Tick bei laufendem Timer; (b) `_refreshToday` setzt immer neu, Signal-Gleichheit verhindert Doppel-Auslösung (Strings, ok).

## 5. Fehlverhalten (Seite über Mitternacht offen)
1. Gestoppter/leerer Eintrag (häufigster Fall: Laptop über Nacht offen): Dashboard zeigt weiter den Vortag (Datum, Zeiten, Soll, Überstunden). **Start-Button schreibt auf den Vortag**: `startOrStopTimer` -> `{...e, workStart: nowToMinute()}` mit `e.date`/`e.id` = Vortag -> `saveEntry` speichert unter dem Vortags-Tagesschlüssel, aber `workStart` ist heute (anonym `_localSave` und `ApiClient.saveWorkEntry`/`toDto` nehmen Tag aus `entry.date`). Ergebnis: Vortagseintrag überschrieben/verfälscht, heutiger Tag bleibt leer. Dasselbe bei „Neue Session“ (`startNewSession`) auf einem abgeschlossenen Vortag (überschreibt `workStart`/`workEnd` des Vortags!) und `setManualStartTime`/`EndTime` (`_parseTime(e.date, …)` = Vortag, hier wenigstens konsistent).
2. Laufender Timer über Mitternacht: **ein Eintrag über zwei Tage** (Eintrag Vortag, `workEnd` später am Folgetag, Brutto > 24 h möglich). `_targetDailyMs` wechselt dabei auf das Soll des neuen Wochentags (siehe Tabelle) -> Tages- und Gesamtüberstunden und „voraussichtliches Ende“ springen. Beim Stoppen nach Mitternacht wird `_saveOvertime` mit diesem verfälschten Wert ausgeführt. Report/Backend rechnet den Eintrag komplett dem Starttag zu.
3. Pausen: offene Pause (`end` undefined) läuft über Mitternacht mit weiter; `calculateAndApplyBreaks` beim Stoppen rechnet auf Basis Brutto > 24 h.
4. Überstunden-Basis: Backend setzt `lastUpdated` beim `saveOvertime` auf „jetzt“. Wird nach Mitternacht für den Vortag gespeichert, hält `calculateInitialOvertime` den Stand beim nächsten `_init` für „heute gespeichert“ und zieht den neuen Tages-`initialDaily` ab -> falsche Basis. Beim Tageswechsel-Reinit also die Basis explizit aus dem gespeicherten Wert nehmen (siehe Empfehlung).
5. Parallele `_init`-Läufe haben kein Abbruch-/Generationskennzeichen: ein später fertig werdender alter Lauf überschreibt den Zustand (gilt für Auth-Wechsel genauso, bei Tageswechsel zusätzlich relevant).

## 6. Mobile-Referenz
- `DashboardViewModel` (Riverpod) hat **kein** Tageswechsel-Handling: `_init` lädt einmalig `getTodayWorkEntry`, `_calculateElapsedTime`/`_getEffectiveTargetDailyHours` benutzen `DateTime.now()`, Timer läuft ohne Datumsprüfung weiter. Es gibt dort keine Mitternachts-Logik für den laufenden Timer (also derselbe Fehler in Mobile; es existiert keine zu portierende Lösung).
- Einziger Tageswechsel in Mobile: `HolidayBanner` (`WidgetsBindingObserver`, `resumed` + `Timer` bis lokale Mitternacht, `ref.invalidate(holidayTodayProvider)`), `holidayTodayProvider` über `clockProvider` (testbare Uhr). Mobile-Dashboard-VM wird nur nach Sync (`settings_page.dart` Z. 497) invalidiert.
- Folge: Lösung für Web ist eine **eigene Entscheidung**; Mobile-Fix wäre ein separates Issue (nicht im Scope; Backend/`CLAUDE.md`-Regel „Web rechnet wie Backend“ gibt keine Split-Semantik vor, Backend-Domain kennt keinen Mitternachts-Split).

## 7. Offene Beobachtung (Profilwechsel, bereits heute)
`DashboardService` reagiert **nicht** auf `workProfile.activeProfileId`: nur der Auth-Effect triggert `_init`; Settings werden reaktiv nachgeladen (cache), Eintrag/Überstunden nicht. `WorkProfileSwitcher.select()` ruft nur `setActiveProfile`. Folge: nach Profilwechsel zeigt das Dashboard den Eintrag des alten Profils, ein laufender Timer-`_autoSave` und Aktionen schreiben über `activeProfileIdForApi` ins **neue** Profil (Datenvermischung). Nicht Teil von #372, aber derselbe Reinit-Mechanismus sollte `profileId` als Trigger kennen (siehe Frage 4). Vor dem Fix im Browser verifizieren (nicht gelaufen; reine Code-Analyse).

## 8. Domain-/Mapping-Tabelle (Bug-Kontext)
| Konzept | Web | Mobile |
|---|---|---|
| „heute“-Quelle | `new Date()` überall, `_today`-Key nur Feiertag | `DateTime.now()` / `clockProvider` (nur Feiertag) |
| Tageswechsel-Signal | `_today` (privat in `DashboardService`) | Banner-Observer + Invalidate |
| Reinit-Trigger | Auth-Effect | Provider-Rebuild bei Repo-Wechsel |
| Auto-Save | 30 s Tick | 30 s Timer |

## 9. Lösungsrichtung / Empfehlung
1. Neuer `TodayService` (root): `today = signal<string>` (Key), Midnight-`setTimeout` + benannter `visibilitychange`-Handler + `focus`/`pageshow`, Cleanup via `DestroyRef`. `holidayToday` und Dashboard lesen davon; #279-Verhalten/Tests bleiben (Spec ggf. auf Service verlagern, `holidayToday`-Tests bleiben grün).
2. Dashboard: `effect` auf `today()` (ersten Lauf überspringen) -> `_onDayChange()`:
   - Kein laufender Timer (kein `workStart` oder `workEnd` gesetzt): ausstehende Änderungen sind schon gespeichert (jede Aktion speichert sofort) -> `_init` für den neuen Tag. Basis-Überstunden nicht über `lastUpdated`, sondern aus Stored (neuer optionaler Parameter), sonst Risiko 4.
   - Laufender Timer: Entscheidung nötig (Frage 1).
3. `_targetDailyMs` und `isExtraDay` an das **Eintragsdatum** (`workEntry.date`) statt `new Date()` koppeln — behebt die Sprünge unabhängig vom Split und macht Eintrag/Soll konsistent.
4. Defensive Absicherung: Aktionen (`startOrStopTimer`, `startNewSession`, `startOrStopBreak`) prüfen vor dem Schreiben, ob `toDateKey(entry.date) === today()`; bei Abweichung zuerst Tageswechsel behandeln (verhindert den Datenverlust aus 5.1 auch bei verpasstem Timer/Standby).
5. `_init` mit Generationszähler gegen parallele Läufe.
6. Anonymen Listener entfernen: Aufgaben (Recalc bei Refokus) in den benannten Handler integrieren, Cleanup per `DestroyRef`; `_timerSub` entfernen.

## 10. Risiken
- Datenverlust/-verfälschung beim Umschalten: laufender `_autoSave` darf nicht den neuen Tag mit altem Eintrag überschreiben -> Reihenfolge: `_stopTimer()`, finales `saveEntry` des alten Eintrags (awaiten), erst dann neuen Tag laden. Offline/API-Fehler beim Final-Save: nicht verwerfen (Retry/Hinweis), `_autoSave` schluckt Fehler still.
- Laufender Timer: Split bei 00:00 vs. Weiterlaufen (Frage 1). Split-Variante: Vortag `workEnd` = 00:00 des Folgetags (Minutenraster ok), offene Pause am Vortag schließen und im neuen Eintrag ab 00:00 neu öffnen, Pflichtpausen (`calculateAndApplyBreaks`) für den Vortag anwenden, Überstunden des Vortags speichern, neuer Eintrag `workStart` 00:00. Gefahr: Backend/Reports erwarten `workEnd` eventuell am selben Kalendertag (nicht geprüft, `server/…/Domain/` kennt keine Cross-Day-Regel, hier gibt es keine Validierung gefunden). Weiterlaufen-Variante: Brutto > 24 h, Soll bleibt an Eintragsdatum gekoppelt.
- Ungespeicherte Pausen/Zeiten: jede Aktion speichert sofort (`save=true`), das Fenster ist nur der 30-s-Autosave bei laufendem Timer.
- Profilwechsel: siehe 7. Während des Tageswechsel-Reinit ist `activeProfileId` zu beachten (Profil kann zwischen Final-Save und Reload wechseln).
- Anonym/localStorage: Speichern/Lesen synchron und tagesschlüsselbasiert (`local_work_entries_YYYY_MM`, `days[d]`); Tageswechsel hier unkritisch, aber derselbe Start-auf-Vortag-Bug. `getAllLocalEntries`/DataSync unbetroffen.
- Login/Logout um Mitternacht: Auth-Effect und Tageswechsel-Effect können beide `_init` auslösen -> Generationszähler (Punkt 5).
- Hintergrund-Tabs/Standby: `setTimeout` kann stark verspätet feuern; ohne `focus`/Tick-Check bleibt der Vortag sichtbar bis zur nächsten Interaktion.
- DST: Tageslänge 23/25 h; lokaler Mitternachts-Key korrekt (`new Date(y, m, d+1)`); Elapsed rechnet in absoluten ms. 2026: 29.03. (23 h) und 25.10. (25 h) — der 25.10. liegt in 3 Wochen. Eintrag über Umstellungsnacht (Split: 00:00 existiert immer, Umstellung 02:00-03:00).
- Premium: kein Bezug (Dashboard nicht gated).

## 11. Tests
Muster aus `dashboard.service.spec.ts` weiterverwenden: `vi.useFakeTimers()`, `vi.setSystemTime(new Date(y, m, d, h, min))` (lokale Konstruktoren, keine UTC-Strings), `advanceTimersByTime`/`advanceTimersByTimeAsync` (für asynchronen `_init`/Saves), Fake-Services via `TestBed`. CI läuft bereits mit `TZ=Europe/Berlin` (`ci.yml`); Tests müssen in UTC **und** Berlin grün sein, nie 23/25 h hart kodieren, sondern `new Date(next).getTime() - Date.now()`.
- TodayService: Mitternacht (23:59:30 -> +31 s), Min-Delay 1 s, Folgetag-Timer, `visibilitychange` visible/hidden, `focus`, Cleanup (`vi.getTimerCount()`, `removeEventListener` mit **derselben** Handler-Referenz: Spy über `addEventListener.mock.calls` vergleichen, nicht nur Aufruf prüfen), Jahreswechsel 31.12. -> 1.1., Schaltjahr 28.02.2028 -> 29.02. (Daten fest).
- Dashboard ohne Timer über Mitternacht: Eintrag Vortag (Fake `getTodayEntry` liefert je nach `Date.now()`), nach Mitternacht `workEntry().date` = neuer Tag, Soll/Überstunden für neuen Wochentag (Fr 2026-10-02 -> Sa 10-03 mit Soll 0; So -> Mo), kein `saveEntry`-Aufruf mit neuem Datum auf alten Eintrag.
- Regression 5.1: Start nach Mitternacht erzeugt `saveEntry` mit `date` = heute (nicht Vortag).
- Laufender Timer über Mitternacht (je nach Entscheidung): Split -> zwei `saveEntry`-Aufrufe in definierter Reihenfolge (alter Eintrag `workEnd` 00:00, dann neuer Tag), offene Pause, Überstunden-Basis nicht doppelt, `_autoSave` nach Switch schreibt nur neuen Eintrag; Weiterlaufen -> Soll bleibt Eintragstag.
- DST: Tageswechsel 2026-03-28 -> 29 (23-h-Tag) und 2026-10-24 -> 25 / 25 -> 26 (25-h-Tag), laufender Timer 22:00 -> 03:00 über die Umstellung ohne Fehlrechnung (Elapsed absolut).
- Listener-Leak: nach `TestBed.resetTestingModule()` darf ein `visibilitychange` keine Reaktion eines zerstörten Services auslösen (z. B. Spy auf `workSvc`/Recalc).
- Parallele `_init`-Läufe: später fertiger alter Lauf überschreibt Zustand nicht.
- Anonym vs. eingeloggt: `AuthService.user` Signal im Fake wechseln (Login um 23:59).
- Profilwechsel nur falls in Scope (Frage 4).

## 12. Offene Fragen (mit Empfehlung)
1. Laufender Timer über Mitternacht: (A) automatisch bei 00:00 splitten (Vortag endet 00:00, neuer Tag startet 00:00) oder (B) weiterlaufen lassen, Eintrag bleibt am Starttag, nur Soll an Eintragsdatum koppeln? Empfehlung: **B für diesen Bugfix** (kleinerer Eingriff, kein Datenmodell-Risiko, Mobile verhält sich gleich); Split als eigenes Feature/Issue klären (Auswirkung auf Backend-Reports, Pflichtpausen, Überstunden-Basis, Mobile-Parität).
2. Gestoppter oder leerer Eintrag nach Mitternacht: automatisch auf neuen Tag umschalten (ohne Nachfrage)? Empfehlung: **ja**, ohne Dialog (Vortag ist bereits gespeichert), plus Schutz nach 9.4.
3. Wiederverwendung: neuer `TodayService` (Core) statt Logik in `DashboardService` — passt das, und soll `CalendarComponent` („heute“-Markierung) gleich mitumgestellt werden? Empfehlung: Service ja; Kalender nicht in #372, ggf. Folge-Issue.
4. Profilwechsel (7) im selben PR beheben (Reinit-Trigger um `activeProfileId` erweitern + Autosave-Schutz)? Empfehlung: **separates Issue**, aber Reinit-Mechanismus so bauen, dass `profileId` später nur ein weiterer Trigger ist; Befund vorher im Browser bestätigen.
5. Mobile ebenfalls fixen? Empfehlung: eigenes Mobile-Issue (gleicher Defekt im `DashboardViewModel`), nicht in #372.
6. Brauchen wir für den Tageswechsel eine UI-Rückmeldung (z. B. kurzer Snackbar „Neuer Tag“)? Empfehlung: nein (neue i18n-Texte vermeiden); Anzeige springt still um.
7. Soll der 1-s-Tick bzw. `focus`/`pageshow` den Key zusätzlich abgleichen (Standby-Härtung)? Empfehlung: ja, `focus` + Abgleich im bestehenden Tick (kostet nichts).

## Entscheidungen zu den offenen Fragen (Hauptsession)

Alle Empfehlungen übernommen: (1) Ein laufender Timer läuft über Mitternacht weiter (kein automatisches Splitten); der Eintrag bleibt am Starttag, Soll/`isExtraDay`/Überstunden werden an das **Eintragsdatum** gekoppelt, nicht an ein frisches `new Date()`; Splitten bei Mitternacht ist ein eigenes Feature/Issue. (2) Ein gestoppter/leerer Eintrag wird nach Mitternacht still auf den neuen Tag umgeschaltet (ohne Dialog), zusätzlich prüfen alle Aktionen („Start", „Neue Session", Pausen, Autosave), dass das Eintragsdatum == heute ist, sonst erst auf den neuen Tag umschalten (verhindert `workStart=jetzt` im Eintrag des Vortags). (3) Neuer Core-`TodayService` (Key-Signal `YYYY-MM-DD`, Midnight-Timer bis lokale Mitternacht, benannter `visibilitychange`-/`focus`-/`pageshow`-Listener, Aufräumen über `DestroyRef`) für Dashboard und `holidayToday`; der Kalender-„heute" im Reports-Tab bleibt außerhalb (Folge-Issue). (4) Der Profilwechsel-Befund (Dashboard reagiert nicht auf Profilwechsel, Autosave kann ins neue Profil schreiben) wird ein eigenes Issue; der Reinit-Mechanismus wird aber erweiterbar gebaut (Generationszähler in `_init`). (5) Mobile-Dashboard (kein Tageswechsel-Handling) wird ein eigenes Mobile-Issue. (6) Kein UI-Hinweis beim Tageswechsel (keine neuen i18n-Texte). (7) Standby-Härtung: `focus` + Key-Abgleich im 1-s-Tick. Der anonyme Bestands-Listener (Z. ~146) wird als benannter, über `DestroyRef` aufgeräumter Listener umgebaut oder, falls redundant zum 1-s-Tick, entfernt (Entscheidung nach Test); `_timerSub` (ungenutzt) entfernen. Basis-Überstunden beim Reinit explizit aus dem Gespeicherten neu bestimmen. Tests: Fake-Timer, feste lokale Daten, `TZ=Europe/Berlin`, DST-Tage 2026-03-29/2026-10-25, laufender Timer über Mitternacht, Freitag→Samstag.
