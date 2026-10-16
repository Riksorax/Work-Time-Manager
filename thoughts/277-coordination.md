# #277 Home-Office-Flag (Free) und #282 Home-Office-PDF (Premium) - Koordinationsplan

Plattformen: #277 Backend + Web + Mobile, #282 nur Mobile. Ziel-Release 1.7.0 (aktuell `pubspec.yaml` 1.6.7). Code-Stand: `develop` (68f3ec6). Beide Issues ohne Kommentare, #282 hängt an #277.

## 1. Befunde im Ist-Zustand

- **Backend:** `DayData` (days-Map-Eintrag, `Firestore/Documents/DayData.cs`) kennt `date, workStart, workEnd, type, isManuallyEntered, manualOvertimeMinutes, description, breaks`. `FirestoreMappings.ToDto/ToDocument` (WorkEntryDto <-> DayData). `WorkEntryRepository.SaveAsync` schreibt `days.{key}` per `SetOptions.MergeAll` (Merge auf Blattfelder-Ebene). Reports (`ReportEndpoints`/`ReportDtos`) kennen nur Zeiten/Tage, kein Ort.
- **Web:** `WorkEntry` in `web/src/app/shared/models/index.ts` (kein `work-entry.ts` im Modellordner, das Issue nennt den Pfad ungenau). Zwei Pfade lesen/schreiben Einträge: Firestore direkt in `web/src/app/core/services/work-entry.ts` (Zeilen ~178, ~258, ~279) und über die API in `core/services/api-client.ts` (DTO + Mapping, ~26, ~223, ~244). Beide müssen das Feld führen.
- **Mobile:** `WorkEntryEntity` (`domain/entities/work_entry_entity.dart`, `copyWith`, Equatable `props`), `WorkEntryModel` (`data/models/work_entry_model.dart`: `fromMap`/`toMap`/`copyWith`), API-Mapping `data/datasources/remote/api_client.dart` (`_entryToJson` ~170, Parsing ~218), lokales Repo `data/repositories/local_work_repository_impl.dart` (~51/~71, SharedPreferences-JSON). `work_entry_extensions.dart` enthält nur Berechnungen, das Flag braucht dort nichts.
- **PDF (Mobile):** `core/services/pdf_report_service.dart` (290 Zeilen) hat `exportWeeklyReport/MonthlyReport/YearlyReport`, `_loadTheme` (Open Sans, Umlaute), `_header`, `_summaryTable`, `_monthlyTable`, `Printing.sharePdf`. Aufruf aus `presentation/screens/reports_page.dart` (Top-Level `_pdfReportService`, `_export*Pdf`-Funktionen, Premium-Gate per `ref.watch(isPremiumProvider)`). Texte `pdf*` in ARB. Wiederverwendung ist gut möglich.
- **Web hat keinen PDF-Export** (kein pdf-Paket, keine Export-Komponente).
- **Security Rules:** `work_entries/{entryId}` ist `isOwner`-basiert ohne Feldliste (Root und `profiles/{id}`). **Kein Regel-Änderungsbedarf, kein Rules-Deploy.**
- **Kritisches Risiko (Datenverlust durch alte Clients):** Ausgelieferte Apps (1.6.x) und Web ohne Flag senden das Feld nicht. Wird `IsHomeOffice` im Backend als nicht-nullable `bool` gemappt, schreibt jeder Save eines alten Clients `false` und löscht damit das Flag. Siehe 2.3.

## 2. Gemeinsamer Vertrag (#277)

### 2.1 Datenfeld

| Ebene | Festlegung |
|---|---|
| Entscheidung Modell | **`isHomeOffice` (bool)**, kein Enum `location`. Begründung: Issue-Motivation ist eine reine Zählung Büro/Home-Office, YAGNI. Ein späterer Enum (z. B. "unterwegs") wäre dann ein neues, additives Feld, kein Breaking Change. Nur sinnvoll an `type == work`; bei `vacation/sick/holiday` ignorieren die Clients das Feld (kein Löschen, keine Anzeige, keine Zählung). |
| Firestore | `users/{uid}/work_entries/{yyyy-MM}` bzw. `.../profiles/{profileId}/work_entries/{yyyy-MM}`: `days.{d}.isHomeOffice` (bool). **Feld fehlt = false.** Kein neuer Pfad, keine Migration, Dokumentgröße vernachlässigbar. |
| Backend `DayData` | `[FirestoreProperty("isHomeOffice")] bool? IsHomeOffice` (nullable, siehe 2.3) |
| Backend `WorkEntryDto` | `bool? IsHomeOffice { get; init; }`, JSON `isHomeOffice`. GET: `true` oder `false`/`null` bei Bestandsdaten, Clients lesen `null` als `false`. Besser: `ToDto` liefert `day.IsHomeOffice ?? false` (GET immer ein bool, PUT darf `null` senden). |
| Web `WorkEntry` | `isHomeOffice?: boolean` (optional, Default `false` beim Lesen) |
| Web `ApiClient` DTO | `isHomeOffice?: boolean \| null` |
| Mobile `WorkEntryEntity` | `final bool isHomeOffice` (Default `false`), in `props` und `copyWith` aufnehmen |
| Mobile `WorkEntryModel.toMap` | `'isHomeOffice': isHomeOffice` immer schreiben (Mobile kennt das Feld, also darf es auch `false` schreiben). `fromMap`: `map['isHomeOffice'] as bool? ?? false` |
| Mobile lokal (`local_work_repository_impl`) | JSON-Feld `isHomeOffice`, fehlend = `false` |

### 2.2 days-Map-Kompatibilität

- Flutter-kanonisches Format bleibt: days-Map-Schlüssel ohne führende Null, Zeiten als `Timestamp`. Zusatzfeld ist ein einfacher bool im Tages-Map. **Ältere Flutter-Versionen** lesen das Dokument unverändert (`fromMap` ignoriert unbekannte Schlüssel). **Aber:** schreibt ein alter Client (Mobile direkt per Firestore-`set` des ganzen Tages oder per API) einen Tag, bleibt das Feld nur erhalten, wenn der Write per Merge erfolgt. Mobile (Firestore-Direktpfad) ersetzt den Tag laut `toMap` vollständig oder merged je nach Datasource. Das ist im Mobile-Teil-PR zu prüfen (`firestore_datasource`/`api_client`) und mit Test abzusichern. Dokumentiert akzeptierte Restlücke: ein Edit eines Home-Office-Tages mit einer alten App-Version kann das Flag verlieren (Kosmetik, keine Rechendaten). Hinweis ins Release-Changelog.
- Breaks `{ name, start, end }` und alle übrigen Felder unverändert.

### 2.3 Backend-FirestoreMappings und PUT-Semantik (kritisch)

- `ToDto(DayData, id)`: `IsHomeOffice = day.IsHomeOffice ?? false`.
- `ToDocument(WorkEntryDto)`: `IsHomeOffice = dto.IsHomeOffice`. **Wenn das Feld im PUT fehlt (`null`), darf es nicht als `null`/`false` in den Tag geschrieben werden**, sonst überschreibt ein alter Client (oder alte Web-Version) das gespeicherte `true`. Umsetzung im Backend-Teil-PR: `SaveAsync` baut für `isHomeOffice == null` das Feld nicht in die geschriebene days-Map ein (z. B. Schreiben über `MergeFields` ohne `days.{key}.isHomeOffice`, analog zum Nullable-Muster `SettingsMergeFields` aus #278/#279) oder entfernt den Key aus dem Dictionary. `false` und `true` werden geschrieben.
- Folge: Ein Client kann das Flag nur durch explizites `false` löschen (gewollt). Neue Clients senden immer `true`/`false`.
- Zu testen (ohne Datumsabhängigkeit, feste Daten): GET-Mapping fehlend -> `false`; PUT ohne Feld lässt vorhandenes `true` unangetastet; PUT `true` setzt; PUT `false` löscht; Profilpfad (`?profileId=`); Flutter-Format (Schlüssel ohne führende Null, `Timestamp`); Roundtrip des Bestandsdokuments ohne Feld bleibt feldfrei.
- **Reports:** Für #277 keine Backend-Reportänderung. Rechenlogik unberührt (Home-Office beeinflusst weder Soll, Pausen noch Überstunden). Backend bleibt kanonisch; eine optionale Aggregation (`homeOfficeDays`) ist für #282 **nicht** nötig (Mobile rechnet lokal aus den Monatseinträgen). Falls später Web-Auswertung kommt, additiv `HomeOfficeDays` in `MonthlyReportDto`.

### 2.4 Mandanten-/Profil-Bezug

Das Flag liegt am Eintrag und folgt damit automatisch dem aktiven Arbeitszeit-Profil (`profiles/{profileId}/work_entries`). Kein eigenes Setting. Auswertungen (#282) gelten je aktivem Profil.

### 2.5 UI-Vertrag (Parität)

- Erfassen/Bearbeiten: Toggle/Chip "Home-Office" im Edit-Dialog (Mobile + Web) und im Dashboard (heutiger Eintrag; Web `DashboardService`, Mobile `DashboardViewModel`, Änderung zählt als Eintragsänderung und läuft über `WorkEntryService`/Hybrid-Repository, nie daran vorbei). Das Flag ist während laufendem Timer setzbar.
- Anzeige im Kalender/Reports: Icon (Haus) und/oder Farbmarkierung am Tag, bei Typ `work` und `isHomeOffice`. Barrierefrei: Semantics-/Aria-Label "Home-Office", nicht nur Farbe.
- Schnelleintrag/Mehrfachauswahl (Web, #377): Batch-Dialog darf `isHomeOffice` setzen oder nicht anfassen. Empfehlung: nicht anfassen (bestehendes Flag bleibt), Toggle nur im Einzel-Edit. Siehe offene Frage 3.

### 2.6 Texte DE/EN

Neue Texte in `mobile/lib/l10n/app_de.arb` + `app_en.arb` und `web/public/i18n/de.json` + `en.json`: "Home-Office" / "Home office", Toggle-Label "Von zu Hause gearbeitet" / "Worked from home", Aria "Home-Office-Tag" / "Home office day". Duzen. Kalender-Legende falls vorhanden ergänzen.

## 3. Vertrag #282 (Mobile-first)

- Neue Methode `PdfReportService.exportHomeOfficeReport({l10n, locale, periodLabel, homeOfficeDays, officeDays, totalWorkDays, ratio, perMonth?})`. Bestehende Helfer (`_loadTheme`, `_header`, `_summaryTable`, `_monthlyTable`) wiederverwenden. Dateiname `Home-Office-Auswertung_<Zeitraum>.pdf`.
- **Zählregel (muss eindeutig sein):** Bezugsmenge = Tage mit `type == work` (und mindestens eine erfasste Arbeitszeit oder `isManuallyEntered`-Eintrag; Urlaub/Krank/Feiertag zählen weder als Büro noch als Home-Office). Home-Office-Tage = Bezugsmenge mit `isHomeOffice`, Büro-Tage = Rest. Verhältnis = Home-Office-Tage / Bezugsmenge (Prozent, eine Nachkommastelle, bei 0 Tagen "-"). Reine Funktion in `domain/utils` (z. B. `home_office_stats.dart`) mit festen Testdaten (zeitzonenunabhängig, Kalendertage als lokale Y/M/D).
- Zeitraum: Monat und Jahr (Akzeptanzkriterium). Jahr = 12 Monatszeilen, Monat = Tagesliste der Home-Office-Tage.
- Premium-Gate wie die bestehenden Exportbuttons in `reports_page.dart` (`isPremiumProvider`); Free-Nutzer sehen den gesperrten Bereich wie bei den anderen Premium-Reports. Kein Backend, kein Endpunkt, keine Rules.
- Texte: neue `pdfHomeOffice*`-Keys in ARB de+en.

## 4. Entscheidung Web-PDF-Scope (#282)

**Empfehlung: #282 bleibt Mobile-only in 1.7.0. Web-PDF ist ausdrücklich kein Teil.**
Begründung: Web hat keinerlei PDF-Infrastruktur (neue Abhängigkeit, Font-Einbettung für Umlaute, Layout, Tests, Bundle-Größe), dieselbe Lücke betrifft #284 (Urlaub/Krank-PDF) und die bestehenden Wochen-/Monats-/Jahres-PDFs; sie sollte einmal grundsätzlich als eigenes Issue "Web: PDF-Export-Infrastruktur" gelöst werden (Optionen: `pdfmake`/`jspdf`, `window.print()` mit Print-CSS als billigster Weg, oder serverseitig im Backend, das wäre auch der einzige Weg zu identischer Ausgabe). Web zeigt Home-Office-Tage aus #277 im Kalender; eine Zahl "Home-Office-Tage im Monat" kann im Web-Report-Block ergänzt werden (optional, aus #277-Datenstand, kein PDF). Folge-Issue anlegen und in #282 verlinken. Premium-Parität: Web-Nutzer erhalten die PDF-Auswertung erst mit dem Folge-Issue, das ist im Release-Text zu erwähnen.

## 5. Reihenfolge und Teil-PRs

Alle Branches gegen `develop`, jeder PR "Refs #277" (bzw. "Refs #282"), Eltern-Issue #277 erst nach PR 3 schließen, #282 nach PR 4.

| # | Branch | Inhalt | Abhängigkeit / Check |
|---|---|---|---|
| 1 | `feature/277-homeoffice-api` | `DayData.IsHomeOffice`, `WorkEntryDto.IsHomeOffice`, `FirestoreMappings` (siehe 2.3, Null-Schutz im `SaveAsync`), Tests, `server/CLAUDE.md`-Endpunkt-/Feldtabelle | zuerst. `dotnet build WorkTimeManager.slnx -c Release && dotnet test WorkTimeManager.slnx -c Release` |
| 2 | `feature/277-homeoffice-web` | `WorkEntry`-Modell, `work-entry.ts` + `api-client.ts` (Lesen/Schreiben), Edit-Dialog-Toggle, Dashboard-Toggle, Kalender-/Report-Markierung, i18n de+en, Specs (TZ-unabhängig, Läufe unter `TZ=Europe/Berlin`) | PR 1. `npm test -- --watch=false && npm run build -- --configuration production` |
| 3 | `feature/277-homeoffice-mobile` | Entity/Model/Repo-Mapping (Firestore, API, lokal), Dashboard-/Edit-Toggle, Kalender-/Reports-Markierung, ARB de+en, Tests, ggf. `build_runner` | PR 1 (API-Feld). Mobile-Checks laut CLAUDE.md inkl. `*_tz_test.dart` |
| 4 | `feature/282-homeoffice-pdf-mobile` | `home_office_stats.dart`, `exportHomeOfficeReport`, Export-Button + Premium-Gate in `reports_page.dart`, ARB, Tests (Zählregel, PDF-Aufbau soweit testbar, Gate) | PR 3 gemerged (Flag in Mobile-Daten). Mobile-Checks |

Web (PR 2) und Mobile (PR 3) können nach Merge von PR 1 parallel laufen; PR 4 strikt nach PR 3. Laut Session-Praxis nacheinander, nach jedem Merge neu von `develop`.

## 6. Paritätstabelle

| Aspekt | Backend | Web | Mobile |
|---|---|---|---|
| Datenfeld / Pfad | `DayData.IsHomeOffice` -> `days.{d}.isHomeOffice` (Root + `profiles/{id}`) | `WorkEntry.isHomeOffice`, Firestore- und API-Pfad | `WorkEntryEntity.isHomeOffice`, Firestore-/API-/Lokal-Mapping |
| Endpunkt genutzt | `GET/PUT /work-entries` (DTO-Feld additiv, Null = unangetastet) | `ApiClient` + direkter Firestore-Pfad | `ApiClient` + Firestore-Direktpfad + lokal |
| Rechenregel identisch | keine Rechenlogik betroffen; Zählregel Home-Office nur in #282 | nur Anzeige | #282: lokale Zählregel (3.), Backend nicht beteiligt |
| Feature-Gate | - (Free) | keines (#277) | #277 keines, #282 `isPremiumProvider` |
| Texte (de + en) | - | `de.json`, `en.json` | `app_de.arb`, `app_en.arb` |
| Mandanten-/Profil-Bezug | `profileId` auf Einträgen vorhanden | `activeProfileIdForApi` | Profil-Pfad bestehend |
| PDF | - | **nicht im Scope** (Folge-Issue) | #282 |
| Security Rule | - | keine Änderung | keine Änderung |

## 7. Ist #282 in 1.7.0 realistisch?

**Ja, bedingt.** Aufwand #282 ist klein bis mittel (ein PR, Muster existiert dreifach, Infrastruktur + Fonts + Gate vorhanden, kein Backend/Web). Der kritische Pfad ist #277 (drei PRs, Backend zuerst) und danach der strikt sequenzielle PR 4. Realistisch, wenn #277 Backend + Mobile zügig durch sind; Web (PR 2) liegt nicht auf dem kritischen Pfad für #282 und kann parallel laufen. Fällt 1.7.0 knapp, ist die Reihenfolge der Kürzung: erst Web-Teil von #277, dann Kalender-Feinschliff, #282 zuletzt. Voraussetzung: Release-Termin und weitere 1.7.0-Inhalte (offene Frage 1) klären; im Repo ist kein Milestone/Label dafür erkennbar.

## 8. Deploy-Hinweise für `/release` (1.7.0)

- API vor Web und Mobile ausrollen (Push `main` -> `deploy-api.yml`). Alte Clients bleiben durch Null-Schutz (2.3) kompatibel.
- Keine Rules-Deploys, keine Secrets, keine Datenmigration (fehlendes Feld = false).
- Changelog/`whatsnew`: Hinweis, dass ältere App-Versionen das Home-Office-Flag beim Bearbeiten eines Tages verlieren können (2.2); Home-Office-PDF nur in der App.
- Version-Bump 1.6.7 -> 1.7.0 in `mobile/pubspec.yaml` (laut `/release`).

## 9. Offene Fragen mit Empfehlung

1. Release-Scope/Termin 1.7.0: welche weiteren Issues sind drin? Empfehlung: #277 komplett + #282 Mobile, Rest nachrangig.
2. Bool statt Enum `location` (Issue lässt beides offen)? Empfehlung: bool (2.1).
3. Batch-/Schnelleintrag (Web Mehrfachauswahl): Flag setzbar? Empfehlung: nein in v1, Bestehendes bleibt erhalten.
4. Home-Office an Tagen mit Typ `vacation/sick/holiday`: Flag ignorieren und nicht zählen? Empfehlung: ja (2.1/3.).
5. Zählung #282: nur `work`-Tage mit erfasster Arbeitszeit als Bezugsmenge? Empfehlung: ja (3.).
6. Web-PDF als eigenes Folge-Issue (zusammen mit #284)? Empfehlung: ja, Entscheidung 4.
7. Restlücke alter Clients (Flag-Verlust beim Edit) akzeptieren? Empfehlung: ja, nur Kosmetik, im Changelog erwähnen.

## 10. Erster Workflow

Backend: `/analysieren 277 dotnet` bzw. `/umsetzen 277 dotnet` auf Branch `feature/277-homeoffice-api` (Scope 2.1 bis 2.3, Tests). Danach `/analysieren 277 angular` und `/analysieren 277 flutter` parallel.
