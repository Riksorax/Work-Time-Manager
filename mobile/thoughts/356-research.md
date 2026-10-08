# Mobile-Research: #356 — german_holidays_test.dart schlägt unter TZ=Europe/Berlin fehl
Datum: 2026-10-03

## Aufgabe
`getGermanHolidays`/`getGermanHolidayNames` liefern in Zeitzonen mit Sommerzeit (Europa/Berlin) für
Jahre mit frühem Ostern falsche `DateTime`-Werte (Uhrzeit 01:00 statt 00:00). Tests (und der Kalender)
vergleichen per Datum-Gleichheit und schlagen fehl. Unter `TZ=UTC` (CI) grün.
Akzeptanz: (1) reproduzieren, (2) Kalenderarithmetik statt Duration-Addition in `german_holidays.dart`,
(3) Tests zeitzonenunabhängig (Regel in `CLAUDE.md`).
Nicht Teil: Feiertagslogik inhaltlich ändern, Web/Backend.

## Reproduktion (ausgeführt)
- `TZ=Europe/Berlin flutter test test/domain/utils/german_holidays_test.dart` -> 5 grün, **3 rot**.
- `TZ=UTC` -> 8/8 grün. `TZ=America/New_York` -> grün (ganzes `test/domain/utils/`).

Fehlschläge (alle Jahr 2024, Ostersonntag = 31.03.2024 = Tag der Zeitumstellung 02:00 -> 03:00):
| Test (Zeile) | erwartet | tatsächlich |
|---|---|---|
| "enthält alle 9 bundesweiten Feiertage 2024" (l.13) | `2024-04-01 00:00` (Ostermontag) | `2024-04-01 01:00` |
| (gleicher Test, würde nach Fix der ersten expect weiter scheitern) | `2024-05-09 00:00` Himmelfahrt, `2024-05-20 00:00` Pfingstmontag | `01:00` |
| "Bayern ..." (l.40) | `2024-05-30 00:00` (Fronleichnam) | `2024-05-30 01:00` |
| "Nordrhein-Westfalen ..." (l.51) | `2024-05-30 00:00` | `2024-05-30 01:00` |
Karfreitag (`-2 Tage`, 29.03.) bleibt korrekt (liegt vor der Umstellung). Der 2025er-Test ist grün
(Ostern 20.04. liegt nach der Umstellung, alle Offsets bleiben nach Ostern in CEST).

## Ursache
`_calculateEasterSunday` liefert lokale Mitternacht `DateTime(year, m, d)`. `easter.add(const
Duration(days: N))` addiert N*24 absolute Stunden. Liegt die Zeitumstellung (letzter März-Sonntag)
zwischen Ostern und Zieldatum — oder ist Ostern selbst der Umstellungstag (2024) —, landet das Ergebnis
auf 01:00 statt 00:00. Die Map-Keys sind dann keine "reinen Datums"-DateTimes mehr, `==`/`contains`/
`Map[]` gegen `DateTime(y,m,d)` schlagen fehl. Betroffen: alle Jahre mit Ostern <= Umstellungssonntag
(u. a. 2008, 2013, 2016, 2024, 2027, 2035). Betroffene Feiertage: Ostermontag, Himmelfahrt, Pfingstmontag,
Fronleichnam (alle `easter.add`). `subtract` im Karfreitag und `_bussUndBettag` (22.11. rückwärts, ohne
DST-Übergang, Umstellung im Okt. liegt davor) sind in Praxis nicht betroffen, sollten aber mitgezogen werden.
Bei Ostern im Oktober gäbe es keinen Fall; `difference().inDays` kommt in `german_holidays.dart` nicht vor.

**Echte Auswirkung in der App:** `reports_page.dart` l.1987-2136 matcht `holidays.contains(DateTime(date.year,
date.month, date.day))` und `holidayNames[...]`. Für deutsche Nutzer (TZ Europe/Berlin) fehlt in diesen
Jahren die rote Markierung/der Name von Ostermontag, Christi Himmelfahrt, Pfingstmontag (und Fronleichnam
in BW/BY/HE/NW/RP/SL). Nächstes betroffenes Jahr: 2027 (Ostern 28.03.).

## Korrektur-Skizze (kein Code geschrieben)
In `german_holidays.dart` nur Kalenderfelder verwenden: `DateTime(easter.year, easter.month, easter.day + N)`
(Dart normalisiert Überlauf) — ein kleiner Helfer `_addDays(DateTime d, int n)`. Gilt für Karfreitag (-2), +1,
+39, +50, +60 und die while-Schleife in `_bussUndBettag` (-1). Test: Ostern +N muss `DateTime(y,m,d)` exakt
entsprechen; zusätzlich Zeitzonen-Robustheit (siehe Testfrage unten).

## Weitere Stellen in `mobile/lib/` mit demselben Fehlertyp
Geprüft per grep (`Duration(days`, `inDays`):
| Stelle | Befund |
|---|---|
| `domain/utils/insights_utils.dart:153` `day.add(Duration(days:1))` in `detectOvertimeStreak`; Lookup `overTargetDays.contains(day)` (Mitternachts-Keys) | **Betroffen**: nach Frühjahrs-Umstellung 01:00, nach Herbst-Umstellung 23:00 des Vortags -> `contains` schlägt fehl, Streak-/Burnout-Warnung (#134) falsch bei Zeiträumen über eine Umstellung. Auch weekday kann abweichen (23:00 Vortag). |
| `presentation/screens/reports_page.dart:1889` `_selectDateRange` (`currentDate.add(1 Tag)`, dann `addDateToSelection`) | **Betroffen**: Mehrfachauswahl über Umstellung enthält Nicht-Mitternachts-Daten; Abgleich mit `DateTime(y,m,d)` (l.2128) schlägt fehl, Tage ggf. nicht markiert/doppelt. |
| `reports_page.dart:716/744` `startOfWeek ±7 Tage` -> `selectDate(...)` | Betroffen leicht: Datum mit 01:00 statt 00:00 als `selectedDay` (Wochenvor/-zurück über die Umstellung). Folgeeffekte gering (danach meist normalisiert), aber unsauber. |
| `reports_page.dart:699`, `reports_view_model.dart:311-312`, `overtime_utils.dart:44-45` (`subtract(weekday-1)`, `+6 Tage`) | Praktisch unkritisch: Umstellung ist Sonntag 02:00/03:00, Mo 00:00 + 6 Tage = So 01:00 (Frühjahr) bzw. So 00:00 (Herbst); Vergleich über `!isAfter(endOfWeek)` bleibt korrekt. Kalenderarithmetik trotzdem sauberer. |
| `dashboard_view_model.dart:121` `today.subtract(weekday-1)` | Wie oben: Montag-00:00 minus Tage, Umstellung nur sonntags -> in Praxis ok; nur Monat/Jahr genutzt. |
| `core/services/notification_service.dart:176-181` `TZDateTime.add(1 Tag / 7 Tage)` | Prüfen: `timezone` addiert absolut; über Umstellung kann die Uhrzeit um 1 h verschoben sein, und `matchDateTimeComponents: dayOfWeekAndTime` (l.230) würde die verschobene Uhrzeit wiederkehrend übernehmen. Eigenes Issue empfohlen, nicht in #356 vermischen. |
| `domain/utils/iso_week.dart` | **Sauber**: rechnet in UTC mit Kalenderfeldern (Vorbild: Kommentar im File). |
| Tests `dashboard_view_model_test.dart`, `reports_view_model_test.dart` (`DateTime.now() ± Duration(days)`) | Nutzen `DateTime.now()` (Verstoß gegen "Tests nicht datumsabhängig", nicht Gegenstand von #356); nicht TZ-Bug im Sinne des Issues. |
Full `flutter test test/domain/utils/` unter Berlin: nur die 3 Holiday-Tests rot, d. h. insights/overtime-Tests
decken die DST-Fälle nicht ab (keine roten Tests, aber latente Bugs).

## Web / Backend
- `web/src` und `server/src`: **keine** Feiertagsberechnung (grep nach easter/ostern/holiday/getGermanHoliday
  liefert nur `holiday` als WorkEntryType in Report-Rechnung). Nicht betroffen, nur Mobile.
- Web hat den gleichen Fehlertyp ggf. an anderen Stellen (nicht geprüft, außerhalb Scope).

## Datenfluss
Settings (`bundesland`) -> `reports_page.dart` Kalender-Widget -> `getGermanHolidayNames(year, bundesland)`
(reine Domain-Funktion, kein ViewModel/Repository/Firestore) -> Set/Map-Lookup per `DateTime(y,m,d)`.
Kein Firestore-Pfad, keine Security Rule, kein Backend-Feld, kein Premium-Bezug, keine ARB-Texte
(Feiertagsnamen sind hart kodiert deutsch, bestehender Zustand), kein build_runner nötig.

## Offene Fragen
1. Umfang: Nur `german_holidays.dart` + Test fixen (so das Issue), oder die latenten Bugs in
   `insights_utils.dart` und `reports_page._selectDateRange` im selben PR mitnehmen?
   Empfehlung: `german_holidays.dart` + eigene Tests in #356; `insights_utils` und `_selectDateRange`
   (echte Fehler, gleicher Typ) als kleinen Zusatz im PR, wenn Aufwand klein, sonst Folge-Issue; Notification-Thema separates Issue.
2. Testabsicherung: Tests sollen TZ-unabhängig sein. Da `flutter test` die Prozess-TZ nicht pro Test setzen kann,
   Vorschlag: Regressions-Assertion, dass **jeder** Rückgabe-DateTime Mitternacht ist
   (`hour==0 && minute==0`) und `isUtc == false`, plus Jahre mit frühem Ostern (2024, 2027, 2008) mit festen
   erwarteten Datumswerten. Unter UTC würde der Mitternachts-Test den Bug nicht fangen -> optional CI-Schritt
   `TZ=Europe/Berlin flutter test` (neuer Job-Schritt in `ci.yml`)? Entscheidung Hauptsession/Owner.
3. Soll `getGermanHolidays` künftig reine Datums-DateTimes garantiert als Vertrag dokumentieren (Doc-Kommentar)? Empfehlung ja.

## Risiken
- Dart-`DateTime(y, m, d + N)` normalisiert Überläufe zuverlässig; Änderung ist risikoarm, Ergebnisse unter UTC unverändert.
- Ohne TZ-Lauf in CI bleibt die Klasse von Fehlern unsichtbar (CI = UTC) -> Regression möglich.
- Scope-Creep bei Fix der weiteren Fundstellen (Streak-Tests brauchen TZ-Setup, ebenfalls nicht von CI abgedeckt).

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. **Scope:** #356 umfasst `german_holidays.dart` (alle `Duration`-Additionen/-Subtraktionen auf Kalenderarithmetik `DateTime(y, m, d + N)` bzw. `_addDays`-Helfer umstellen, inkl. `_bussUndBettag`) plus Tests. `insights_utils.dart:153`, `reports_page.dart:1889`/Woche ±7 und `notification_service.dart:176-181` kommen in ein eigenes Folge-Issue (nicht in diesen PR).
2. **Testabsicherung:** Feste Erwartungen für Jahre mit frühem Ostern (2024, 2027, 2008) und Assertion „alle Schlüssel sind lokale Mitternacht, nicht UTC". Da die CI unter UTC läuft und den Fehler nicht sieht, zusätzlich ein CI-Schritt in `.github/workflows/ci.yml`, der `test/domain/utils` mit `TZ=Europe/Berlin` ausführt (nur nach lokalem Nachweis, dass er grün ist).
3. **Vertrag im Doc-Kommentar:** „liefert reine Datums-DateTimes (lokale Mitternacht)" in `german_holidays.dart` festhalten.
