# Mobile-Plan: #356 — german_holidays unter TZ=Europe/Berlin korrekt (Kalenderarithmetik)
Research: mobile/thoughts/356-research.md (inkl. "Entscheidungen zu den offenen Fragen")

## Ziel
`getGermanHolidays`/`getGermanHolidayNames` liefern in DST-Zeitzonen immer reine Datums-DateTimes (lokale Mitternacht),
indem `Duration`-Addition durch Kalenderarithmetik ersetzt wird. Die Tests sichern das ab, und die CI führt
`test/domain/utils` zusätzlich unter `TZ=Europe/Berlin` aus.

## Architektur-Entscheidungen
| Frage | Entscheidung | Begründung |
|---|---|---|
| Neue Entity / Feld? | Nein | Reine Domain-Utility-Korrektur |
| Repository-Interface ändern? | Nein | Kein Repository beteiligt (Hybrid/Firebase/Local/ApiDataSource unberührt) |
| Neuer Provider? | Nein, kein build_runner | Keine DI-Änderung |
| Premium-Gate? | Nein | Kein Feature-Bezug |
| Pro Arbeitszeit-Profil? | Nein | Keine profileId-Daten |
| Backend-Änderung nötig? | Nein | Backend/Web haben keine Feiertagsberechnung |
| Neue Texte? | Nein | Keine ARB-Keys; kein `flutter gen-l10n` |
| Fix-Technik | Privater Helfer `_addDays(DateTime d, int n)` = `DateTime(d.year, d.month, d.day + n)`; ersetzt jedes `add`/`subtract` mit `Duration` (Karfreitag -2, +1, +39, +50, +60, while-Schleife in `_bussUndBettag`) | Dart normalisiert Überlauf, unabhängig von DST; unter UTC identische Ergebnisse |
| Vertrag | Doc-Kommentar an `getGermanHolidays`/`getGermanHolidayNames`: "reine Datums-DateTimes (lokale Mitternacht, nicht UTC)" | Entscheidung 3 |
| Test-Absicherung | Feste Erwartungswerte für 2024, 2027, 2008 + Assertion "alle Schlüssel Mitternacht und `isUtc == false`"; zusätzlich CI-Schritt mit `TZ=Europe/Berlin` | Entscheidung 2: CI läuft sonst unter UTC und sieht den Fehler nicht |
| Scope | Nur `german_holidays.dart` + Test + `ci.yml`. NICHT: `insights_utils.dart:153`, `reports_page.dart` (`_selectDateRange`, Woche ±7), `notification_service.dart` | Entscheidung 1: Folge-Issue |
| Tests datum-/TZ-unabhängig | Nur feste Jahre/Daten, kein `DateTime.now()`, keine Prozess-TZ-Annahme im Testcode | Die Assertions gelten unter jeder TZ; die Bug-Sichtbarkeit kommt über die Prozess-TZ des Laufs (CI-Schritt) |

## Dateien
| Datei | neu/geändert | Zweck |
|---|---|---|
| `mobile/test/domain/utils/german_holidays_test.dart` | geändert | Neue Regressionstests (2024/2027/2008 fest, Mitternachts-Assertion, Namen-Map-Keys); bestehende Tests bleiben unverändert |
| `mobile/lib/domain/utils/german_holidays.dart` | geändert | `_addDays`-Helfer, alle Duration-Arithmetik ersetzen, Doc-Kommentar-Vertrag |
| `.github/workflows/ci.yml` | geändert | Zusätzlicher Schritt `TZ=Europe/Berlin flutter test test/domain/utils` im Job `flutter` (working-directory `./mobile`), direkt nach dem Schritt "Test" |

Nicht betroffen: data/, core/providers/, presentation/, l10n/, `*.g.dart`, `*.mocks.dart`.

## Schritte (TDD)

### Schritt 1: Domain — Tests zuerst (rot unter Berlin)
- [x] Test in `mobile/test/domain/utils/german_holidays_test.dart`, neue Gruppe "getGermanHolidays - Zeitumstellung (DST)":
  - Feste Referenz Ostern: 2024-03-31 (Ostern = Umstellungstag), 2027-03-28, 2008-03-23. Erwartet jeweils als `DateTime(y,m,d)`:
    - 2024: Karfreitag 03-29, Ostermontag 04-01, Himmelfahrt 05-09, Pfingstmontag 05-20, Fronleichnam 05-30 (Bundesland mit Fronleichnam, z. B. Bayern)
    - 2027: Karfreitag 03-26, Ostermontag 03-29, Himmelfahrt 05-06, Pfingstmontag 05-17, Fronleichnam 05-27
    - 2008: Karfreitag 03-21, Ostermontag 03-24, Himmelfahrt 05-01, Pfingstmontag 05-12, Fronleichnam 05-22
  - Test "alle Rückgabe-DateTimes sind lokale Mitternacht": für Jahre 2008, 2013, 2016, 2024, 2025, 2027, 2035 und Bundesländer Bayern + Sachsen (deckt Fronleichnam und Buß- und Bettag) jeweils `hour == 0`, `minute == 0`, `second == 0`, `millisecond == 0`, `isUtc == false`.
  - Test `getGermanHolidayNames` (2024/2027, Bayern): Schlüssel von Ostermontag/Himmelfahrt/Pfingstmontag/Fronleichnam sind per `containsKey(DateTime(y,m,d))` auffindbar; Namen nicht leer. (Konkrete Namen erst nach Lesen der Implementierung in Schritt 2 ergänzen; nicht neu erfinden.)
  - Kein `DateTime.now()`, keine TZ-Annahme im Testcode.
- [x] Nachweis rot: `cd mobile && TZ=Europe/Berlin flutter test test/domain/utils/german_holidays_test.dart` -> rot (bestehende 3 + neue). Zusätzlich `TZ=UTC` -> grün (Tests prüfen unter UTC nur das ohnehin korrekte Verhalten).
- [x] Impl in `mobile/lib/domain/utils/german_holidays.dart`: Datei lesen, Helfer `_addDays` ergänzen, alle `easter.add/subtract(Duration)` und die Schleife in `_bussUndBettag` darauf umstellen, Doc-Kommentar zum Vertrag. Keine inhaltliche Änderung der Feiertagslogik, keine Nebenbei-Refactorings.
- [x] Nachweis grün: `TZ=Europe/Berlin`, `TZ=UTC`, `TZ=America/New_York` jeweils `flutter test test/domain/utils/`.

### Schritt 2: Data — entfällt
Keine Repository-/Model-Änderung.

### Schritt 3: Provider — entfällt
Keine Verdrahtung, kein build_runner.

### Schritt 4: Presentation — entfällt
`reports_page.dart` nutzt die Funktion unverändert; Auswirkung nur indirekt (Markierung von Ostermontag etc. in DST-Jahren wird korrekt). Kein UI-Code-Change; keine Widget-Tests nötig.

### Schritt 5: Texte — entfällt
Keine ARB-Keys.

### Schritt 6: CI-Absicherung (Voraussetzung: Schritt 1 lokal unter Berlin grün)
- [x] `.github/workflows/ci.yml`: Schritt nach "Test" im Job `flutter`:
  Name z. B. "Test (TZ=Europe/Berlin, Domain-Utils)", `run: TZ=Europe/Berlin flutter test test/domain/utils` (Bash-Env-Präfix, ubuntu-latest; `working-directory` kommt aus `defaults`).
- [x] Vorab lokal bestätigen, dass der gesamte Ordner `test/domain/utils` unter Berlin grün ist (laut Research nach dem Fix der Fall; sonst Schritt nicht aufnehmen und Rückfrage).
- [x] YAML-Syntax und Einrückung prüfen; keine weiteren Workflow-Änderungen.

## Validierung
- `cd mobile && dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze --no-fatal-infos`, `dart run custom_lint`, `flutter test` (UTC/Standard-TZ)
- `TZ=Europe/Berlin flutter test test/domain/utils` und `TZ=America/New_York flutter test test/domain/utils`
- Nichts committen vor Freigabe; kein `git stash`.

## Risiken
- Neuer CI-Schritt deckt nur `test/domain/utils` ab; andere TZ-latente Stellen (insights, reports_page, Notifications) bleiben im Folge-Issue.
- Falls andere Tests in `test/domain/utils` unter Berlin rot sind, CI-Schritt erst nach deren Klärung aktivieren.
