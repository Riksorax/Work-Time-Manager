# Mobile-Research: #354 — Wochen-Reflexion: Schlüssel ohne ISO-Wochenjahr
Datum: 2026-10-03

## Aufgabe
Die Wochen-Reflexion (#137) speichert unter `yyyy-Www`. `year` kommt in `reports_page.dart`
(Zeile 756-759) aus `startOfWeek.year` (Kalenderjahr des Montags), `week` aus
`isoWeekNumber(startOfWeek)`. Am Jahreswechsel stimmt das Paar nicht. Umstellen auf
`isoWeekYear(startOfWeek)` (Util existiert seit #353 in `domain/utils/iso_week.dart`, bisher nur
in Tests genutzt). Für Altdaten (unter altem Schlüssel gespeichert) ist Migration oder
bewusster Verzicht zu entscheiden. Web-Nutzung des Schlüssels prüfen.

Akzeptanzkriterien (abgeleitet): Wochen um den Jahreswechsel bekommen den ISO-Schlüssel
(Mo 29.12.2025 -> `2026-W01`); ISO-Jahr und Wochenzahl kommen immer aus demselben Datum;
Test ohne Datums-/Zeitzonenabhängigkeit; Entscheidung zu Altdaten dokumentiert.

## Betroffene Dateien
| Datei | Warum |
|---|---|
| `mobile/lib/presentation/screens/reports_page.dart` (698-701, 756-759, 768-775) | Einziger Aufrufer des Dialogs; `year: startOfWeek.year` ist der Fehler. `weekNumber` stammt korrekt aus `isoWeekNumber(startOfWeek)`. |
| `mobile/lib/domain/utils/iso_week.dart` | `isoWeekYear` bereits vorhanden und getestet (`test/domain/utils/iso_week_test.dart`). |
| `mobile/lib/presentation/widgets/weekly_reflection_dialog.dart` | Hält `year`/`week`, ruft `loadReflection(year, week)`. Titel nutzt nur `week`. |
| `mobile/lib/presentation/view_models/weekly_reflection_view_model.dart` | `loadReflection(year, week)` / `saveReflection`; guter Ort für Fallback-Logik, falls gewünscht. |
| `mobile/lib/domain/entities/weekly_reflection_entity.dart` | `id` = `'$year-W${week.padLeft(2,'0')}'` ist der Dokument-Schlüssel. |
| `mobile/lib/domain/repositories/weekly_reflection_repository.dart` + `data/repositories/weekly_reflection_repository_impl.dart` | Interface `getReflection(year, week)` / `saveReflection`; Impl delegiert 1:1 an die DataSource. |
| `mobile/lib/data/datasources/remote/firestore_datasource.dart` (462-503) | Eigentliche Persistenz (Pfad, Felder). |
| `mobile/lib/data/datasources/remote/api_data_source.dart` (110-121) | Delegiert Reflexion direkt an Firestore (kein Backend-Endpunkt). |
| `mobile/lib/core/providers/providers.dart` (194-204) | `weeklyReflectionRepositoryProvider` (null, wenn ausgeloggt). Kein `.g.dart`-Lauf nötig, solange die Signatur der Provider gleich bleibt. |
| `mobile/lib/core/services/pdf_report_service.dart` (151) | Dateiname `Wochenbericht_KW${weekNumber}_${startOfWeek.year}.pdf` hat denselben Jahresfehler (kosmetisch, siehe Offene Fragen). |
| `mobile/test/presentation/screens/reports_page_test.dart` (35-81, 245-263) | Bestehender Reflexions-Widgettest; `getReflection(any, any)`. Neuer Test mit fester Woche nötig. |
| `web/firestore.rules` (39-41) | Regel `weekly_reflections/{docId}` für Owner; keine Änderung nötig. |

## Ist-Zustand / Ursache

### Speicherung
- Nur eingeloggt, nur Firestore. Kein SharedPreferences/Local-Fallback, kein Hybrid-Repo
  (bewusst, siehe Doku im Repository-Interface). Ausgeloggt: `weeklyReflectionRepositoryProvider`
  = null, Reflexion lebt nur im Dialog-State.
- Pfad: `users/{uid}/weekly_reflections/{yyyy-Www}` (z. B. `2026-W11`). **Nicht profilgebunden**:
  kein `profileId`, kein Profil-Suffix; gilt unabhängig vom aktiven Arbeitszeit-Profil.
- Felder: `whatWentWell` (String), `whatWasHard` (String), `updatedAt` (Timestamp). `year`/`week`
  stehen **nicht** als Felder im Dokument, nur im Dokument-Id. Gelesen wird mit `year`/`week` aus
  dem Aufruf, nicht aus dem Dokument.
- Schreiben mit `set(..., SetOptions(merge: true))` -> ein zweites Speichern unter demselben
  Schlüssel überschreibt die beiden Textfelder, es entstehen keine Dubletten, aber stiller
  Überschreib-Datenverlust bei Schlüsselkollision.
- Über `ApiDataSource` laufen nur die Methoden-Delegationen an `FirestoreDataSource`; das .NET-Backend ist beteiligt nicht.

### Aufrufer
- Anzeige/Laden und Speichern: ausschließlich `WeeklyReflectionDialog` (über ViewModel) aus
  `reports_page.dart` Zeile 756. Einziger Aufrufer.
- Löschen: nicht vorhanden (weder Repo noch DataSource noch UI). Account-Löschung: nicht geprüft,
  ob `weekly_reflections` mit gelöscht wird (`deleteAccount` löscht nur den Auth-User, Rest
  vermutlich Backend/Firestore-Seite) – nicht Teil von #354.
- Export/PDF: PDF-Export enthält keine Reflexion. Nur der Dateiname trägt `startOfWeek.year`.
- `DataSyncService`: Reflexionen werden nicht synchronisiert/migriert (kein lokaler Speicher).

### Fehlerlage (rechnerisch geprüft, Python-Gegenprobe)
ISO-Wochenjahr und Montags-Kalenderjahr weichen **nur** ab, wenn der Montag auf den
29., 30. oder 31. Dezember fällt (Donnerstag liegt dann im Januar -> KW 1 des Folgejahres).
Dann wird `Y-W01` statt `(Y+1)-W01` verwendet. Betroffen ist also eine Woche in ca. 3 von 7
Jahren (nicht „3 Tage pro Jahr“: es ist eine ganze Woche, deren Montag zwischen 29.12.-31.12. liegt).

- KW 52/53 sind **nicht** falsch zugeordnet. Mo 28.12.2026 (KW 53/2026) hat Montagsjahr = ISO-Jahr = 2026.
  KW-53-Jahre erzeugen allein keinen Fehler; die Aussage im Issue zu „KW 53“ trifft nur insofern zu,
  als in 53-Wochen-Jahren der Dezember-Montag vor dem 29. liegt (kein Fehler).
- Auch Wochen mit Montag im Januar (1.-7.1.) sind richtig: Mo 1.-4.1. -> KW 1, Mo 5.-7.1. -> KW 2,
  immer ISO-Jahr = Kalenderjahr.

Betroffene Wochen (Montag -> ISO / falsch gespeichert unter):
| Montag | ISO-Woche | Alter Schlüssel | Kollision |
|---|---|---|---|
| 30.12.2024 | 2025-W01 | 2024-W01 | **ja**, mit der echten 2024-W01 (Mo 01.01.2024) |
| 29.12.2025 | 2026-W01 | 2025-W01 | nein |
| 31.12.2029 | 2030-W01 | 2029-W01 | **ja**, mit 2029-W01 (Mo 01.01.2029) |
| 30.12.2030 | 2031-W01 | 2030-W01 | nein |
| 29.12.2031 | 2032-W01 | 2031-W01 | nein |
| 31.12.2035 | 2036-W01 | 2035-W01 | **ja** |
| 29.12.2036 | 2037-W01 | 2036-W01 | nein |
| 31.12.2040 | 2041-W01 | 2040-W01 | **ja** (2040: Schaltjahr, beginnt Sonntag, erster Montag 02.01.) |

Kollisionsjahre = Jahre, die an einem Montag beginnen, sowie Schaltjahre, die an einem Sonntag
beginnen. Dort schreiben zwei verschiedene Wochen (Anfang Januar Y und Dezember-Montag Y) auf
dasselbe Dokument `Y-W01`; durch `merge: true` überschreibt die zweite die Textfelder der ersten
(Datenverlust, nicht unterscheidbar im Dokument).

Zeitleiste: Das Feature ist am 2026-09-16 eingecheckt (`git log -S weekly_reflections`, #236).
Heute 2026-10-03. Eine Altdatenlage gibt es nur, wenn jemand nach dem Release rückwirkend die
Woche 29.12.2025-04.01.2026 (alter Schlüssel `2025-W01`, **keine Kollision**) bearbeitet hat.
Die nächste fehlerhafte Woche ist 31.12.2029. Praktisch ist die Fehlerlage aktuell also
fast reine Zukunftsvorsorge; Altdaten sind höchstens vereinzelt vorhanden.

## Datenfluss
`ReportsPage` (WeeklyReportView) -> `WeeklyReflectionDialog(year, week)` ->
`WeeklyReflectionViewModel.loadReflection/saveReflection` -> `WeeklyReflectionRepository`
(`WeeklyReflectionRepositoryImpl`) -> `ApiDataSource` (delegiert) -> `FirestoreDataSource` ->
`users/{uid}/weekly_reflections/{yyyy-Www}`.

## Plattformübergreifend
**Nur Mobile.** Web und Backend nutzen die Reflexion nicht: keine Treffer für
`weekly_reflections`/Reflection in `web/src`, `web/functions`, `server/src` (nur Rule in
`web/firestore.rules`, die kein Format erzwingt). Es gibt also keine Web-Parität zu wahren und
keinen Konflikt über den Schlüssel. Der Web-Util `shared/utils/iso-week.util.ts` hat bereits
`getIsoWeekYear`; sollte Web die Reflexion später portieren, den ISO-Schlüssel `yyyy-Www` mit
ISO-Jahr übernehmen. Das Schlüsselformat wird als Vertrag in der Kurzfassung festgehalten
(Doc-Kommentar im Entity), kein Web-/Backend-Eingriff jetzt.
Firestore Rules: keine neuen Pfade -> keine Änderung.

## Migrationsoptionen
**(a) Kein Migrieren, nur neuer Schlüssel + Lesen mit Fallback auf alten Schlüssel**
- Nur nötig für Wochen mit ISO-Woche 1 und Montag im Dezember (alter Schlüssel `(iy-1)-W01`).
  Fallback nur dann lesen, wenn neuer Schlüssel nicht existiert.
- In **Kollisionsjahren** ist der alte Schlüssel mehrdeutig (gehört der Text zur Januar- oder zur
  Dezember-Woche?). Dort Fallback weglassen (oder nur über `updatedAt`-Heuristik; nicht empfohlen).
  Einzig reale Altdaten-Kandidatin (29.12.2025) ist eindeutig.
- Vorteil: keine Schreibzugriffe, nichts zu verlieren, einfach testbar. Nachteil: alter Datensatz
  bleibt als Karteileiche (`2025-W01`); Fallback-Code bleibt dauerhaft (oder bis bewusst entfernt).
- Gemischte App-Versionen: ein Altclient schreibt weiter `2025-W01` -> Neuclient liest per Fallback
  (nur solange der neue Schlüssel fehlt).

**(b) Einmalige Migration** (alle `weekly_reflections` laden, falsch zugeordnete nach neuem
Schlüssel kopieren/löschen)
- Müsste bei jedem eingeloggten Nutzer einmal laufen (Flag in SharedPreferences o. Ä.), liest die
  ganze Collection, ist in Kollisionsjahren ebenfalls mehrdeutig, kann bei Fehlern/Abbruch halb
  migrieren und Dubletten oder Verlust erzeugen. Hoher Aufwand für maximal eine Woche pro Nutzer.

**(c) Beides**: unnötig, doppelte Komplexität.

**Empfehlung: (a) in schlanker Form.** Schlüssel auf ISO-Jahr umstellen; Lesen mit Fallback nur
für `week == 1` und Montag im Dezember und nicht in Kollisionsjahren; kein Schreib-Migrationslauf,
kein Löschen des alten Dokuments. Alternativ (noch schlanker) bewusst ganz auf Fallback verzichten
und im Plan festhalten, weil Feature erst seit 2026-09 existiert und nur die Woche 29.12.2025 als
Altdaten in Frage kommt. Entscheidung dem Nutzer überlassen (Frage 1).

## Umsetzungsskizze (nur zur Orientierung für Phase 2, kein Code)
- `reports_page.dart`: `year: isoWeekYear(startOfWeek)`; `weekNumber` bleibt.
- Für den Fallback muss das Jahr des alten Schlüssels (`startOfWeek.year`) bekannt sein: entweder
  `legacyYear` an Dialog/ViewModel durchreichen oder `loadReflection` bekommt das Montagsdatum.
- Tests (datumsunabhängig, feste Daten): Dialog erhält `year == 2026` bei Montag 2025-12-29; Entity-Id
  `2026-W01`; Kollisionsjahr 2024/2025-Paar bekommt verschiedene Schlüssel (`2024-W01` vs `2025-W01`);
  Fallback-Test (neuer Schlüssel leer, alter vorhanden -> alter Text); kein Fallback in Kollisionsjahr.

## Offene Fragen
1. Fallback für Altdaten (Option a) oder bewusst ganz ohne? Empfehlung: schlanker Fallback (nur KW 1 + Dezember-Montag + kein
   Kollisionsjahr), keine Schreib-Migration. Falls Ihr bestätigt, dass vor dem Release keine Reflexion für die Woche 29.12.2025
   gespeichert werden konnte (Release-Datum von #236 prüfen), ist auch „kein Fallback“ vertretbar.
2. PDF-Dateiname `Wochenbericht_KW${weekNumber}_${startOfWeek.year}.pdf` mit ISO-Jahr korrigieren (`KW01_2025` statt
   `KW01_2026` für die Woche 29.12.2025)? Empfehlung: ja, im selben PR (eine Zeile + Test in `pdf_report_service_test.dart`,
   Signatur bräuchte `isoYear` oder berechnet aus `startOfWeek`). Alternativ eigenes Issue.
3. `loadReflection`-Signatur: `(year, week)` beibehalten und Fallback-Jahr separat durchreichen, oder auf das Montagsdatum
   umstellen? Empfehlung: Fallback-/Schlüsselberechnung im ViewModel aus dem Montagsdatum, damit Aufrufer nicht selbst
   `isoWeekYear` nennen müssen (verhindert den Fehler an der Wurzel).
4. Soll das Schlüsselformat als Vertrag für Web im Entity-Doc-Kommentar stehen (ISO-Jahr!) und `web/CLAUDE.md`/Root-Tabelle
   um den Pfad `users/{uid}/weekly_reflections/{yyyy-Www}` ergänzt werden? Empfehlung: ja, Root-`CLAUDE.md`-Tabelle kennt den Pfad
   bisher nicht (nur Doc-Änderung).

## Risiken
- Kollisionsjahre (2024/2025, 2029/2030, 2035/2036, 2040/2041): alter Schlüssel mehrdeutig; Fallback dort falsch positiv
  (zeigt Text der falschen Woche) -> Fallback dort aussparen.
- Fallback und späteres Speichern: nach dem ersten Speichern existiert der neue Schlüssel, der alte bleibt liegen;
  kein Datenverlust, aber Verwaiste Dokumente (harmlos).
- `merge: true` + Altclients: ein nicht aktualisierter Client schreibt weiter unter dem alten Schlüssel.
- Tests dürfen nicht von `now` abhängen: der bestehende Test `reports_page_test.dart` nutzt `DateTime.now()`-abhängige Woche;
  neue Tests mit festem Datum (`selectedDay`) schreiben.
- Dialog-Titel zeigt nur die Wochenzahl; bei KW 1 im Dezember sieht der Nutzer „KW 1“ im Dezember (korrekt nach ISO,
  ggf. irritierend, kein Teil dieses Issues).

## Entscheidungen zu den offenen Fragen (Hauptsession)

1. **Altdaten:** Kein Lesefallback und keine Migration. Das Feature existiert erst seit #236 (2026-09-16); ein Altbestand ist nur denkbar, wenn jemand rückwirkend die Woche 29.12.2025 bearbeitet hat. Ein Fallback wäre in Kollisionsjahren mehrdeutig und mehr Code als der Nutzen rechtfertigt. In der PR-Beschreibung als bewusster Verzicht vermerken (inkl. Korrektur der Issue-Aussage: KW 52/53 waren nicht falsch zugeordnet, nur Montage am 29.–31.12. mit KW 1).
2. **PDF-Dateiname** `Wochenbericht_KW${weekNumber}_${startOfWeek.year}.pdf` im selben PR auf das ISO-Wochenjahr korrigieren (eine Zeile plus Test).
3. **`loadReflection`/Speichern:** Schlüssel (`isoWeekYear` + `isoWeekNumber`) wird im ViewModel aus dem Montagsdatum berechnet, nicht vom Aufrufer übergeben.
4. **Doku:** Root-`CLAUDE.md`-Pfadtabelle um `users/{uid}/weekly_reflections/{yyyy-Www}` (ISO-Wochenjahr) ergänzen, dazu Doc-Kommentar am Entity.
Tests mit festen Daten (Mo 2025-12-29, Mo 2024-12-30, Mo 2024-01-01), nicht von `DateTime.now()` abhängig.
