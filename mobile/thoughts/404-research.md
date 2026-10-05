# Mobile-Research: #404 — Reports rechnen offene Einträge mit „jetzt“, Backend zählt 0
Datum: 2026-10-04
Branch: claude/week-number-display-bug-x5xq8r (auf develop, cea2d3a)

## Aufgabe
Ein Eintrag mit `workStart != null && workEnd == null` wird in den Mobile-Reports mit der aktuellen Uhrzeit als Ende berechnet. Ein verwaister Vortag (siehe #385) ergibt eine absurde Dauer. Backend (`ReportCalculator`) und Web zählen Netto nur bei Start UND Ende, sonst 0.

Akzeptanzkriterien (Issue):
- Offene Einträge vor heute rechnen nicht mehr mit „jetzt“ (Backend-konform 0 bzw. klar als „läuft noch / unvollständig“ gekennzeichnet).
- Nur der heute laufende Eintrag darf live mitzählen.
- Test mit fester Uhr, TZ-unabhängig, auch unter `TZ=Europe/Berlin`.
Nicht Teil: Fortsetzen/Beenden offener Einträge (#385, PR 1b), Backend-Änderung, Persistenz, Behebung der bekannten Flutter-Abweichungen (doppelte Pausen-Subtraktion u. a., `server/CLAUDE.md`).

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `mobile/lib/presentation/screens/reports_page.dart` Z. 241, 461, 2439 | **Die einzigen drei Stellen mit „jetzt“** (`workEnd ?? nowToMinute()`): Tages-Tab Summe + Tages-Überstunden (Z. 229-274), Eintragskarte im Tages-Tab (Z. 456-566), Bottom-Sheet je Kalendertag (Z. 2429-2518). Drei fast identische Schleifen (Pausen auf [start,end] klemmen, offene Pause bis `end`). |
| `mobile/lib/domain/entities/work_entry_extensions.dart` Z. 13 | `calculatedWorkDuration` nutzt `nowToMinute()`. Praktisch toter Code, siehe unten; Stolperfalle, aufräumen. |
| `mobile/lib/l10n/app_de.arb` / `app_en.arb` | Neue Texte für die Kennzeichnung (falls Variante B). Vorhanden: `breakInProgress` („läuft...“, Beschreibung sagt „Pause“, wird aber auch als Ende-Platzhalter offener Einträge genutzt), `openEntryBannerTitle` (#385). |
| `mobile/lib/core/providers/clock_provider.dart`, `today_provider.dart` | Uhr/„heute“-Quelle für die Entscheidung „heute oder vor heute“. `reports_page_test.dart` überschreibt `clockProvider` bereits (Default 2026-10-02 12:00). |
| `mobile/test/presentation/screens/reports_page_test.dart`, `reports_page_widget_test.dart`, `test/domain/entities/work_entry_extensions_test.dart` | Testvorlagen / Anpassung. |

## Ist-Zustand je Stelle (Bewertung)

Wichtiger Befund zuerst: Dart bevorzugt Instanzmember vor Extension-Membern (mit einem Scratch-Programm verifiziert: `a.x` liefert den Klassen-Getter, nur unqualifizierte Aufrufe **innerhalb** der Extension treffen deren eigenen Getter). `WorkEntryEntity` hat selbst `effectiveWorkDuration` (`totalWorkTime - totalBreakTime`, `totalWorkTime` = 0 bei `workEnd == null`). Alle `e.effectiveWorkDuration`-Aufrufer außerhalb der Extension rechnen daher **nicht** mit „jetzt“.

| Stelle | „jetzt“? | Bewertung |
|---|---|---|
| `reports_page.dart` Tages-Tab Summe/`dayOvertime` (Z. 229-274) | ja | **falsch** bei Vortagen (Vortag offen: Netto = jetzt − Start, `dayOvertime` riesig positiv). Für heute laufend korrekt (live). |
| `reports_page.dart` Eintragskarte (Z. 456-566) | ja, Titel „Arbeitszeit: hh:mm:ss“ | **falsch** bei Vortagen. Inkonsistent: `calculateOvertime` der Karte liefert für offene Einträge 0 (Guard), die Tages-Summe oben rechnet mit „jetzt“. Das Ende zeigt schon „läuft...“. Außerdem tickt es nicht (nur beim Neuaufbau). |
| `reports_page.dart` Bottom-Sheet (Z. 2437-2456) | ja | **falsch** bei Vortagen (Kalender-Tap auf einen verwaisten Tag). |
| `work_entry_extensions.dart` `calculatedWorkDuration`/`effectiveWorkDuration` | ja | Nur über `calculateOvertime` erreichbar, das vorher `workEnd == null` → 0 zurückgibt. Außerhalb der Extension verdeckt der Klassen-Getter. Toter Pfad, aber irreführend. `calculatedWorkDuration` hat keinen Aufrufer außerhalb. Hinweis: der Extension-Getter klemmt auf ≥ 0, der Klassen-Getter nicht (Unterschied für abgeschlossene Einträge, im Report nie gesehen). |
| `ReportsViewModel._calculateDailyReport/_calculateWeeklyReport/_calculateMonthlyReport` | nein | Kein „jetzt“. `totalWorkTime` = 0 bei offenem Eintrag; `dailyWork`/`weeklyWork` nehmen nur `workEnd != null`. Offener Tag wird als Arbeitstag mit Start gezählt (Soll steigt) wie im Backend (`workDaySet.Add` bei `WorkStart`). Bekannt abweichend und außerhalb: Pausen werden doppelt abgezogen; geschlossene Pausen eines offenen Eintrags machen die Summe negativ (Backend: gleiche Eigenheit, `netWork = 0 − SumBreakMs`). |
| Eingeloggt: `_loadReportsFromApi` überschreibt Tages-Überstunden, Wochen- und Monatsbericht mit Backend-Werten | nein | Bereits Backend-konform (offener Eintrag = 0). Der Tages-Tab in `reports_page.dart` benutzt `dailyReport.overtime` aber **nicht**, sondern rechnet `dayOvertime` selbst (Z. 274). Der Bug betrifft also auch eingeloggte Nutzer. |
| `yearly_report_utils.dart` `calculateMonthSummary` | nein | Kein „jetzt“ (Klassen-Getter). Offener Eintrag: Netto 0 (minus geschlossene Pausen), Arbeitstag zählt fürs Soll, identisch zum Backend. Keine Änderung. |
| `insights_utils.dart` (`_effectiveDuration`) | nein | Schließt offene Einträge aus (0 bzw. nicht gezählt). Korrekt, Backend-konform. |
| `pdf_report_service.dart` | nein | Bekommt nur vorberechnete Aggregate (`dailyWork`, Summen) aus `weeklyReport`/`monthlyReport`; kein `now`. Offene Einträge fehlen darin (nur `workEnd != null`). Kein Handlungsbedarf. |
| `reports_page.dart` Wochen-/Monatsliste, Kalendermarkierung (`dailyWork.keys`) | nein | Offene Tage tauchen in `dailyWork` nicht auf: in der Wochen-/Monatsliste unsichtbar, im Kalender ohne Marker. Nur der Tages-Tab bzw. das Sheet zeigt sie. Siehe Frage 3. |
| `dashboard_screen.dart` Z. 68 `DateTime.now()` (Live-Pausensumme), `DashboardViewModel._now()` | ja | **Korrekt**: laufender Eintrag zählt live, Uhr ist im VM über `clockProvider` injiziert (#379). Läuft ein Timer über Mitternacht, bleibt er am Starttag und zählt live (Entscheidung #379). Z. 68 nutzt `DateTime.now()` direkt (nicht injiziert, nur Anzeige einer laufenden Pause, nicht Teil von #404). |
| `edit_work_entry_view_model.dart` Z. 41 `nowToMinute()` | Vorbelegung | Kein Report, nicht betroffen. |

## Backend / Web: offene Einträge
- Backend `ReportCalculator`: Domain ohne Uhr. `NetWorkMs` = 0 bei fehlendem Start oder Ende; `GrossWorkMs` ebenso. Tag: `worked = 0`, `overtime = −Soll + manuell`. Wochen/Monat: Tag zählt als Arbeitstag (Start gesetzt), `worked = 0`, geschlossene Pausen werden trotzdem abgezogen; offene Pausen (`End == null`) ignoriert.
- Web `report-calculator.ts` identisch (Z. 44, 126, 193). Web-Reports-Liste (`reports.html` Z. 141) zeigt für einen Eintrag ohne Ende `reports.timeRunning` („läuft…“ / „in progress…“) an der Stelle der Endzeit; die Netto-/Überstundenanzeige rechnet 0 (`reports.service.ts` Z. 312). **Es gibt im Web keine eigene „unvollständig“-Kennzeichnung**, nur den Platzhalter beim Ende. Mobile hat denselben Platzhalter schon (`breakInProgress`).

## Datenfluss
`ReportsPage` (ConsumerWidget, `ref` vorhanden) → `reportsViewModelProvider` (`dailyReportState.entries`, `applyBreakCalculation`) → pro Eintrag lokale Schleife in `reports_page.dart`. Keine UseCases/Repos berührt, keine Persistenz. Gleitzeit-Saldo (`OvertimeRepository`, Dashboard `initialOvertime`) liest diese Anzeige nicht; geschrieben wird er nur in Dashboard-Stop und `CloseOpenWorkEntry`. **Reine Anzeigeänderung**, keine Reparatur, kein Datenmigrationsbedarf.

## Plattformübergreifend
Nur Mobile. Web und Backend zählen bereits 0; kein neuer Pfad, keine Rules, kein `profileId`-Thema. Nachziehen im Web wäre nur die optionale Kennzeichnung (Parität), nicht Teil.

## Bewertung der Varianten (Frage 2)
Regel (Entscheidungsvorschlag bestätigt): Eintrag ist **live**, wenn Typ `work`, Start gesetzt, kein Ende und lokaler Tag des Eintrags == `todayProvider`. Vor heute und offen: Netto 0 (Backend-konform). Tag des Eintrags immer über `DateTime(date.year, date.month, date.day)` (wie #385 `_dayOf`), nie über UTC-Konvertierung.

- **Variante A (nur Rechenlogik):** ca. 1 PR, klein. Nachteil: der Tages-Tab zeigt dann „Arbeitszeit: 00:00:00“ und ein −8:00 Tagessaldo ohne Erklärung; der Nutzer sieht „Ende: läuft...“ und versteht nicht, warum 0 gezählt wird.
- **Variante B (mit Kennzeichnung), empfohlen:** zusätzlich Karte/Sheet für offene Vortage: Titel statt „Arbeitszeit: 00:00:00“ ein Hinweis, Überstundenzeile der Karte entfällt. Neu 2 ARB-Keys (de+en), z. B. `reportsEntryIncompleteTitle` („Unvollständig“) und `reportsEntryIncompleteHint` („Kein Ende erfasst, daher nicht in der Auswertung. Im Dashboard beenden.“; Anmerkung: Das Dashboard-Banner (#385) zeigt nur aktuellen + Vormonat und nur das aktive Profil, deshalb den Text nicht auf „Banner“ festlegen). Du-Form, `@key`-Beschreibung. Aufwand grob +30-40 % gegenüber A, überwiegend Widget-Tests de/en.
- **Interaktion mit #385:** Der Banner und Reports teilen die Definition „offen vor heute“. Empfehlung: ein kleiner reiner Helper in `domain/utils` (z. B. `isOpenBeforeToday(entry, today)` bzw. `netDurationForReport(entry, now, today)`), den `GetOpenPastWorkEntries` später mitbenutzen kann (nicht in diesem PR anfassen). Grenzfall Dashboard-Lauf über Mitternacht (#379): Der Eintrag ist vom Vortag und läuft im Dashboard live, ist aber „vor heute“ → Reports zeigen ihn als „läuft noch“ mit 0, nicht live. Konsistent mit dem Issue-Wortlaut („nur der heute laufende“); als Frage 2 dokumentiert. Ältere Einträge (> Vormonat), andere Profile: der Banner erreicht sie nicht, Reports zeigen sie über Kalender-Tap; der Hinweistext soll deshalb nicht „Beenden über Banner“ versprechen.
- **Tages-Überstunden eines Tages nur mit offenem Vortagseintrag:** Backend-konform `−Soll` (rot). Alternativ ausblenden. Siehe Frage 4.

## Testplan
Fest, ohne `DateTime.now()`; Uhr über `clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 12))` (Mo, kein DST-Tag), alle Zeiten lokal per `DateTime(y, m, d, h, min)` konstruiert (keine ISO-/UTC-Strings, keine Wochentagsannahme außer Datum-Konstanten). Differenzen (z. B. 3 h) sind unabhängig von der Zeitzone; DST-Tage (Berlin 2026-03-29 / 2026-10-25) nicht verwenden. CI läuft in `Europe/Berlin`; lokal zusätzlich `TZ=UTC`, `TZ=America/Los_Angeles`, `TZ=Pacific/Auckland flutter test <Dateien>`.
1. **Unit (rein, `test/domain/utils/…`):** Helper-Tabelle: (a) abgeschlossen → `end − start − Pausen`; (b) offen, Tag == heute → `now − start − Pausen` (offene Pause bis `now`); (c) offen, Vortag (1 Tag, 5 Tage, Vormonat) → 0; (d) offen, Tag == heute, aber `now` < `start` (Uhrsprung) → nicht negativ; (e) Typ vacation/sick/holiday ohne Ende → nicht „offen“; (f) Mitternachts-Grenze: Uhr 23:59 vs. 00:01 am Folgetag, derselbe Eintrag wechselt von live zu 0 (nur über Übergabe von `today`/`now`, kein Timer).
2. **Widget (`reports_page_test.dart`-Muster):** Vortag offen (Start 2026-10-02 08:00, Uhr 2026-10-05 12:00): Tages-Tab zeigt Summe 00:00, `dayOvertime` = −Soll (Backend-Wert), Karte ohne „Arbeitszeit: 76:00:00“; Hinweistext vorhanden (de und en, `locale`-Override); Bottom-Sheet analog; Gegenprobe heute offen (Start 08:00, Uhr 12:00) → 04:00 live. Gegenprobe abgeschlossen unverändert.
3. **Bestehendes grün halten:** `work_entry_extensions_test` (falls `calculatedWorkDuration` angepasst wird), `reports_view_model_test`, `yearly_report_utils_test`.
4. **Mutationsproben (vor dem Fix rot, nach dem Fix grün, danach gezielt wieder einbauen):** (i) Helper-Bedingung `today`-Vergleich auf `!=` bzw. immer „live“ → Vortagstest rot; (ii) Helper immer 0 → Heute-live-Test rot; (iii) Tag über `entry.date.toUtc()` statt lokal → rot in `TZ=America/Los_Angeles`/`Pacific/Auckland` (nur wenn ein Testdatum nahe Mitternacht existiert, sonst Test ergänzen); (iv) Pausenklemmung entfernen → Test mit Pause vor Start rot. Rot-Nachweis vor dem Fix dokumentieren (Tages-Tab-Test zeigt aktuell 76:00:00).

## Aufteilung / PR-Größe
Klein, ein PR genügt (Variante B): Helper + Test, Umstellung der drei Stellen in `reports_page.dart` auf den Helper (dedupliziert die Pausenschleife), 2 ARB-Keys de/en, Aufräumen `calculatedWorkDuration`, CLAUDE.md-Abschnitt (kurz unter #385 „Grenzen“ aktualisieren: #404 erledigt). Kein `build_runner` nötig (kein `@riverpod`), `flutter gen-l10n` nach ARB. Falls Variante A gewählt: ohne ARB. `reports_page.dart` ist ~2500 Zeilen groß, daher nur minimale, lokale Diffs und kein Umbau.

## Offene Fragen (mit Empfehlung)
1. **Variante A oder B?** Empfehlung B (Kennzeichnung), 2 ARB-Keys. Begründung: nur 0 ohne Erklärung wirkt wie ein Datenverlust.
2. **Dashboard-Lauf über Mitternacht (#379) in den Reports:** Eintrag vom Vortag, im Dashboard live. Empfehlung: in den Reports als „vor heute offen“ (0 + Kennzeichnung) behandeln, nicht live (einfach, Backend-konform, Issue-Wortlaut). Alternative wäre, den vom Dashboard gehaltenen Eintrag zusätzlich live zu rechnen; das koppelt Reports an `dashboardViewModelProvider` und wird nicht empfohlen.
3. **Offene Tage in Wochen-/Monatsliste und Kalender (heute unsichtbar, da `dailyWork` nur `workEnd != null`)?** Empfehlung: nicht ändern (Backend-konform, `dailyWork` kommt eingeloggt vom Server); der Tages-Tab deckt die Kennzeichnung ab.
4. **Tages-Überstunden bei Tag nur mit offenem Vortagseintrag:** `−Soll` (Backend-konform) oder ausblenden? Empfehlung: Backend-konform lassen und mit dem Hinweis erklären; eigene Sonderanzeige vermeiden.
5. **Hinweistext-Formulierung:** nicht auf den Banner verweisen (greift nur für aktuellen + Vormonat, aktives Profil). Empfehlung: „Kein Ende erfasst – dieser Eintrag zählt nicht in die Auswertung.“ plus (optional) Verweis aufs Bearbeiten über das Stift-Icon der Karte, das es schon gibt.
6. **`calculatedWorkDuration`:** Mit-Bereinigung (auf `workEnd`-basiert, kein `nowToMinute`) oder bewusst unangetastet? Empfehlung: mitnehmen, weil toter Pfad und Falle, kein Verhaltensunterschied (Test ergänzen, der das belegt).
7. **Branch:** `claude/week-number-display-bug-x5xq8r` heißt thematisch anders (steht auf develop); wie bei #390/#385 trotzdem nutzen, PR-Titel mit `#404`. Hinweis im PR: Backend- und Web-Rechnung unverändert (Web-Parität der Kennzeichnung offen, kein Pflicht-Follow-up).
8. **Nebenbefunde (kein Teil von #404, ggf. Hinweis im PR):** (a) geschlossene Pausen eines offenen Eintrags machen die lokale Wochen-/Monatssumme negativ (auch im Backend so); (b) `dashboard_screen.dart` Z. 68 `DateTime.now()` statt `clockProvider`.

## Risiken
- `reports_page.dart` baut Dauern im `build`; ein „live“ heute laufender Eintrag aktualisiert sich nur bei Neuaufbau (heute schon so, kein Ticker). Nicht erweitern.
- Tag des Eintrags: `entry.date` kann je Quelle (lokal/API, UTC-Konvertierung) auf einen anderen Tag fallen; #385 hat dieselbe Falle (`_dayOf`). Test mit `TZ=America/Los_Angeles`/`Pacific/Auckland`.
- Extension-Shadowing: Wer später `effectiveWorkDuration` „reparieren“ will, trifft auf zwei gleichnamige Getter mit unterschiedlicher Klemmung. Beim Aufräumen nur `calculatedWorkDuration` anfassen, den Klassen-Getter nicht (Reports/Yearly hängen daran).
- Screen-Tests, die `DashboardScreen` pumpen, brauchen `openEntryViewModelProvider`-Override (#385); für `ReportsPage`-Tests gilt das nicht, `clockProvider` ist dort schon überschrieben.
- ARB: Du-Form, `@key`-Beschreibung, `flutter gen-l10n`; generierte `app_localizations*.dart` nicht manuell editieren.

## Plan (TDD, knapp; Variante B)
1. **Rot:** Unit-Tests für den Helper (Tabelle Testplan 1) in `test/domain/utils/open_entry_report_utils_test.dart` (Name Vorschlag) und Widget-Test Vortag-offen im Tages-Tab (zeigt aktuell absurde Dauer, Rot-Nachweis notieren).
2. **Helper** `lib/domain/utils/…`: reine Funktion `Duration reportNetDuration(WorkEntryEntity e, {required DateTime now})` (live nur wenn `isSameDay(e.date, now)`; Pausenklemmung aus den drei Schleifen) und `bool isOpenBeforeToday(WorkEntryEntity e, DateTime now)`. Keine Flutter-Imports.
3. **ARB** de/en (2 Keys), `flutter gen-l10n`.
4. **`reports_page.dart`:** drei Stellen auf den Helper, `now` aus `ref.read(clockProvider)()`, Karte/Sheet für offene Vortage: Hinweis statt Arbeitszeit, Überstundenzeile weg.
5. **`work_entry_extensions.dart`:** `calculatedWorkDuration` ohne `nowToMinute` (Brutto nur bei `workEnd`), Test anpassen.
6. **Grün + Mutationsproben** (Testplan 4), Checks: `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`, zusätzlich Teilmenge unter `TZ=UTC`, `America/Los_Angeles`, `Pacific/Auckland`.
7. **Doku:** `mobile/CLAUDE.md` Abschnitt „Offene Einträge vor heute (#385)“, Zeile „Grenzen“: Reports-Darstellung (#404) erledigt, Regel „live nur heute“ festhalten.

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. Variante B: Netto 0 plus Kennzeichnung „Unvollständig / kein Ende erfasst" in Eintragskarte und Bottom-Sheet; 2 neue ARB-Keys de (duzen)/en; reiner Helper in domain/utils (live nur wenn Eintragstag == heute), die drei Schleifen deduplizieren.
2. Im Dashboard über Mitternacht laufender Vortag (#379): in den Reports als „vor heute offen" behandeln (0 + Kennzeichnung), nicht live.
3. Offene Tage in Wochen-/Monatsliste und Kalender bleiben unverändert (nicht ändern).
4. Tag mit nur einem offenen Vortagseintrag: Tagesüberstunden = −Soll (Backend-konform) lassen.
5. Hinweistext ohne Bezug auf den Banner: „Kein Ende erfasst – dieser Eintrag zählt nicht in die Auswertung." (de duzend/sachlich, en sinngemäß).
6. `calculatedWorkDuration` (toter Code) aufräumen, mit Test.
7. Auf dem Session-Branch arbeiten, PR-Titel mit #404.
8. Nebenbefunde nur als Hinweis im PR-Text: Geschlossene Pausen eines offenen Eintrags machen die Wochen-/Monatssumme negativ (im Backend ebenso); Dashboard Z. ~68 nutzt `DateTime.now()` statt clockProvider.
9. Der Abschnitt „Plan" am Ende der Datei gilt; kein separater Planer-Schritt.
