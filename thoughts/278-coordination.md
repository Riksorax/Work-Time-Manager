# #278 Urlaubs-/Krankheitstage mit Kontingent (Resturlaub) - Koordinationsplan

Plattformen: Backend, Web, Mobile. Free-Feature (kein Premium-Gate). Basis: Issue #278 (keine Kommentare), Code-Stand `develop` (25fb01a).

## 1. Befunde im Ist-Zustand

- `WorkEntryType` (`work|vacation|sick|holiday`) existiert auf allen Plattformen. `WorkEntryDto.Type` ist ein String (`"work"` Default).
- **Mobile** zählt Urlaub/Krank/Feiertag je Monat bereits in `domain/utils/yearly_report_utils.dart` (`MonthSummary.vacationDays/sickDays`), `YearlyReportState.totalVacationDays/totalSickDays`, Anzeige in `reports_page.dart` (Jahresreport, `vacationDaysLabel`/`sickDaysLabel`). Es fehlt nur Anspruch und Rest.
- **Backend** `ReportCalculator` kennt Typen nur als `Type != "work"` (zählt als Soll-Tag), keine Zählung je Typ. `SettingsDto` hat kein Urlaubsfeld. `ProfileDto` ist nur `Uid` + `IsPremium` (das Issue nennt es, es ist aber der falsche Ort, siehe 2.1).
- **Web** hat keinen Jahresreport (Reports: Tag/Woche/Monat über `ApiClient`). `UserSettings` (`shared/models/index.ts`) hat kein Urlaubsfeld.
- **Settings-Speicherung:** Web liest per `onSnapshot` `users/{uid}/settings/current` und schreibt per `PUT /settings` (ganzes DTO). Mobile hält Settings in SharedPreferences und synchronisiert über `ApiDataSource.saveSettings` (Read-Modify-Write gegen die API, schreibt `{...current, ...neu}`) nach Firestore; `syncFromFirestore()` liest beim Login aber **nur** `weeklyTargetHours` und `workdays` zurück.

## 2. Gemeinsamer Vertrag

### 2.1 Datenfeld (Settings, nicht Profil)

| Ebene | Festlegung |
|---|---|
| Firestore | `users/{uid}/settings/current` bzw. `users/{uid}/profiles/{profileId}/settings/current`, Feld **`vacationDaysPerYear`** (int, ganze Tage, 0-366). Fehlt das Feld: effektiv **30**. Kein neuer Pfad, keine Migration. |
| Backend `SettingsDocument` | `[FirestoreProperty("vacationDaysPerYear")] int? VacationDaysPerYear` (nullable, damit "nie gesetzt" erkennbar bleibt) |
| Backend `SettingsDto` | `int VacationDaysPerYear { get; init; } = 30;` in `GET`. Für `PUT` siehe 2.2. JSON: `vacationDaysPerYear`. |
| Web `UserSettings` | `vacationDaysPerYear: number`, Default 30 in `SettingsService.defaultSettings` |
| Mobile `SettingsEntity` | `int vacationDaysPerYear` (Default 30), SharedPreferences-Key `vacation_days_per_year_$_userId$_profileSuffix` (analog `workdays_...`) |

`ProfileDto` bleibt unverändert (Abweichung vom Issue-Hinweis, bewusst: das ist der Premium-/Uid-Datensatz, der Anspruch ist eine pro Arbeitszeit-Profil geltende Einstellung und gehört zu `settings/current`).

Der Anspruch gilt je Arbeitszeit-Profil (`?profileId=`), wie alle Settings. Zählung ebenfalls je Profil (Einträge des Profils).

### 2.2 Abwärtskompatibilität (kritisch)

Alte Web-/Mobile-Clients senden das Feld nicht. `SettingsRepository.SaveAsync` nutzt `SetOptions.MergeAll`; ein nicht-nullbarer Default 30 im DTO würde einen gespeicherten Wert (z.B. 25) bei jedem Speichern eines alten Clients zurück auf 30 setzen.
Festlegung: Im **PUT-Pfad** ist das Feld optional (`int?`-Eingang bzw. Deserialisierung mit Nullable). Ist es `null`, bleibt das gespeicherte Feld unangetastet (Wert aus dem Bestandsdokument übernehmen oder Feld aus dem Merge-Dokument weglassen). Das Backend validiert `0 <= v <= 366`, sonst `400`. Zu testen: PUT ohne Feld überschreibt nicht (Unit-/Integrationstest in `FirestoreMappingsTests`/`RepositoryIntegrationTests`).
Mobile: `ApiDataSource.saveSettings` merged `current` mit der Änderung, Backend muss das Feld also durchreichen (deshalb Backend zuerst).

### 2.3 Rechenregel (Backend kanonisch)

Für Kalenderjahr `Y` (lokales Datum des Eintrags, `Date.Year == Y`), Profil `P`:

- `vacationTaken` = Anzahl Einträge mit `Type == "vacation"` (ein Eintrag = ein Tag, gezählt wird jeder `vacation`-Eintrag, unabhängig von Wochentag/Arbeitstag-Setting. So rechnet Mobile heute schon, keine Halbtage).
- `sickDays` = Anzahl Einträge mit `Type == "sick"`.
- `vacationRemaining` = `vacationDaysPerYear - vacationTaken` (darf **negativ** werden, wird als Überschreitung angezeigt, nicht auf 0 geklemmt).
- Kein Übertrag, keine anteilige Berechnung. Jahreswechsel entsteht von selbst, weil nur Jahr `Y` gezählt wird. Vergangene Jahre werden gegen den *aktuellen* Anspruch gerechnet (v1-Einschränkung, Anspruch ist nicht pro Jahr versioniert).
- `holiday` zählt nicht zum Urlaub.

### 2.4 API (additiv)

Neuer Endpunkt: `GET /reports/yearly/{year}?profileId=` (Validierung `year 2000..2100`, wie `IsValidMonth`) liefert

```json
{ "year": 2026, "vacationDaysPerYear": 30, "vacationDaysTaken": 12,
  "vacationDaysRemaining": 18, "sickDays": 3 }
```

DTO `YearlyLeaveReportDto` (Name offen) in `Contracts/ReportDtos.cs`, Logik als `ReportCalculator.CalculateYearlyLeave(IReadOnlyList<WorkEntryDto> yearEntries, int year, SettingsDto settings)`. Dafür braucht `WorkEntryRepository` eine Jahresabfrage (12 Monatsdokumente `users/{uid}/work_entries/{yyyy-MM}` lesen; `GetMonthAsync` existiert).
Bestehende Endpunkte (`daily|weekly|monthly`) bleiben unverändert.

### 2.5 Firestore Security Rules

**Kein Änderungsbedarf** in `web/firestore.rules`: `settings/{doc}` (Root und unter `profiles/{profileId}`) und `work_entries` sind bereits abgedeckt. Kein neuer Pfad. Kein manuelles Rules-Deploy nötig.

### 2.6 Texte (DE/EN, Web: `public/i18n/de.json|en.json`, Mobile: `lib/l10n/app_de.arb|app_en.arb`)

Neue Schlüssel (gleiche Semantik, plattformspezifische Benennung):
- Einstellung: "Urlaubsanspruch pro Jahr" / "Vacation days per year" (+ Hinweis "in Tagen", Validierung 0-366)
- "Resturlaub" / "Remaining vacation", "Genommen" / "Taken", "von {total} Tagen" / "of {total} days"
- Überschreitung: "{n} Tage über dem Anspruch" / "{n} days over entitlement"
- "Kranktage {Jahr}" / "Sick days {year}" (Mobile hat `sickDaysLabel`/`vacationDaysLabel` bereits, wiederverwenden)
- Pluralformen in ARB per ICU (`{n, plural, ...}`), Web per ngx-translate-Parameter.

## 3. Reihenfolge und Teil-PRs (je Branch gegen `develop`, jeder PR verweist auf #278)

| # | Branch | Inhalt | Abhängigkeit |
|---|---|---|---|
| 1 | `feature/278-urlaub-api` | `SettingsDocument`/`SettingsDto`/`FirestoreMappings` (inkl. PUT-Null-Schutz, Validierung), `WorkEntryRepository` Jahresabfrage, `ReportCalculator.CalculateYearlyLeave`, `GET /reports/yearly/{year}`, Tests (inkl. Jahreswechsel-Grenze 31.12./01.01 mit festem Datum, negativer Rest, Profil, Default 30, PUT ohne Feld) | keine, **zuerst**. Check: `dotnet build/test WorkTimeManager.slnx -c Release` |
| 2 | `feature/278-urlaub-web` | `UserSettings` + Default, Settings-UI-Feld, `ApiClient.getYearlyLeave`, Anzeige Resturlaub im Dashboard (Karte) und Settings, Kranktage-Summe in den Reports, i18n de+en, Specs | PR 1 (Endpunkt + Feld). Check: `npm test -- --watch=false && npm run build -- --configuration production` |
| 3 | `feature/278-urlaub-mobile` | `SettingsEntity`/`SettingsRepository(Impl)`/`settings_view_model.dart` (Feld, SharedPreferences, `_syncToFirestore`, `syncFromFirestore` um `vacationDaysPerYear` erweitern), reine Funktion in `domain/utils` (z.B. `leave_balance_utils.dart`) für Rest aus den bereits geladenen Jahres-`MonthSummary`, Anzeige Settings + Dashboard + Kranktage im Jahresreport (existiert), ARB de+en, Tests, ggf. `build_runner` | PR 1 für Sync-Feld. Rechnung kann offline lokal laufen (Hybrid), muss mit Backend-Regel 2.3 übereinstimmen. Check: Mobile-Checks laut CLAUDE.md |

Web und Mobile können nach Merge von PR 1 parallel laufen. Mobile-Rechenlogik lokal (Offline-Fähigkeit der Hybrid-Layer, kein harter Endpunkt-Zwang), Web nutzt den Endpunkt.
Hinweis Workflow: Unter-Issues je Plattform bei Bedarf anlegen. Teil-PRs "Refs #278", Eltern-Issue erst nach PR 3 schließen.

## 4. Paritätstabelle

| Aspekt | Backend | Web | Mobile |
|---|---|---|---|
| Datenfeld / Pfad | `vacationDaysPerYear` in `settings/current` (Root + `profiles/{id}`) | gleiches Feld über `SettingsService` (onSnapshot lesen, PUT schreiben) | SharedPreferences + Sync über API nach Firestore; `syncFromFirestore` erweitert |
| Endpunkt genutzt | `GET /reports/yearly/{year}`, `PUT /settings` | `ApiClient` (Yearly + Settings) | Settings über `ApiDataSource`; Rest lokal berechnet |
| Rechenregel identisch | `CalculateYearlyLeave` (kanonisch) | nutzt Backend-Ergebnis | lokal gleiche Regel (Anspruch minus `vacation`-Einträge im Kalenderjahr, kann negativ sein, `holiday` nicht gezählt) |
| Premium-Gate | - (Free) | keines | keines |
| Texte de + en | - | `public/i18n/de.json`, `en.json` | `app_de.arb`, `app_en.arb` |
| Arbeitszeit-Profile | `profileId` auf Settings + Yearly | `activeProfileIdForApi` | `_profileSuffix` im Pref-Key, Profil an Sync |
| Anzeige | Daten | Dashboard + Settings (Rest), Reports (Kranktage) | Dashboard + Settings (Rest), Jahresreport (Kranktage, vorhanden) |
| Security Rule | - | keine Änderung | keine Änderung |

## 5. Deploy-Hinweise für `/release`

- Reihenfolge beim Release: API vor Web und Mobile ausrollen (deploy-api läuft auf Push `main`, Mobile-Release über Play-Track). Alte Clients bleiben durch Nullable-PUT (2.2) kompatibel.
- Kein Firestore-Rules-Deploy, keine neuen Secrets, keine Datenmigration (Fehlendes Feld = 30).

## 6. Offene Fragen mit Empfehlung

1. **Zählung bei Wochenenden/Nicht-Arbeitstagen:** Soll ein `vacation`-Eintrag an einem Tag zählen, der laut `workdays` kein Arbeitstag ist? Empfehlung: ja, jeder Eintrag zählt 1 (entspricht Mobile heute, ein Eintrag ist eine bewusste Nutzerentscheidung, einfach und deterministisch).
2. **Halbe Urlaubstage:** nicht vorgesehen. Empfehlung: ganze Tage, Feld `int`. Falls später gewünscht, wäre `double` ein breaking Contract, daher jetzt entscheiden. Empfehlung: bei `int` bleiben (v1 laut Issue "einfach").
3. **Anspruch für Vorjahre:** Rückblick auf frühere Jahre nutzt den aktuellen Anspruch. Empfehlung: v1 so lassen, in der UI nur das laufende Jahr als Rest anzeigen (Vorjahre nur Summen), kein Anspruch pro Jahr.
4. **Ort der Berechnung auf Mobile:** lokal (offline) vs. API. Empfehlung: lokal aus den Jahres-`MonthSummary`, Parität über identische Testfälle (gleiche Fixtures wie Backend-Tests).
5. **Wertebereich:** 0-366 ganze Zahlen. Empfehlung wie festgelegt, Ablehnung von Negativ/zu groß mit 400 (Backend) bzw. Eingabevalidierung (Clients).
6. **Dashboard-Platzierung** (Karte vs. Zeile) ist Design-Entscheidung der Plattform-Workflows (`/web-design`, `/mobile-plan`), nicht Vertrag.
7. **Issue-Hinweis `ProfileDto`:** Abweichung begründet in 2.1. Empfehlung: Issue-Text entsprechend korrigieren oder im Kommentar vermerken.
8. **Erwartung "Resturlaub in Reports":** Issue nennt Anzeige "in Settings/Dashboard/Reports" und Kranktage in Reports. Empfehlung: Rest in Settings + Dashboard, Reports zeigen Kranktage und zusätzlich Urlaub genommen/Rest in der Jahresübersicht (Mobile: im vorhandenen Jahresreport-Block).

## 7. Erster Workflow

Backend: `/server-implement 278` auf Branch `feature/278-urlaub-api` (Scope: Abschnitt 2.1, 2.2, 2.3, 2.4, Tests). Danach `/web-analyze` und `/mobile-analyze` für #278 (parallel möglich).

## Entscheidungen (Hauptsession)

Alle Empfehlungen aus Abschnitt 6 übernommen: (1) `vacation`-Eintrag zählt 1, auch an Nicht-Arbeitstagen; (2) nur ganze Tage (`int`); (3) kein Anspruch pro Vorjahr in v1, Rest nur für das laufende Jahr; (4) Mobile rechnet lokal (offline), Parität über gleiche Testfälle; (5) Wertebereich 0–366; (6) Rest in Settings und Dashboard, Reports zeigen Urlaub genommen/Rest und Kranktage; (7) Abweichung von `ProfileDto` bewusst, Feld nur in `SettingsDto`.
Branch: Teil-PRs nacheinander auf dem Session-Branch `claude/week-number-display-bug-x5xq8r` (nach jedem Merge neu von `develop`), Reihenfolge Backend → Web → Mobile.
