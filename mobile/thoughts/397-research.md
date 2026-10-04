# Mobile-Research: #397 — Pausenzeit im Bearbeiten-Dialog bekommt das Datum von "jetzt"
Datum: 2026-10-04

## Aufgabe
`EditBreakModal._selectTime` (edit_break_modal.dart:76-78) baut die gewählte Uhrzeit mit
`DateTime.now()`-Datum statt mit dem Datum der Pause/des Eintrags. Erwartet: Datum des
Eintrags verwenden. Akzeptanz laut Issue: zuerst reproduzieren (Eintrag von gestern, Pause
ändern); Test mit festen Daten, Fake-Uhr, auch unter `TZ=Europe/Berlin`. Nicht Teil: #387-Scope.

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `lib/presentation/widgets/edit_break_modal.dart` Z. 75-78 | Ursache: `now = DateTime.now(); DateTime(now.year, now.month, now.day, h, m)` |
| `lib/presentation/widgets/edit_break_modal.dart` Z. 82-91, 103 | Folgefehler: Dauer-Verschiebung via `add`, Prüfung `end.isBefore(start)` |
| `lib/presentation/screens/dashboard_screen.dart` Z. 365 | einziger Aufrufer (`showDialog` -> `EditBreakModal(breakEntity: b)`) |
| `lib/presentation/view_models/dashboard_view_model.dart` Z. 737-744 | `updateBreak`: ersetzt Pause per `id`, `_recalculateStateAndSave` speichert |
| `lib/domain/utils/date_utils.dart` | Ort für einen kleinen Helper (siehe Plan-Hinweis) |
| `test/presentation/widgets/edit_break_modal_test.dart` | bestehende Tests, `FakeDashboardViewModel.lastUpdatedBreak` nutzbar |
| `test/support/fake_clock.dart`, `lib/core/providers/clock_provider.dart` | Fake-Uhr für VM-Tests |

## Ist-Zustand / Ursache
**Wo:** Nur `_selectTime`. `initState` setzt `_startTime/_endTime` korrekt aus `breakEntity`
(Anzeige stimmt, daher fällt der Fehler erst nach dem Speichern auf). Nach Auswahl im
`showTimePicker` bekommt die neue Zeit das Datum von heute.

**Aufrufer:** Nur das Dashboard (Pausenliste). Reports -> `EditWorkEntryModal` ist nicht
betroffen (dort `workEntry.date`, Z. 158-182/237-268, korrekt). Das Dashboard zeigt normalerweise
den heutigen Eintrag; "Datum jetzt != Datum der Pause" tritt daher nur auf, wenn:
1. **Timer läuft über Mitternacht** (#379): Eintrag und Pausen bleiben am Vortag, Nutzer
   bearbeitet nach 00:00 eine Pause -> neue Zeit bekommt das Datum von heute.
2. Dashboard zeigt noch den Vortag, bevor der Tageswechsel greift (kurzes Fenster; ein
   gestoppter Vortag wird sonst still auf heute umgeschaltet, `_ensureCurrentDay`).
3. Pausen, die selbst nach Mitternacht liegen (Start nach 00:00 am Folgetag), werden
   fälschlich auf "jetzt" gezogen (auch wenn jetzt gleicher Tag wie die Pause: dann
   korrekt, sonst falsch).
Der Fall "Eintrag von gestern im Dashboard bearbeiten" aus dem Issue ist im Dashboard nur
über 1. erreichbar; die Reports-Pfade sind korrekt. Reproduktion (Test, deterministisch):
Pause 2024-01-15 12:00-12:30, Modal öffnen, Startzeit auf 13:00 setzen, Speichern ->
`lastUpdatedBreak.start` ist heutiges Datum 13:00 statt 2024-01-15 13:00.

**Fehlerbilder:**
- Nur Start geändert: Start = heute, `_endTime` = `_startTime.add(previousDuration)` = heute
  -> Pause komplett auf heute verschoben (Dauer stimmt noch).
- Nur Ende geändert: Ende = heute, Start = Vortag -> Pause ~24 h + x lang.
  `isBefore`-Prüfung greift nicht (Ende liegt später), wird gespeichert.
- Name-only-Änderung: unkritisch, Zeiten bleiben unverändert (`copyWith` mit altem Start/Ende).

**DST:** `DateTime(y,m,d,h,min)` (lokal) ist der richtige Weg; Dart normalisiert
nicht existierende Zeiten (Berlin 2026-03-29 02:30 -> 03:30) und wählt bei Doppelstunde
(2026-10-25 02:30) eine der beiden Instanzen. Das ist bei einem lokalen Zeitpicker
vertretbar. Wichtig: `add(Duration)` auf Tagesgrenzen/DST ist Absolutzeit (30 min bleiben
30 min), Kalenderarithmetik nur über `addCalendarDays` (date_utils.dart). Kein `Duration(days:)`.

## Datenfluss
`DashboardScreen` (Pausenliste) -> `EditBreakModal` -> `DashboardViewModel.updateBreak`
(`_ensureCurrentDay`, ersetzt Pause per id in `state.workEntry.breaks`) ->
`_recalculateStateAndSave` -> Hybrid-Repo (Firestore/API bzw. SharedPreferences).
Hinweis: Ist der angezeigte Vortag nicht laufend, lädt `_ensureCurrentDay` auf heute um;
die id findet sich dann nicht mehr -> `updateBreak` ist ein stiller No-op (kein Datenschaden).

## Nachbarstellen (gleiche Fehlerklasse: Uhrzeit + `DateTime.now()`)
Grep über `lib/` nach `DateTime.now()`/`TimeOfDay.now()`:
| Stelle | Bewertung |
|---|---|
| `edit_work_entry_view_model.dart` `addBreak` (Z. 31-34): `state.newStartTime ?? nowToMinute()` | **Gleiche Klasse, gering.** Greift nur, wenn kein Start gesetzt ist (Typ work verlangt beim Speichern Start, aber Pause kann vorher hinzugefügt werden): neue Pause bekäme heutiges Datum für Eintrag eines anderen Tages. Im Plan mitnehmen (Fallback `entry.date` + Uhrzeit nowToMinute, oder Start-Pflicht). `nowToMinute()` ist nicht an `clockProvider` angebunden. |
| `edit_work_entry_modal.dart` Z. 133 / `dashboard_screen.dart` Z. 467 `TimeOfDay.now()` | Unkritisch: nur Initialwert des Pickers, kein Datum. |
| `dashboard_screen.dart` Z. 66 `b.end ?? DateTime.now()` | Nur Anzeige laufender Pause, nicht über `clockProvider` (Test-Hygiene, nicht #397). |
| `settings_view_model.dart` Z. 235, `weekly_reflection_view_model.dart` Z. 70, `dashboard_state.dart` Z. 39 | Zeitstempel/Default, nicht betroffen. |
| `edit_work_entry_modal.dart` Start/Ende/Pausen Z. 158-182, 237-268 | Korrekt: nutzen `originalEntry.date`/`workEntry.date`. Kleine Besonderheit: Pausen nach Mitternacht werden dort auf `entry.date` gezwungen (Overnight nicht abbildbar). |
| `quick_entry_dialog.dart` Z. 110-116 | Korrekt (`widget.date`). |
| `batch_quick_entry_dialog.dart` Z. 35-37 | `DateTime(2000,1,1,8,0)` nur als TimeOfDay-Hilfswert, unkritisch. |
| `dashboard_view_model.dart` `setManualStartTime/EndTime` (Z. 643-678) | Korrekt: Datum aus bestehendem `workStart/workEnd/date`. **Dies ist das Muster für den Fix.** |
| `add_adjustment_modal`, `edit_*_modal` (Ziel-Stunden, Urlaub, Timezone) | Kein Uhrzeit+Datum-Aufbau (nicht gefunden). |
Ergebnis: Hauptbug nur edit_break_modal; `addBreak` als Nebenfund.

## Pause über Mitternacht
- `_saveChanges` prüft nur `end.isBefore(start)` -> Fehler `endBeforeStartError`. Gleichheit
  (0 Minuten) wird akzeptiert.
- Eine Pause 23:30-00:30 ist über den Dialog nicht eingebbar (Ende wird mit gleichem Tag gebaut
  und liegt vor Start). Heute (mit "jetzt"-Datum) ebenso. Über Start-Verschiebung via
  `add(previousDuration)` kann das Ende aber auf den Folgetag laufen (23:50 + 30 min) und
  wird dann korrekt gespeichert; die Endzeitanzeige zeigt nur HH:mm, der Tageswechsel ist nicht sichtbar.
- Fix-Variante A (minimal): Basisdatum = Datum des bestehenden Werts (`_startTime` bzw.
  `_endTime ?? _startTime`), wie in `setManualStartTime`. Erhält Folgetag-Pausen.
- Variante B (Issue-Wortlaut): `entry.date` aus `dashboardViewModelProvider.workEntry.date`.
  Würde Pausen nach Mitternacht auf den Eintragstag zurückziehen -> Ende < Start beim Overnight-Lauf.
- Empfehlung: A, optional Ende-Rollover (Ende < Start und Differenz sinnvoll -> `addCalendarDays(+1)`),
  nur wenn gewünscht (siehe Fragen).

## Testplan (TDD, datums-/TZ-unabhängig)
1. Reiner Unit-Test für Helper (z. B. `combineDateAndTime(DateTime day, TimeOfDay t)` in
   `domain/utils/date_utils.dart`, `test/domain/utils/date_utils_test.dart`): feste Daten
   2024-01-15; 2026-03-29 (02:30 nicht existent, nur Invariante `result.year/month/day` bleiben
   gleich, Stunde in {2,3}) und 2026-10-25; 23:59->Datum unverändert. TZ-unabhängig als
   Invarianten (kein harter Offset), laufen mit `TZ=Europe/Berlin`, `UTC`, `America/Los_Angeles`.
2. Widget-Test `edit_break_modal_test.dart` (bestehende Struktur): Pause an festem Datum
   (2024-01-15, weit weg von "jetzt"); Picker öffnen, per Tastatur-Modus (Icon `Icons.keyboard_outlined`)
   Stunde/Minute eingeben, OK, Speichern; erwarten `fakeViewModel.lastUpdatedBreak.start` ==
   `DateTime(2024,1,15,13,0)` und `end` == `DateTime(2024,1,15,13,30)`. Zweiter Fall: nur Endzeit
   ändern -> Dauer bleibt <= 1 Tag, Datum = Datum der Pause. Dritter: Pause am Folgetag
   (Start 2024-01-16 00:10) bleibt Folgetag. Der Modal braucht keine Uhr; ein Fake-Datum 2024
   reicht, weil "jetzt" immer ein anderes Datum liefert (Test schlägt vor dem Fix reproduzierbar fehl).
3. Fake-Uhr dort, wo sie wirkt: VM-Test in `dashboard_view_model_break_test.dart` /
   `_day_change_test.dart` (fakeAsync + `FakeClock` + `clockProvider`-Override): Timer startet
   Fr 23:00, Pause 23:30, `clock.jumpTo` Sa 00:20, `updateBreak` mit gleichem Datum -> Eintrag
   und Pause bleiben am Fr-Schlüssel. Absicherung des Mitternacht-Szenarios (#379) ohne UI.
4. Lokal zusätzlich `TZ=Europe/Berlin flutter test` (CI-Pflicht) sowie `TZ=UTC`/`Pacific/Auckland`.
5. Optional `addBreak` (edit_work_entry_view_model_test): Eintrag eines festen Tags ohne Start ->
   Pausendatum = Eintragsdatum.

## Persistenz
- Ja, falsche Werte werden gespeichert: `updateBreak` -> `_recalculateStateAndSave` schreibt
  `BreakEntity.start/end` (absolute Timestamps) im days-Map-Eintrag des Eintragsdatums.
  Das Eintragsdatum selbst bleibt richtig; nur die Pausen-Zeitstempel liegen am falschen Tag
  (oder 24 h+ lang bei einseitiger Änderung).
- Auswirkung: Pausensumme/Netto-Arbeitszeit/Überstunden (Dauer = end - start) falsch bei
  einseitigem Ändern; bei Änderung beider Felder stimmt die Dauer, nur das Datum ist falsch.
  Reports clippen teilweise Pausen auf den Zeitraum (`reports_page.dart` Z. 250/468/2448) —
  Einfluss dort nicht verifiziert.
- Datenreparatur: nur ein Heuristik-Migrationsschritt wäre möglich (Pause-Datum != Eintragstag
  und nicht Overnight-Lauf), ist aber riskant (legitime Folgetag-Pausen, Web/Backend schreiben
  eigene Formate). Betroffen sind nur Nutzer, die nach Mitternacht bei laufendem Timer eine
  Pause bearbeitet haben. Empfehlung: nur Fix, keine Migration; Nutzer korrigieren über Berichte.

## Plattformübergreifend
Nur Mobile. Web (`edit`-Komponente) und Backend nicht geprüft; optional kurz gegenprüfen, ob
Web dieselbe Datum-Komposition nutzt (kein Teil von #397). Keine ARB-Texte, keine
Provider-Änderung, kein build_runner nötig (Helper rein in `date_utils.dart`).

## Offene Fragen
1. Basisdatum: Datum der Pause selbst (Variante A, empfohlen) oder `entry.date` aus
   `dashboardViewModelProvider` (Issue-Wortlaut)? Empfehlung A (erhält Pausen nach Mitternacht).
2. Overnight-Pausen (23:30-00:30) im Dialog unterstützen (Ende < Start -> +1 Tag) oder weiter mit
   `endBeforeStartError` ablehnen? Empfehlung: ablehnen (Scope), Verhalten per Test festhalten.
3. `addBreak`-Nebenfund (`nowToMinute()` ohne Start) im selben PR mitfixen? Empfehlung: ja, klein,
   mit Test; sonst Folge-Issue.
4. Datenreparatur? Empfehlung: keine, nur Fix; Hinweis im PR.
5. Helper `combineDateAndTime` in `date_utils.dart` anlegen (auch für Dashboard-VM/Edit-Modal
   wiederverwendbar) oder Inline-Fix? Empfehlung: Helper, aber nur im Modal einsetzen.

## Risiken
- Falsches Basisdatum bei Variante B bricht Pausen nach Mitternacht.
- Widget-Test mit `showTimePicker` ist fragil (Tastatur-Modus, Layout); Helper-Unit-Test deckt Kern ab.
- DST-Doppelstunde: Dart-Wahl der Instanz nicht steuerbar; Tests nur als Invarianten.
- Bestehende Tests nutzen 2024-Daten; nach dem Fix dürfen sie nicht von "jetzt" abhängen (tun sie nicht).

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Variante A: Basisdatum ist das Datum der Pause selbst (Start: Datum von `_startTime`, Ende: Datum von `_endTime ?? _startTime`). Nicht `entry.date`.
2. Overnight-Pausen (Ende < Start) im Dialog weiter ablehnen; Verhalten per Test festhalten.
3. `edit_work_entry_view_model.addBreak` (Fallback `nowToMinute()` ohne Start) im selben PR mitfixen, klein, mit Test, als eigener Commit.
4. Keine Datenreparatur; nur Hinweis im PR-Text.
5. Helper `combineDateAndTime` in `domain/utils/date_utils.dart` anlegen (DST-sicher, `DateTime(y,m,d,h,min)`), vorerst nur im Modal (und addBreak) einsetzen.
6. Kein separater Plan (kleiner Fix): direkt TDD nach Testplan der Research.
