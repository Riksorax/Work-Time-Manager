# #279 Feiertage pro Bundesland im Dashboard - Koordinationsplan

Plattformen: Mobile + Web, plus ein kleiner Backend-Teil (Settings-Feld). Free-Feature (kein Premium-Gate). Basis: Issue #279 (keine Kommentare), Code-Stand `develop` (5ca9317, nach #356/#362/#278).

## 1. Befunde im Ist-Zustand

- **Mobile Logik vorhanden:** `mobile/lib/domain/utils/german_holidays.dart` mit `getGermanHolidays(year, Bundesland)` und `getGermanHolidayNames(year, Bundesland)` (`Map<DateTime, String>`, nur deutsche Namen, Schlüssel = lokale Mitternacht). Osterberechnung (Meeus/Jones/Butcher), bewegliche Feiertage und `Buß- und Bettag` über `addCalendarDays` (DST-sicher, #362). Test: `mobile/test/domain/utils/german_holidays_test.dart` (inkl. DST-Fälle).
- **Mobile Bundesland-Einstellung:** Enum `domain/entities/bundesland.dart` (16 Werte, `bundeslandFromName`), `SettingsEntity.bundesland` (nullable, "nicht ausgewählt" erlaubt), Auswahl in `settings_page.dart`. **Gespeichert nur in SharedPreferences unter dem globalen Key `bundesland` (Enum-Name, z.B. `nordrheinWestfalen`), kein Profil-Suffix, kein `_syncToFirestore`, kein Eintrag in `syncFromFirestore`.** Das Feld existiert also weder in Firestore noch im Backend noch im Web.
- **Mobile Nutzung:** nur `reports_page.dart` (Kalender-Markierung, #222/#253). `dashboard_screen.dart` kennt Bundesland/Feiertage nicht.
- **Web:** keine Feiertagslogik, kein Bundesland-Setting, kein Settings-UI dafür. `WorkEntryType.Holiday` (Eintragstyp) existiert, hat aber nichts mit der Feiertagsberechnung zu tun. `UserSettings` (`shared/models/index.ts`), `SettingsService` (onSnapshot `users/{uid}/settings/current`, Schreiben per `PUT /settings`).
- **Backend:** keine Feiertagslogik, `SettingsDto`/`SettingsDocument` ohne Bundesland. `SettingsRepository.SaveAsync` nutzt `SetOptions.MergeFields(SettingsMergeFields)` mit Nullable-Muster aus #278 (`VacationDaysPerYear`). Reports rechnen nicht mit Feiertagen, also ist keine Backend-Rechenlogik nötig.
- **Dashboard ist reiner "Heute"-Screen** (Mobile `DashboardViewModel` und Web `DashboardService` nutzen `DateTime.now()`/`new Date()`, kein Datumswechsel). "Aktuell angezeigter Tag" im Issue = heute.
- CI: Web-Tests laufen bereits zusätzlich mit `TZ=Europe/Berlin` (`ci.yml`), Mobile ebenfalls.

Konsequenz: Das Issue unterschätzt den Umfang. Für Web muss nicht nur die Logik portiert, sondern auch das Bundesland **synchronisierbar** gemacht werden (Settings-Feld + Web-Settings-UI), sonst weiß Web nie, welches Bundesland der Nutzer gewählt hat. Mobile muss das bisher lokale Feld in die Settings-Synchronisation aufnehmen (Parität #278-Muster).

## 2. Gemeinsamer Vertrag

### 2.1 Datenfeld

| Ebene | Festlegung |
|---|---|
| Firestore | `users/{uid}/settings/current` bzw. `users/{uid}/profiles/{profileId}/settings/current`, Feld **`bundesland`** (string). Wert = **Dart-Enum-Name** (Flutter-kanonisch, keine Migration der lokalen Prefs): `badenWuerttemberg, bayern, berlin, brandenburg, bremen, hamburg, hessen, mecklenburgVorpommern, niedersachsen, nordrheinWestfalen, rheinlandPfalz, saarland, sachsen, sachsenAnhalt, schleswigHolstein, thueringen`. Feld fehlt = nicht ausgewählt (keine Feiertage anzeigen). Kein neuer Pfad. |
| Backend `SettingsDocument` | `[FirestoreProperty("bundesland")] string? Bundesland` |
| Backend `SettingsDto` | `string? Bundesland { get; init; }`, JSON `bundesland`. GET: Wert oder `null`. |
| Web `UserSettings` | `bundesland: Bundesland \| null` (Union der 16 Strings, Default `null` in `DEFAULT_SETTINGS`), Typ `Bundesland` + `BUNDESLAND_VALUES` in `shared/models` |
| Mobile | `SettingsRepository.setBundesland` ruft zusätzlich `_syncToFirestore({'bundesland': name})`; `syncFromFirestore` liest `bundesland` zurück (nur gültige Enum-Namen, sonst ignorieren) |

### 2.2 Abwärtskompatibilität und "Löschen"-Semantik (kritisch)

- Alte Clients senden das Feld im PUT nicht. Wie bei #278 gilt: **Feld `null`/fehlend im PUT = gespeicherten Wert unangetastet lassen** (Feld nicht in `SettingsMergeFields` aufnehmen). Sonst würde jedes Speichern eines alten Clients das Bundesland löschen.
- Problem: Der Nutzer muss die Auswahl auch wieder zurücknehmen können ("Nicht ausgewählt", Mobile kennt das). Mit "null = unangetastet" ginge das nicht. **Festlegung: leerer String `""` im PUT = Feld löschen** (Merge mit `FieldValue.Delete` bzw. Feld im Dokument entfernen). Das Backend gibt im GET dann `null` zurück. Clients senden bei "Nicht ausgewählt" `""`.
- Backend validiert: `null` | `""` | einer der 16 Enum-Namen (Whitelist), sonst `400`. Zu testen: PUT ohne Feld überschreibt nicht, PUT `""` löscht, ungültiger Wert `400`, Profil-Pfad, GET-Mapping.
- Mobile `ApiDataSource.saveSettings` merged `{...current, ...neu}` (Read-Modify-Write über die API). Das Backend muss das Feld also durchreichen, deshalb Backend zuerst. Achtung: Mobile sendet bei Löschung `""` (nicht `null`, sonst wird nichts gelöscht), und beim Merge `{...current}` ist `current['bundesland']` `null`, was als "unangetastet" korrekt ist.

### 2.3 Profil-Bezug (`profileId`)

Das Feld liegt in `settings/current` und gilt damit **je Arbeitszeit-Profil** wie alle Settings. Mobile hat den Pref-Key heute global. Festlegung: neuer Key `bundesland_$_userId$_profileSuffix`-analog zu `workdays_...`/`vacation_days_per_year_...`, mit **einmaligem Fallback auf den bestehenden globalen Key `bundesland`**, wenn der neue Key fehlt (Bestandsnutzer behalten ihre Auswahl, keine Migration nötig). Offene Frage 1 (global vs. je Profil).

### 2.4 Rechenregel und Parität der Feiertagslogik

Es gibt **keine Backend-Rechenregel** (anders als sonst im Repo ist Mobile hier die Referenz, da das Backend keine Feiertage kennt; nicht ins Backend portieren, kein Endpunkt). Web portiert Mobile 1:1. Paritäts-Vertrag:

- Gleiche 17 Feiertage und Länderzuordnung wie `getGermanHolidayNames` (siehe Tabelle 2.5). Gleiche Vereinfachungen (Fronleichnam/Mariä Himmelfahrt landesweit). Keine Änderung der Mobile-Berechnung (Akzeptanzkriterium 4).
- **Web-Signatur** (neue Datei `web/src/app/shared/utils/german-holidays.util.ts`, Namensmuster wie `iso-week.util.ts`): `getGermanHolidayNames(year: number, bundesland: Bundesland): Map<string, HolidayInfo>` mit Schlüssel `YYYY-MM-DD` (String, **keine** `Date`-Schlüssel, damit Vergleich nicht von Zeitzone/Referenz abhängt) und `getHolidayFor(date: Date, bundesland): HolidayInfo | null`.
- **DST-/TZ-Sicherheit:** Alle Berechnungen mit UTC-Kalenderfeldern (`Date.UTC(year, month, day + offset)`, `getUTCFullYear/Month/Date/Day`), nie `getTime() + n * 86400000` auf lokalen Daten. Ostersonntag per Meeus/Jones/Butcher mit Integer-Arithmetik (`Math.floor`), identische Formel wie Dart (`~/` = `Math.floor` bei positiven Werten). Buß- und Bettag: ab 22.11. rückwärts bis `getUTCDay() === 3`. "Heute" aus **lokalen** Kalenderfeldern des Geräts (`now.getFullYear()/getMonth()/getDate()`) in den `YYYY-MM-DD`-Schlüssel umwandeln (nicht `toISOString()`, das ist UTC und verschiebt um 1 Tag nachts).
- **Gleiche Testfälle:** Eine gemeinsame, ausgeschriebene Fixture-Tabelle (Jahr, Bundesland, erwartete `YYYY-MM-DD`-Liste, jeweils für 2024, 2025, 2026, 2027 sowie Ostern-Randfälle) in beiden Test-Suites. Mindestens: alle 16 Länder für 2026 (vollständige Liste), Ostern 2024 (Umstellungstag 31.3.), 2025, 2026; Karfreitag/Ostermontag/Himmelfahrt/Pfingstmontag/Fronleichnam je Jahr; Buß- und Bettag 2024 (20.11.), 2025 (19.11.), 2026 (18.11.); Länder ohne Zusatzfeiertag (Hamburg: nur Reformationstag zusätzlich, Hessen: nur Fronleichnam). Tests dürfen nicht von `new Date()`/Wochentag/Zone abhängen (feste Daten). Web-Tests laufen in CI zusätzlich unter `TZ=Europe/Berlin`. Zusätzlich ein Web-Test, der `getHolidayFor` mit lokalen Mitternachtsdaten rund um die Umstellung (30.3.2025, 26.10.2025) und mit 23:30 Uhr prüft.
- **Mobile:** Die vorhandenen Tests als Referenz belassen, fehlende Fälle der gemeinsamen Fixture ergänzen (gleiche Erwartungswerte, nur Test-Ergänzung, keine Logikänderung).

### 2.5 Feiertage (Referenz aus `german_holidays.dart`)

Bundesweit: Neujahr 1.1., Karfreitag (Ostern -2), Ostermontag (+1), Tag der Arbeit 1.5., Christi Himmelfahrt (+39), Pfingstmontag (+50), Tag der Deutschen Einheit 3.10., 1./2. Weihnachtsfeiertag 25./26.12.
Zusätzlich: Hl. Drei Könige 6.1. (BW, BY, ST), Fronleichnam (+60: BW, BY, HE, NW, RP, SL), Mariä Himmelfahrt 15.8. (BY, SL), Allerheiligen 1.11. (BW, BY, NW, RP, SL), Reformationstag 31.10. (BB, HB, HH, MV, NI, SN, ST, SH, TH), Internationaler Frauentag 8.3. (BE, MV), Weltkindertag 20.9. (TH), Buß- und Bettag (SN).

### 2.6 Firestore Security Rules

**Kein Änderungsbedarf.** `match /settings/{doc}` (Root und unter `profiles/{profileId}`) in `web/firestore.rules` deckt das neue Feld ab, kein neuer Pfad. Kein manuelles Rules-Deploy. (Kommentar an der Regel "nur Web - Flutter nutzt SharedPreferences" ist veraltet, optionale Doku-Korrektur, nicht Teil dieses Issues.)

### 2.7 Texte DE/EN

- **Feiertagsnamen:** Heute nur Deutsch (Mobile liefert Klartext). EN-Anforderung (Root-`CLAUDE.md`: DE Referenz, EN mitpflegen) heißt: Namen dürfen nicht als Klartext in die UI. Vertrag: **stabile Feiertags-IDs** (`newYear, goodFriday, easterMonday, labourDay, ascension, whitMonday, germanUnityDay, christmasDay1, christmasDay2, epiphany, corpusChristi, assumption, reformationDay, allSaints, womensDay, worldChildrensDay, repentanceDay`) und je Plattform eine Übersetzungstabelle (Mobile ARB `holiday_<id>`, Web `i18n/de.json|en.json` unter `holidays.<id>`). Mobile: additive Funktion (z.B. `getGermanHolidayIds(year, bundesland) -> Map<DateTime, GermanHoliday>`) neben dem unveränderten `getGermanHolidayNames`; der Reports-Pfad bleibt unberührt. Web gibt direkt `{id}` zurück.
- **EN-Namen:** New Year's Day, Good Friday, Easter Monday, Labour Day, Ascension Day, Whit Monday, German Unity Day, Christmas Day, Boxing Day (St. Stephen's Day), Epiphany, Corpus Christi, Assumption Day, Reformation Day, All Saints' Day, International Women's Day, World Children's Day, Repentance and Prayer Day.
- **Banner-Text:** DE "Heute ist Feiertag: {name}" / EN "Today is a public holiday: {name}". Semantik-/Aria-Label gleich. Deutsche Texte duzen.
- **Settings-Texte (Web neu, Mobile vorhanden):** "Bundesland" / "Federal state", Hinweis "Für Feiertage im Dashboard und Kalender" / "Used for public holidays in dashboard and calendar", Option "Nicht ausgewählt" / "Not selected", 16 Ländernamen (Web `settings.bundesland.<enumName>`; Mobile nutzt `displayName` aus `bundesland.dart`, ist heute hart deutsch, siehe offene Frage 5).

### 2.8 Anzeige und Verhalten im Dashboard

- **Wann:** Heute (lokales Kalenderdatum) ist laut gewähltem Bundesland ein Feiertag. Kein Bundesland gewählt: nichts anzeigen, **kein** Aufforderungs-Banner (kein Nagging; Auswahl nur über Settings).
- **Form:** kompakter Hinweis-Chip/Banner **oberhalb des Timers** ("Heute ist Feiertag: Tag der Deutschen Einheit"), nicht blockierend. Die Zeiterfassungs-UI bleibt voll nutzbar (Nutzer arbeitet ggf. an einem Feiertag, Schicht/Bereitschaft). Das Issue lässt "statt normaler UI" oder "als Zusatzinfo" offen, Empfehlung Zusatzinfo.
- **Bestehender Eintrag:** Hat der Nutzer heute bereits einen Eintrag (Typ `work` mit Zeiten, oder Typ `holiday`/`vacation`/`sick`), bleibt der Eintrag unverändert. Der Banner ist rein informativ, **es wird nie automatisch ein Eintrag angelegt oder geändert**, und das Soll (`getEffectiveDailyTarget`/Overtime) wird nicht angefasst (Akzeptanzkriterium 4, Reports-Logik unverändert). Bei Eintrag Typ `holiday` zusätzlich kein Doppel-Hinweis nötig (Banner bleibt, schadet nicht).
- **Mitternachtswechsel:** Banner-Wert wird aus dem aktuellen Datum abgeleitet (Mobile: Provider, der bei Tageswechsel neu rechnet bzw. bei `build`; Web: `computed` über ein Datum-Signal, das beim Tageswechsel aktualisiert wird). Mindestens: bei Rückkehr in die App/Tab neu berechnen. Kein Timer nötig, wenn die vorhandene Tick-Logik des Dashboards das Datum ohnehin neu liest (Teil-PR prüft).
- **Barrierefreiheit:** `role="status"`/Semantics-Label, Kontrast im Dark Mode (Farbe der vorhandenen `--color-holiday` bzw. Mobile-Theme-Farbe der Kalender-Markierung wiederverwenden).

## 3. Reihenfolge und Teil-PRs

Branches gegen `develop`, jeder PR "Refs #279", Eltern-Issue erst nach PR 3 schließen. Laut Session-Praxis (#278) nacheinander auf dem Session-Branch, nach jedem Merge neu von `develop`.

| # | Branch | Inhalt | Abhängigkeit |
|---|---|---|---|
| 1 | `feature/279-bundesland-api` | `SettingsDocument.Bundesland`, `SettingsDto.Bundesland`, `FirestoreMappings` (ToDto/ToDocument/`SettingsMergeFields` mit null = unangetastet, `""` = löschen, Whitelist-Validierung `IsValidBundesland`), `PUT /settings` `400` bei ungültigem Wert, Tests (GET-Mapping, PUT ohne Feld, PUT `""`, ungültig, Profilpfad). `server/CLAUDE.md`-Endpunkttabelle um das Feld ergänzen. Check: `dotnet build/test WorkTimeManager.slnx -c Release` | keine, **zuerst** |
| 2 | `feature/279-bundesland-mobile` | Mobile hat die Logik schon, daher kleiner Umfang: Settings-Sync (`setBundesland` -> `_syncToFirestore`, `syncFromFirestore` liest zurück, Profil-Suffix mit Legacy-Fallback, Erst-Sync: lokal gesetzt und remote leer -> hochladen), additive Feiertags-ID-Funktion, ARB `holiday_*` + Banner-Text de+en, Dashboard-Banner (`DashboardScreen`, Provider für "Feiertag heute"), Tests (Fixture-Parität, Provider mit fester Uhr, Widget-Test Banner/kein Banner/Eintrag vorhanden, Sync-Tests). Check: Mobile-Checks laut `CLAUDE.md`, `flutter gen-l10n` | PR 1 nur für den Sync (Anzeige selbst läuft lokal, offline-fähig) |
| 3 | `feature/279-bundesland-web` | `Bundesland`-Typ + `UserSettings.bundesland`, `german-holidays.util.ts` (+ Spec mit Fixture, TZ-Fälle), `SettingsService` merge/`ApiClient.saveSettings` (`""` bei Nicht-Auswahl), Settings-UI (Select mit 16 Ländern + "Nicht ausgewählt"), Dashboard-Chip (`DashboardService`/`DashboardComponent`, `computed` aus Settings + Datum), i18n de+en (Feiertage, Banner, Settings), Specs. Check: `npm test -- --watch=false && TZ=Europe/Berlin npm test -- --watch=false && npm run build -- --configuration production` | PR 1 (Feld im PUT/GET), Fixture aus PR 2 |

Mobile vor Web ist sinnvoll, weil die Logik und das Setting dort existieren und die gemeinsame Fixture dort entsteht. PR 2 und PR 3 können nach PR 1 parallel laufen; die Fixture-Tabelle wird beim Start von PR 2 festgeschrieben (Anhang A der Hauptsession bzw. im Mobile-Test) und von Web übernommen.

## 4. Paritätstabelle

| Aspekt | Backend | Web | Mobile |
|---|---|---|---|
| Datenfeld / Pfad | `bundesland` in `settings/current` (Root + `profiles/{id}`) | gleiches Feld über `SettingsService` (onSnapshot lesen, PUT schreiben) | SharedPreferences (Key mit Profil-Suffix + Legacy-Fallback), Sync über API nach Firestore, `syncFromFirestore` erweitert |
| Endpunkt genutzt | `GET/PUT /settings` (Validierung) | `ApiClient.saveSettings` | `ApiDataSource.saveSettings/getSettings` |
| Rechenregel identisch | keine (Backend kennt keine Feiertage) | Port von `german_holidays.dart`, UTC-Kalenderfelder, Fixture-Parität | Referenz, Logik unverändert |
| Premium-Gate | - (Free) | keines | keines |
| Texte de + en | - | `public/i18n/de.json`, `en.json` (`holidays.*`, Banner, Settings) | `app_de.arb`, `app_en.arb` (`holiday_*`, Banner) |
| Arbeitszeit-Profile | `profileId` auf Settings | `activeProfileIdForApi` (wie übrige Settings) | `_profileSuffix` im Pref-Key |
| Anzeige | Daten | Dashboard-Chip + Settings-Auswahl | Dashboard-Banner (neu), Settings (vorhanden), Reports-Kalender (unverändert) |
| Verhalten Eintrag vorhanden | - | Banner informativ, Eintrag/Soll unverändert | identisch |
| Zeitumstellung/TZ-Tests | - | UTC-Felder, CI zusätzlich `TZ=Europe/Berlin` | `addCalendarDays` (#362), CI `TZ=Europe/Berlin` |
| Security Rule | - | keine Änderung | keine Änderung |

## 5. Deploy-Hinweise für `/release`

- API vor Web/Mobile ausrollen (`deploy-api` auf Push `main`). Alte Clients bleiben durch Null-Semantik im PUT kompatibel (2.2).
- Kein Firestore-Rules-Deploy, keine neuen Secrets, keine Migration (Feld fehlt = nicht gewählt; Mobile-Bestandsnutzer behalten lokale Auswahl, sie wird beim nächsten Login-Sync hochgeladen, wenn remote leer).
- Release-Hinweis: Bestehende Mobile-Nutzer mit gewähltem Bundesland sehen den Feiertags-Banner sofort nach dem Update (kein Opt-in nötig, Einstellung war schon gesetzt).

## 6. Offene Fragen mit Empfehlung

1. **Bundesland global oder je Arbeitszeit-Profil?** Der Wohnort ist eigentlich profilübergreifend, Settings sind es aber nicht. Empfehlung: je Profil in `settings/current` (konsistent mit allen übrigen Settings, kein Sonderpfad, Rules unverändert), Mobile mit Legacy-Fallback auf den globalen Key. Nachteil: Nutzer mit mehreren Profilen wählen mehrfach.
2. **Löschen-Semantik `""`:** Empfehlung wie 2.2 (leerer String löscht, `null` = unangetastet). Alternative wäre ein eigenes `bundeslandCleared`-Flag, unnötig komplex.
3. **Feiertagsnamen EN:** Empfehlung stabile IDs + Übersetzungen auf beiden Plattformen (2.7), `getGermanHolidayNames` bleibt unverändert für Reports. Alternative (nur deutsche Namen auch in EN-UI) verstößt gegen die i18n-Regel.
4. **Banner vs. Ersatz der Zeiterfassungs-UI:** Empfehlung Banner/Chip als Zusatzinfo, UI bleibt nutzbar, kein automatischer Eintrag, Soll unverändert.
5. **Bundesland-Anzeigenamen in Mobile-Settings sind hart deutsch** (`BundeslandDisplayName`, Eigennamen, im EN meist identisch außer Bavaria/Saxony etc.). Empfehlung: ausser Scope, Eigennamen belassen; im Web dieselben deutschen Namen in beiden Sprachen (konsistent). Nur falls gewünscht EN-Namen nachziehen.
6. **Teilweise regionale Feiertage** (Fronleichnam/Mariä Himmelfahrt/Allerheiligen-Gemeindeeinschränkungen, Augsburger Friedensfest, Sachsen Fronleichnam in Teilen): Empfehlung unverändert landesweit wie Mobile (bekannte Vereinfachung, im Banner-Hilfetext oder Settings-Hinweis nicht nötig).
7. **Sync des Banners ohne Login (Web localStorage / Mobile lokal):** Empfehlung: Web nutzt `user_settings` im localStorage mit (Feld wird durch `mergeSettings` mitgeführt), Mobile funktioniert lokal bereits. Kein Sonderfall.
8. **Hinweis im Dashboard, wenn kein Bundesland gewählt:** Empfehlung kein Hinweis (nicht aufdringlich). Optional später ein dezenter Link in Settings.
9. **Tageswechsel bei offenem Dashboard:** Empfehlung Neuberechnung bei Tageswechsel/Resume (2.8), kein dedizierter Timer, falls die bestehende Tick-Logik das Datum ohnehin neu liest.

## 7. Erster Workflow

Backend: `/server-implement 279` auf Branch `feature/279-bundesland-api` (Scope: Abschnitte 2.1, 2.2, Tests, `server/CLAUDE.md`-Tabelle). Danach `/mobile-analyze 279` und `/web-analyze 279` (parallel möglich); die gemeinsame Fixture-Tabelle (2.4) dabei im Mobile-Test anlegen und für Web übernehmen. Vor dem Start von PR 1 bitte die offenen Fragen 1 bis 4 klären lassen (Vertragsrelevant: 1 und 2).

## Entscheidungen (Hauptsession)

Alle Empfehlungen aus Abschnitt 6 übernommen: (1) Bundesland je Arbeitszeit-Profil in `settings/current` (Mobile mit Legacy-Fallback auf den globalen Key); (2) leerer String `""` löscht das Feld, `null`/fehlend lässt den Wert unangetastet; (3) Feiertagsnamen über stabile IDs mit Übersetzungen (DE/EN) auf beiden Plattformen, `getGermanHolidayNames` bleibt für Reports unverändert; (4) Banner/Chip als Zusatzinfo oberhalb des Timers, kein Ersatz der Erfassungs-UI, kein automatischer Eintrag, Soll unverändert; Fragen 5–9 nach den jeweiligen Empfehlungen in der Datei.
Branch: Teil-PRs nacheinander auf dem Session-Branch `claude/week-number-display-bug-x5xq8r` (nach jedem Merge neu von `develop`), Reihenfolge Backend → Mobile → Web, alle mit `Refs #279`.
