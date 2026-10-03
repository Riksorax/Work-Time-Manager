# Mobile-Research: #362 — Datumsarithmetik über die Zeitumstellung
Datum: 2026-10-03

## Aufgabe
Folge-Issue zu #356. `Duration(days: N)`-Addition/-Subtraktion (und `TZDateTime.add`) rechnet in
24-Stunden-Blöcken. Über die Zeitumstellung landet das Ergebnis auf 01:00 (Frühjahr) bzw. 23:00 des
Vortags (Herbst) statt 00:00. Betroffen laut Issue: `insights_utils.detectOvertimeStreak`, Datumsbereich und
Wochennavigation in `reports_page.dart`, `notification_service.dart`. Fix: Kalenderarithmetik
`DateTime(y, m, d + N)`; Tests mit festen Daten um die Umstellung, zuerst rot unter `TZ=Europe/Berlin`.
Nicht Teil: Web/Backend, reine Dauer-Rechnung (`difference`, Arbeitszeiten), Feiertage (erledigt in #356).
Ausgangslage Code: `german_holidays.dart` hat `_addDays(d, n) => DateTime(d.year, d.month, d.day + n)`;
`iso_week.dart` rechnet in UTC mit Kalenderfeldern (sauber). CI: `ci.yml` Z. 51 führt
`TZ=Europe/Berlin flutter test test/domain/utils` aus.

## Reproduktion (ausgeführt, TZ=Europe/Berlin, temporäre Skripte/Tests, wieder gelöscht, Repo sauber)
Rohverhalten `DateTime.add/subtract(Duration(days))` (lokale Mitternacht als Start):
| Start | Operation | Ergebnis (Berlin) |
|---|---|---|
| 30.03.2025 00:00 (Umstellung) | +1 Tag | 31.03.2025 **01:00** |
| 31.03.2024 00:00 | +1 Tag | 01.04.2024 **01:00** |
| 29.03.2025 00:00 | +7 Tage | 05.04.2025 **01:00** |
| 26.10.2025 00:00 (Umstellung) | +1 Tag | 26.10.2025 **23:00** (selber Tag!) |
| 27.10.2024 00:00 | +1 Tag | 27.10.2024 **23:00** (selber Tag!) |
| 25.10.2025 00:00 | +7 Tage | 31.10.2025 **23:00** |
| 31.03.2025 (Mo) | −7 Tage | 23.03.2025 **23:00** (Vorwoche, Sonntag!) |
| 27.10.2025 (Mo) | −7 Tage | 20.10.2025 **01:00** |
Unter UTC sind alle Ergebnisse exakt Mitternacht (daher in CI unsichtbar).

## Befund je Fundstelle

### 1. `insights_utils.dart:151-153` `detectOvertimeStreak` — ECHTER FEHLER, hoch
Ursache: Die Schleife `day = day.add(Duration(days: 1))` startet auf Mitternacht (`minDate`), wird nach
der Umstellung aber 01:00 (Frühjahr) bzw. 23:00 (Herbst). `overTargetDays.contains(day)` (Keys sind
Mitternacht) schlägt für **jeden** Tag nach der Umstellung fehl. Zusätzlich im Herbst: der Umstellungs-
sonntag wird doppelt besucht (00:00 und 23:00), und der letzte Tag fällt über `!day.isAfter(maxDate)` weg.
Gemessen (3 Monate Insights-Zeitraum, `insights_view_model.dart:19` `_monthCount = 3`, d. h. der Zeitraum
überspannt in rund jedem zweiten Monat eine Umstellung):
| Eingabe (alle Tage Mo-Fr jeweils 9 h bei Soll 8 h) | UTC currentStreak/longest | Berlin |
|---|---|---|
| 24.03.-04.04.2025 (Frühjahr) | 10 / 10 | **0 / 5** |
| 25.03.-05.04.2024 (31.03.2024) | 10 / 10 | **0 / 5** |
| 20.10.-31.10.2025 (Herbst) | 10 / 10 | **0 / 5** |
| 21.10.-01.11.2024 (27.10.2024) | 10 / 10 | **0 / 5** |
| 22.-30.10.2025, alle 7 Wochentage Arbeitstag | 9 / 9 | **0 / 5** |
Folge: Burnout-Warnung (#134, Schwelle 5 Tage) wird fälschlich unterdrückt oder zu früh abgeschnitten, sobald
der Zeitraum eine Umstellung enthält.
Fix: `for (var day = minDate; !day.isAfter(maxDate); day = DateTime(day.year, day.month, day.day + 1))`.
Alternativ `_addDays`-Helfer (siehe Frage 2).

### 2. `reports_page.dart:1869-1890` `_selectDateRange` — ECHTER FEHLER, mittel
Ursache: gleiche Schleife `currentDate.add(Duration(days: 1))` auf Mitternachts-Start. Die Auswahl selbst
bleibt konsistent, weil `addDateToSelection` (`reports_view_model.dart:490`) auf `DateTime(y,m,d)`
normalisiert, auch der Wochentag (`_isWorkday`) stimmt (01:00/23:00 liegen am richtigen Kalendertag, außer
dem doppelt besuchten Sonntag, harmlos dank Set). Der Fehler liegt an der Abbruchbedingung:
`!currentDate.isAfter(maxDate)` — `maxDate` ist Mitternacht, `currentDate` 01:00/23:00 des Endtags, also
**der letzte Tag des Bereichs fehlt** in der Mehrfachauswahl, sobald der Bereich die Umstellung überspannt
und der Endtag nach dem Umstellungstag liegt. Beispiele: 24.10.-28.10.2025 liefert 24, 25, 26, 27 (28.10. fehlt);
28.03.-01.04.2025 liefert 28, 29, 30, 31 (01.04. fehlt). Endtag = Umstellungstag selbst ist korrekt.
Fix: `currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day + 1)`.
Hinweis: Umstellungs-Fall ist selten genug, dass kein Nutzerbericht vorliegt, aber reproduzierbar.

### 3. `reports_page.dart:716 / 744` Wochennavigation ±7 — ECHTER FEHLER, hoch (Navigation klemmt/überspringt)
Ursache: `startOfWeek` (Mo 00:00) ± `Duration(days: 7)` wird an `selectDate` gegeben; Z. 697 berechnet dann
die Woche aus `selectedDay` neu per Kalenderfeldern. Das Ergebnis ist nur korrekt, wenn die Verschiebung auf
dem richtigen Kalendertag landet. Gemessen:
- Herbst, vorwärts: Mo 20.10.2025 + 7 Tage = **So 26.10.2025 23:00** -> gleiche Woche wie vorher
  (Mo 20.10.). Der Pfeil „nächste Woche" **bewirkt nichts**, Nutzer kann die Umstellungswoche nicht per Pfeil
  verlassen. Gleiches für 21.10.2024 -> 27.10.2024 23:00. Rückwärts aus 27.10. -> 20.10. 01:00, korrekt.
- Frühjahr, rückwärts: Mo 31.03.2025 − 7 Tage = **So 23.03.2025 23:00** -> Woche 17.03.; die Woche 24.03.
  wird **übersprungen** (analog 01.04.2024 -> 24.03.2024 23:00 -> Woche 18.03.). Vorwärts aus Mo 24.03.:
  31.03. 01:00, richtige Woche.
Fix: `selectDate(DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day ± 7))`.
Kalenderarithmetik. `selectDate` im ViewModel normalisiert selbst nicht; zusätzlich Mitternachts-
Normalisierung am Eingang von `selectDate` wäre Härtung (Frage 3).
`reports_page.dart:699` `startOfWeek.add(Duration(days: 6))`: nur für die Anzeige (`DateFormat.MMMd`),
Frühjahrswoche liefert So 01:00 (gleicher Kalendertag), Herbstwoche So 00:00: **kein sichtbarer Fehler**,
dennoch sauberer auf Kalenderarithmetik.

### 4. `notification_service.dart:164-182` `_scheduleWeeklyNotification` — ECHTER FEHLER, niedrig/mittel
Ursache: `tz.TZDateTime.add(Duration(days: n))` addiert absolute Zeit (timezone 0.10.1 gemessen).
Ausgangswert ist `TZDateTime(tz.local, today, hour, minute)`; liegt die Umstellung zwischen heute und dem Ziel-
termin (maximal 13 Tage Vorlauf: Schleife <= 6 Tage, dann +7), kippt die Uhrzeit.
Gemessen (Berlin, Erinnerung 08:00):
| Jetzt / Ziel | Ergebnis |
|---|---|
| Fr 28.03.2025, Ziel So | So 30.03.2025 **09:00** statt 08:00 (Termin ist der Umstellungstag selbst, liegt nach 03:00) |
| Sa 29.03.2025, Ziel Mo | Mo 31.03.2025 **09:00** |
| Mo 24.03.2025, +7 | Mo 31.03.2025 **09:00** |
| Fr 24.10.2025, Ziel Di | Di 28.10.2025 **07:00** |
| Mo 20.10.2025, +7 | Mo 27.10.2025 **07:00** |
Wirkung: Der Plugin-Aufruf nutzt `matchDateTimeComponents: dayOfWeekAndTime` (Z. 230), die falsche Uhrzeit
wird wöchentlich wiederkehrend übernommen. Abmilderung: `main.dart:134` plant bei jedem App-Start neu, und
Settings-Änderungen planen ebenfalls neu (`settings_view_model.dart:464`, `notification_settings_dialog.dart:144`).
Der Fehler hält also bis zum nächsten App-Start; bei Nutzern, die die App selten öffnen, kann die Erinnerung
mehrere Wochen eine Stunde zu früh/spät kommen. Betrifft Plan-Fenster von ca. 2 Wochen je Umstellung (4 pro Jahr).
Fix (Kalenderfelder in `tz.local`, kein `.add`): Tagesdifferenz `delta = (day - now.weekday + 7) % 7`;
`scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day + delta, hour, minute)`;
wenn `scheduled.isBefore(now)`: `tz.TZDateTime(tz.local, scheduled.year, scheduled.month, scheduled.day + 7, hour, minute)`.
`TZDateTime(...)` normalisiert Überlauf wie `DateTime`. Der `while`-Loop entfällt.
Testbarkeit: `now` ist fest `tz.TZDateTime.now(tz.local)`, nicht injizierbar; der Test
`notification_service_test.dart` setzt `tz.local` auf UTC. Für feste Testdaten Berechnung in eine
reine, testbare Funktion auslagern (z. B. `nextWeeklyOccurrence(tz.TZDateTime now, int day, int hour, int minute)`) oder
optionaler `now`-Parameter. Test kann `tz.setLocalLocation('Europe/Berlin')` selbst setzen (unabhängig von der
Prozess-TZ, da `TZDateTime` nur die Location nutzt), braucht also **keinen** TZ-CI-Schritt.

## Weitere Fundstellen (grep: `.add(Duration/const Duration(days`, `.subtract(…days`, `difference(`, `inDays`, `days:`)
| Stelle | Bewertung |
|---|---|
| `overtime_utils.dart:44-45` `normalizedDate.subtract(weekday-1)`, `+6` | Kein Fehler (Begründung unten): Vergleich nur über `isBefore/isAfter` gegen Entry-Mitternacht. |
| `reports_view_model.dart:311-312` `reportDate.subtract(weekday-1)`, `+6` | Kein Fehler, gleiche Begründung (Wochenbericht). |
| `dashboard_view_model.dart:121` `today.subtract(weekday-1)` | Gleiche Mechanik, aber nur `startOfWeek.month`/`year` genutzt (Z. 127ff.) -> praktisch folgenlos, Korrektur trotzdem mitnehmen. |
| `reports_page.dart:699` `startOfWeek.add(6)` | Nur Anzeige (siehe oben), kein Fehler. |
| `iso_week.dart:10` `thursday.difference(jan1).inDays` | Sauber (beide UTC). |
| `difference(` an Arbeits-/Pausenzeiten (`insights_utils:67`, `work_entry_extensions:14`, `work_entry_entity:48`, `break_entity:21`, `dashboard_*`, `reports_page` 249/252/467/472/2456/2459, Modals) | Reine Dauern zwischen zwei Zeitpunkten, absolute Zeit ist hier fachlich gewollt (echte verstrichene Zeit, Nachtschicht über Umstellung ist 1 h länger/kürzer). **Kein Fehler.** |
| `Duration(hours: 24)` / `inDays` sonst | Keine weiteren Treffer in `mobile/lib`. |
| Tests mit `DateTime.now() ± Duration(days)` | Datumsabhängig (Verstoß gegen CLAUDE.md-Regel), nicht Teil von #362. |

Begründung Wochenberechnung `subtract(weekday-1)` / `+6` (bestätigt die Einstufung aus #356 und dem Issue): Eine
Mo-So-Woche enthält die Umstellung immer erst am Sonntag um 02:00/03:00. Alle Mitternachts-Werte der Woche
(Mo 00:00 bis So 00:00) liegen im selben UTC-Offset. Beispiele Berlin: So 30.03.2025 00:00 minus 6 Tage = Mo 24.03.
00:00; Mo 24.03. plus 6 Tage = So 30.03. 00:00; Herbst Mo 20.10.2025 plus 6 Tage = So 26.10. 00:00. Der Fehler tritt
erst bei Verschiebungen **über** den Umstellungssonntag hinaus auf (±7 Tage, +1 Tag auf Sonntag), also nicht hier.
Härtung auf Kalenderarithmetik bleibt optional (Frage 5). Merke: die gemessene Tabelle oben für ±7 gilt nur für
Verschiebung um eine Woche.

## Datenfluss
Insights: `InsightsScreen` -> `InsightsViewModel.load` (3 Monate) -> `workRepository.getWorkEntriesForMonth` ->
`detectOvertimeStreak` (reine Domain-Funktion). Berichte: `ReportsPage` -> `ReportsViewModel.selectDate/
addDateToSelection` (State `selectedDay`, `selectedDates`). Benachrichtigung: `main.dart`/Settings ->
`NotificationService.scheduleDailyReminder` -> `_scheduleWeeklyNotification` -> `flutter_local_notifications.zonedSchedule`.
Keine Firestore-Pfade, keine Security Rules, kein Backend-Feld, kein Premium-Bezug, keine ARB-Texte,
kein build_runner.

## Plattformübergreifend
Nur Mobile. Web: `calendar.ts:293` nutzt `setDate(getDate()+1)` (kalenderbasiert, korrekt), `iso-week.util.ts`
rechnet mit UTC-Millisekunden (analog sauber). Backend: `AddDays` auf Datumstypen (kein Zeitzonenproblem).
Keine Fundstellen, keine Aktion nötig.

## Testbarkeit
- Gesamte Suite läuft lokal unter `TZ=Europe/Berlin flutter test` in rund 51 s und ist **heute grün**
  (die Fehler sind nicht abgedeckt, also latent). Die bestehende CI-Zeile (`test/domain/utils`) deckt
  `insights_utils` ab, daher ist für Fix 1 **kein CI-Schritt nötig**.
- Presentation: `reports_page`-Datumsbereich und Wochennavigation sind private Methoden/Lambdas im Widget. Tests
  über Widget-Test (`reports_page_widget_test.dart`) bräuchten Berlin-TZ im Prozess. Empfehlung: Logik in reine
  Domain-Funktionen extrahieren (z. B. `domain/utils/date_utils.dart`: `addCalendarDays(DateTime, int)`,
  `datesInRange(start, end)`, `shiftWeek(DateTime, int weeks)`), die unter dem vorhandenen CI-Schritt laufen.
  Widget-Tests müssen dann nur noch verdrahten.
- CI-Option A (empfohlen, minimal): Schritt in `ci.yml` von `test/domain/utils` auf ganzes `flutter test`
  unter Berlin erweitern, oder zweiten Lauf `TZ=Europe/Berlin flutter test test/domain test/presentation test/core`
  anfügen (+~50 s Laufzeit, Suite läuft heute grün). Option B: beim Domain-Ordner bleiben (Logik extrahieren).
- Alternativ in Tests selbst unabhängig von der Prozess-TZ: `DateTime` lässt sich in Dart nicht pro Test auf eine
  Zone setzen (nur `TZDateTime`/`tz.Location`). Für den Notification-Fall reicht `TZDateTime` mit Location Berlin,
  für `DateTime`-Fälle ist der Prozess-TZ-Lauf nötig.
- Testdaten (fest): 29./30.03.2025, 26./27.10.2025, 31.03.2024, 27.10.2024. Erwartungen: Streak über beide Umstellungen
  = Anzahl Arbeitstage (10, nicht 0); `_selectDateRange` 24.-28.10.2025 enthält 28.10. und liefert 5 Tage;
  Woche vorwärts von Mo 20.10.2025 = Mo 27.10.2025, rückwärts von Mo 31.03.2025 = Mo 24.03.2025; Erinnerung
  Fr 28.03.2025 -> So 30.03.2025 08:00 (Offset +02:00), Fr 24.10.2025 -> Di 28.10.2025 08:00.
  Regressionstest „alle Ergebnisse sind lokale Mitternacht" ist unter UTC wirkungslos, deshalb TZ-Lauf nötig.

## Offene Fragen (mit Empfehlung)
1. Scope: Alle vier Fundstellen in einem PR oder Notification getrennt? Empfehlung: ein PR, aber Commit/Test je
   Fundstelle (insights, reports_page, notification); der Notification-Fix ist klein und klar. Wenn die
   Notification-Berechnung in eine Funktion ausgelagert wird, getrennter Commit.
2. Gemeinsamer Helfer: `_addDays` ist privat in `german_holidays.dart`. Empfehlung: ein öffentlicher Helfer
   `addCalendarDays(DateTime, int)` in `domain/utils/date_utils.dart`, `german_holidays.dart` darauf umstellen
   (bleibt unter dem CI-TZ-Lauf), alle neuen Stellen nutzen ihn. Alternativ jeweils inline `DateTime(y, m, d + N)`.
3. Soll `ReportsViewModel.selectDate` am Eingang auf Mitternacht normalisieren (Härtung gegen weitere Aufrufer)?
   Empfehlung: ja, ein Einzeiler plus Test.
4. CI: Schritt auf die ganze Suite unter Berlin erweitern (Option A) oder auf Domain beschränken (Option B)?
   Empfehlung: Option A, ersetzt den bisherigen Domain-Schritt (volle Suite grün, +ca. 50 s), da
   Presentation-Logik (Wochennavigation) sonst ungetestet bleibt; falls Laufzeit/Flakiness (DateTime.now-Tests)
   ein Problem wird, Option B mit Extraktion.
5. Wochenstart `subtract(weekday-1)`/`+6` an drei Stellen mitumstellen (Härtung ohne Befund)? Empfehlung: ja
   (billig, via Helfer), aber ohne eigene Tests, die nur Mitternacht-Gleichheit prüfen.
6. Notification: Zusätzlich ein Hinweis/Nachplan nach DST (z. B. Neuplanung beim App-Start passiert bereits)?
   Empfehlung: nein, Fix der Berechnung genügt.

## Risiken
- `DateTime(y, m, d + N)` normalisiert Überläufe zuverlässig; unter UTC unverändertes Verhalten.
- Notification: Schleife durch Delta-Formel ersetzen ändert die Semantik nicht (gleicher Ziel-Wochentag, gleiche
  „heute schon vorbei -> nächste Woche"-Regel); Grenzfall „gleicher Wochentag, Zeit noch offen" muss getestet werden.
- Wochennavigation: Aufrufer von `selectDate` mit anderen Uhrzeiten (z. B. `DateTime.now()`) bleiben unverändert.
- `_selectDateRange`-Fix kann Mehrfachauswahl-Verhalten über Umstellung ändern (Endtag jetzt enthalten), gewollt.
- Datumsabhängige Bestandstests (`DateTime.now()`) könnten unter dem erweiterten CI-Lauf zeitabhängig flackern.

## Entscheidungen zu den offenen Fragen (Hauptsession)

Alle Empfehlungen übernommen: (1) alle vier Fundstellen in einem PR, je Fundstelle ein Test (zuerst rot unter TZ=Europe/Berlin); (2) öffentlicher Helfer `addCalendarDays` in `domain/utils`, `german_holidays.dart` `_addDays` darauf umstellen; (3) `ReportsViewModel.selectDate` normalisiert am Eingang auf lokale Mitternacht; (4) Option A: CI führt die ganze Flutter-Suite unter `TZ=Europe/Berlin` aus (ersetzt den Schritt `test/domain/utils` aus #363, der normale UTC-Lauf bleibt), nur nach lokalem Nachweis, dass die ganze Suite unter Berlin mehrfach grün ist (Flackern durch `DateTime.now()`-Tests prüfen); (5) Wochenstart-Stellen ohne Befund (overtime_utils, reports_view_model, dashboard_view_model) werden als Härtung auf `addCalendarDays` umgestellt, ohne eigene Tests; (6) Notification: Berechnungs-Fix in eine reine Funktion mit injizierbarem `now` auslagern, Test setzt `tz.local` auf Berlin, keine zusätzliche Neuplanung nach der Umstellung.
