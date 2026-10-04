# Mobile-Research: #385 — Über Mitternacht laufender Eintrag bleibt nach App-Neustart verwaist
Datum: 2026-10-04

## Aufgabe

Seit #379 läuft ein Timer über Mitternacht weiter (Eintrag bleibt am Starttag). Wird die App danach beendet und neu
gestartet (Fr 22:00 Start, Sa 09:00 Neustart), lädt `DashboardViewModel._load` über `GetTodayWorkEntry` nur den Eintrag
von **heute**. Der Freitags-Eintrag (`workStart != null && workEnd == null`) ist unsichtbar, bleibt offen im Datenbestand,
fließt nicht in den Gleitzeit-Saldo ein, und Reports zeigen einen offenen Eintrag.

**Produktentscheidung (verbindlich):** nur Hinweis, **kein** automatisches Teilen/Schließen (#381 ist nicht Teil). Beim
Start der App/Seite gibt es einen noch offenen Eintrag vor heute: der Nutzer sieht ihn und entscheidet (fortsetzen oder
beenden/Ende nachtragen).

Akzeptanzkriterien (abgeleitet aus Issue + Entscheidung):
1. Beim Start (und beim Reinit nach Profil-/Auth-Wechsel) wird ein offener Eintrag vor heute erkannt und angezeigt.
2. Nutzer kann: Fortsetzen (Timer läuft am Eintragsdatum weiter, wie #379), Beenden mit wählbarem Ende, oder Später.
3. Nichts wird ohne Nutzeraktion geändert. Kein Splitten.
4. Gleitzeit-Saldo stimmt nach dem Beenden (kein Doppelzählen, kein Überschreiben).
5. Tests mit Fake-Uhr, festen Daten, TZ-unabhängig (CI `Europe/Berlin`).
6. Web: Parität prüfen (Ergebnis unten: gleiches Problem), getrennter PR.

Nicht Teil: automatisches Teilen bei Mitternacht (#381), Reparatur bereits verfälschter Daten, Scan aller Profile,
Reports-Darstellung offener Einträge (Folge-Issue, siehe Risiken).

## Betroffene Dateien

| Datei | Warum |
|---|---|
| `mobile/lib/presentation/view_models/dashboard_view_model.dart` | `_load` (Zeile ~100) lädt nur heute via `getTodayWorkEntry.call()`; `_isRunning`/`_ensureCurrentDay`/`_onDayChange`/`_recalculateStateAndSave` kennen schon "laufender Vortag"; Pinning eines Vortags-Eintrags für "Fortsetzen" |
| `mobile/lib/presentation/state/dashboard_state.dart` | ggf. unverändert (empfohlen: Hinweis-Zustand in eigenem Provider, nicht im Dashboard-State) |
| `mobile/lib/domain/usecases/get_today_work_entry.dart` | Muster für neuen Use Case (Uhr per Konstruktor) |
| `mobile/lib/domain/usecases/` (neu: `get_open_past_work_entries.dart`, `close_open_work_entry.dart`) | Suche + Beenden, ohne die Repository-API zu erweitern |
| `mobile/lib/domain/repositories/work_repository.dart` | vorhandene API reicht: `getWorkEntriesForMonth(year, month)`; kein neuer Repo-Vertrag nötig |
| `mobile/lib/data/repositories/hybrid_work_repository_impl.dart`, `work_repository_impl.dart`, `local_work_repository_impl.dart` | Datenquellen (API/Firestore bzw. SharedPreferences), alle profilgebunden über `workRepositoryProvider` |
| `mobile/lib/data/datasources/remote/api_client.dart` | `GET /work-entries/{y}/{m}?profileId=` liefert Monatsliste (Datum `.toLocal()`) |
| `mobile/lib/core/providers/providers.dart` | `workRepositoryProvider` watcht `activeWorkProfileIdProvider`; neue Provider (UseCases, Hinweis-Notifier) hier verdrahten, `build_runner` nötig falls `@riverpod` |
| `mobile/lib/core/providers/today_provider.dart`, `clock_provider.dart` | "heute" und Uhr; immer `ref.listen`, nie `ref.watch(todayProvider)` (#387) |
| `mobile/lib/presentation/screens/dashboard_screen.dart` | Banner neben `HolidayBanner` (Zeilen ~185 und ~217, schmal + breit) |
| `mobile/lib/presentation/widgets/` (neu: `open_entry_banner.dart`, Ende-Dialog) | UI; Muster: `holiday_banner.dart` (`Semantics(liveRegion)`, Farbschema-Container) |
| `mobile/lib/domain/services/break_calculator_service.dart` | Auto-Pausen beim Beenden (wie Stop) |
| `mobile/lib/domain/utils/overtime_utils.dart` | `getEffectiveDailyTarget` für Soll am Eintragsdatum |
| `mobile/lib/l10n/app_de.arb`, `app_en.arb` | neue Texte |
| `mobile/lib/presentation/screens/reports_page.dart` (~2455) | zeigt offenen Eintrag mit `end = nowToMinute()` (Folgeproblem, siehe Risiken) |
| `mobile/test/support/dashboard_harness.dart`, `fake_clock.dart`, `fake_repositories.dart` | Testbasis; `dashboard_view_model_day_change_test.dart` / `_profile_test.dart` als Vorbild |
| Web: `web/src/app/features/dashboard/dashboard.service.ts`, `dashboard.html`, `core/services/work-entry.ts`, `core/services/today.ts`, `shared/components/holiday-banner/`, `web/public/i18n/de.json`/`en.json` | Paritäts-PR (siehe unten) |

## Ist-Zustand / Ursache

Reproduktion (Mobile, TZ egal): `now = Fr 2026-10-02 22:00`, Timer starten. Autosave schreibt alle 30 s
`users/{uid}/work_entries/2026-10` bzw. lokal `local_work_entries_2026_10` mit `days["2"] = {workStart, workEnd: null, breaks}`.
App beenden. Neustart `Sa 2026-10-03 09:00`: `_load` -> `getTodayWorkEntry` -> `getWorkEntry(Sa)` -> `days["3"]` fehlt ->
`WorkEntryModel.empty(Sa)`. Dashboard zeigt leeren Samstag, Fr bleibt offen. Startet der Nutzer nun einen Timer, existieren
zwei Einträge mit `workEnd == null` (Fr offen, Sa läuft). Der Fr wird nie von selbst geschlossen.

Folgen im Bestand:
- Saldo: wird nur bei Stop gespeichert (`_recalculateStateAndSave`: `saveOvertime(base + daily)` + `saveLastUpdateDate`). Autosave schreibt den Eintrag, **nicht** den Saldo. Der offene Tag ist im Saldo nie enthalten.
- Mobile-Reports: `reports_page.dart` rechnet für `workEnd == null` mit `end = nowToMinute()` -> ein Wochen alter offener Eintrag zeigt eine absurd hohe Arbeitszeit. Backend `ReportCalculator` (Zeilen ~197/203) zählt offene Einträge dagegen als 0. Unterschiedliche Darstellung, nicht Teil von #385.
- `calculateOvertime` (Entity-Extension) liefert 0 bei `workEnd == null`.

Wichtig: Das Dashboard kann einen laufenden Vortag bereits vollständig bedienen, wenn `state.workEntry` ihn enthält (#379):
`_isRunning` schützt vor `_onDayChange`/`_ensureCurrentDay`-Reinit, Soll kommt über `_getEffectiveTargetDailyHours(entry.date)`,
Stop speichert am Starttag und schaltet danach per `_init(dayChange: true)` auf heute. Ihm fehlt nur der **Einstieg** (Laden
des Vortags statt heute nach einem Kaltstart).

## (1) Wo sind offene Einträge auffindbar

Repository-API (kein Erweiterungsbedarf): `WorkRepository.getWorkEntriesForMonth(year, month)` liefert alle Einträge des
Monats (API: ein `GET` je Monat; Firestore: ein Monatsdokument; lokal: ein SharedPreferences-Key, synchron billig).
Filter im neuen Use Case: `type == work && workStart != null && workEnd == null && _dayOf(date) < today`.

Rückblick (Empfehlung): **aktueller + Vormonat**, Treffer absteigend nach Datum. Begründung:
- "Nur gestern" greift zu kurz: der Nutzer kann die App erst nach einem Wochenende öffnen, oder der Eintrag wurde schon einmal ignoriert.
- Ein Monatsdokument pro Aufruf ist die kleinste Lese-Einheit; gestern liegt am Monatsersten im Vormonat. 2 Reads pro Start sind vertretbar (Dashboard lädt ohnehin Eintrag, Saldo, lastUpdate).
- Älter als der Vormonat: nicht gesucht. Das ist ein bewusst akzeptierter Rest (offener Eintrag > ~4 Wochen), Reports/Kalender erlauben dort manuelles Bearbeiten.
- Lokal (ausgeloggt) wäre ein voller Scan über `local_monthly_keys` möglich/billig; aus Konsistenz trotzdem dieselbe 2-Monats-Grenze (gleiche Testbasis, gleiche Semantik).

Aspekte:
- **Profile (#138/#244):** `workRepositoryProvider` ist an `activeWorkProfileIdProvider` gebunden; ein Use Case, der dieses Repo watcht, sucht automatisch im aktiven Profil. Nach Profilwechsel wird neu gesucht (Rebuild). Offene Einträge **in nicht aktiven Profilen** werden nicht gescannt (Kosten, Vertrag unklar). Das löst die bekannte Grenze (2) aus `mobile/CLAUDE.md` #388 für das aktive Profil: kommt man in ein Profil mit eingefrorenem Vortags-Eintrag zurück, erscheint der Hinweis. Ein am selben Tag eingefrorener Eintrag wird dagegen normal als "heute" geladen (unverändert).
- **Premium:** nicht gaten. Es geht um Datensicherheit des Nutzers, keine Zusatzfunktion.
- **Hybrid:** unverändert über `HybridWorkRepositoryImpl` (userId != null -> API/Firestore, sonst lokal). `DataSyncService` (Login-Migration) nimmt offene lokale Einträge mit; nach Login greift die Suche automatisch auf Cloud-Daten (Auth-Wechsel baut Repo/VM neu).
- **Kosten:** 2 Monats-Reads je Start, je Profilwechsel, je Auth-Wechsel; zusätzlich je Banner-Aktion ein Re-Check (nur bei Bedarf).
- **Datum/TZ:** API-Daten kommen via `.toLocal()`, lokaler Key = Kalendertag; Vergleich mit `todayProvider`-Tag (`DateTime(y,m,d)`), nie Stunden-Differenzen für "vor heute".

## (2) UX-Konzept

### Varianten

**A — Modaler Dialog beim Start** ("Eintrag vom Fr, 02.10. läuft noch seit 22:00" mit Fortsetzen / Beenden / Später).
- Pro: nicht zu übersehen.
- Contra: stapelt sich mit Start-Dialogen (App-Lock, Update-Pflicht, Wochen-Reflexion, Paywall); unterbricht; blockiert Zugriff auf Dashboard; nach "Später" kein sichtbarer Rest; schlechter testbar/zugänglich.

**B — Nicht-modaler Banner im Dashboard (Empfehlung)**, oberhalb des Timers (neben/unter `HolidayBanner`), Aktionen im Banner:
"Eintrag vom Fr, 02.10. läuft noch seit 22:00 Uhr" + Buttons **Fortsetzen**, **Beenden**, (Später = Banner wegwischen/Schließen-Icon).
- Pro: konsistent mit bestehendem Banner-Muster, `liveRegion`, kein Dialogstapel, bleibt sichtbar bis zur Entscheidung, Dashboard bleibt bedienbar (Nutzer kann z. B. direkt heute starten).
- Contra: kleine Gefahr, ihn zu ignorieren (gewollt: "Später").

**C — Automatisch schließen/teilen:** durch Produktentscheidung ausgeschlossen (#381).

Empfehlung: **B**, Beenden öffnet einen kleinen Dialog/Bottom-Sheet mit Datum+Zeit-Wahl.

### Aktionen im Detail

**Fortsetzen:** lädt den offenen Eintrag in den Dashboard-State ("Pinning"), Timer läuft weiter, exakt der #379-Zustand.
- Nur angeboten, wenn (a) der heutige Eintrag leer ist (`workStart == null`), sonst gäbe es zwei parallele Einträge in einem Ein-Eintrag-Dashboard, und (b) der Eintrag plausibel noch läuft (Empfehlung: `now - workStart <= 24 h`; Konstante, siehe offene Fragen). Sonst nur Beenden.
- Technik: `_load(gen, dayChange)` bekommt einen optionalen `pinnedDate`/Eintrag; statt `getTodayWorkEntry` wird dieser Eintrag geladen; Basis über den **dayChange-Pfad** (`initialOvertime = storedOvertime`), nicht über die "lastUpdate == heute"-Heuristik (die würde bei zufällig heute gesetztem `lastUpdated` den Tagesanteil fälschlich abziehen). Danach greifen `_isRunning`-Guards, Stop -> Reinit auf heute, alles wie #379.
- Autosave: schreibt `state.workEntry` (Vortags-Eintrag), unverändert korrekt.
- Offene Pause: läuft weiter (Pausenzeit zählt bis jetzt, `_calculateTotalBreakDuration` nimmt `b.end ?? now`). Entspricht dem, was der Nutzer sieht, wenn die App durchgelaufen wäre.
- Gleitzeit-Basis: `storedOvertime` (Stand bis zum letzten Stop); Tagesanteil = Vortags-Netto - Soll(Vortag). Beim Stop: `saveOvertime(base + daily)`, wie #379.

**Beenden:** eigener Pfad **ohne** den Dashboard-State anzufassen (Use Case `CloseOpenWorkEntry`):
1. Ende wählen (Datum + Uhrzeit). Standard-Vorschlag und Schnellwahl:
   - **Soll-Ende** (Start + Tagessoll des Eintragsdatums + vorhandene Pausen; Logik wie `_calculateExpectedEndTime`), falls in der Vergangenheit und < jetzt; sonst "Jetzt";
   - "Jetzt" (nur wenn Eintrag <= 24 h alt, sonst nicht anbieten: erzeugt riesige Dauer);
   - manuell (Picker für Datum + Zeit, Datum begrenzt auf [Starttag, heute]).
   - **"Letzte bekannte Aktivität" ist nicht verlässlich ableitbar:** der Eintrag hat kein `updatedAt`; Autosave-Zeitpunkt wird nicht gespeichert. Aus Pausen (`start`/`end`) lässt sich nur eine Untergrenze ermitteln. Kein Default daraus.
   - Validierung: `end > workStart`, `end <= now`, `end >= letzter Pausenstart`; Warnhinweis bei Netto > 16 h (soft, kein Blocker).
2. Eine offene Pause wird zum gewählten Ende geschlossen.
3. Auto-Pausen wie beim normalen Stop (`BreakCalculatorService.calculateAndApplyBreaks`, nur Typ work, nur wenn keine offene Pause).
4. Eintrag speichern (`SaveWorkEntry`).
5. Saldo **inkrementell** fortschreiben: `neu = ensureOvertimeLoaded() + (netto - Soll(entry.date))`, `saveOvertime(neu)`. **Nicht** `saveLastUpdateDate` setzen (siehe Datenrisiken: Heuristik `lastUpdate == heute`). Bei Fehler: Eintrag nicht als geschlossen melden (erst Saldo, dann Eintrag, wie im Stop-Pfad "Saldo, dann Eintrag"), Fehler loggen und Banner stehen lassen.
6. Dashboard neu laden (`_init(dayChange: true)` über eine kleine öffentliche Methode, z. B. `reloadAfterRetroClose()`), damit `initialOvertime` den neuen Saldo enthält. Läuft heute ein Timer, wird er durch den Reinit neu aufgebaut (Eintrag bleibt laufend, Basis = gespeicherter Saldo ist korrekt, weil dessen Tagesanteil erst beim Stop gespeichert wird; ist heute bereits ein abgeschlossener Eintrag nach `workEnd` gespeichert, deckt `dailyAlreadyStored` den Fall ab). Genau diesen Fall im Plan mit Test absichern.

**Später:** Banner schließen, nur im Speicher (Provider-State, je Profil + Eintrags-Id). Beim nächsten Start erscheint er wieder. Absichtlich nicht persistent: der Eintrag ist ein Datenmangel, kein Hinweis zum Wegklicken.

### Interaktion mit bestehender Logik

| Thema | Verhalten |
|---|---|
| `_ensureCurrentDay` | unverändert; ein gepinnter laufender Vortag fällt unter `_isRunning`. Beenden-Pfad geht nicht durch das Dashboard und braucht den Guard nicht (eigene Aktionskapsel mit festgehaltenem Repo, analog `_ActionCtx`, damit Profilwechsel mitten im Dialog nichts ins falsche Profil schreibt) |
| Tageswechsel-Reinit (`_onDayChange`) | läuft nicht bei laufendem Eintrag; Hinweis-Provider hört per `ref.listen(todayProvider)` und rechnet neu (ein vor Mitternacht "heutiger" offener Eintrag wird nach Mitternacht nur dann gemeldet, wenn er **nicht** im Dashboard läuft: der im Dashboard laufende Eintrag ist per Definition sichtbar und darf keinen Banner erzeugen) |
| Autosave | schreibt nur `state.workEntry`; Beenden-Pfad schreibt separat. Race: läuft ein Dashboard-Timer für denselben Eintrag, ist er nicht Banner-Kandidat (Ausschluss über Eintrags-Id des Dashboard-Eintrags) |
| Gleitzeit-Basis | Fortsetzen: dayChange-Pfad (`stored` = Basis). Beenden: inkrementell, ohne `lastUpdated` |
| Offene Pause | Fortsetzen: läuft weiter. Beenden: wird zum Ende geschlossen |
| Profilwechsel (#388) | Hinweis-Provider hängt am Repo des aktiven Profils -> neue Suche; Beenden-Aktion hält Repos zu Beginn fest |
| Riskante Datei | `dashboard_view_model.dart` (823 Zeilen, Race-sensibel #379/#388). Änderung dort minimal halten: nur Pinning in `_load` + Reload-Methode |

### Aufwand und Empfehlung

| Teil | Aufwand |
|---|---|
| Use Cases (Suche, Beenden inkl. Saldo-Delta) + Provider | M |
| Banner-Widget + Ende-Dialog (A11y, Dark Mode, l10n) | M |
| `DashboardViewModel`: Pinning für "Fortsetzen" + Reload-Methode | M (heikel: Race-/Gen-Logik) |
| Tests (VM, Use Cases, Widget) | M-L |
| ARB-Texte | S |

Empfehlung: **Variante B, Pflichtumfang "Beenden" + "Später"; "Fortsetzen" im selben PR**, wenn der Pinning-Eingriff klein bleibt;
andernfalls Fortsetzen als Folge-PR (Beenden löst das Datenproblem allein). Begründung: Beenden und Hinweis sind
entkoppelt vom heiklen ViewModel und liefern 90 % des Werts; Fortsetzen ist die einzige Aktion, die `DashboardViewModel`
anfasst.

## Datenfluss

```
App-Start / Profilwechsel / Auth-Wechsel
  -> openPastEntriesProvider (AsyncNotifier, ref.watch(workRepositoryProvider)/UseCase,
                              ref.listen(todayProvider))
     -> GetOpenPastWorkEntries (clock) -> WorkRepository.getWorkEntriesForMonth(m), (m-1)
        -> Hybrid -> WorkRepositoryImpl -> ApiDataSource -> GET /work-entries/{y}/{m}?profileId=
                  -> LocalWorkRepositoryImpl -> SharedPreferences local_work_entries_{y}_{mm}
  -> DashboardScreen: OpenEntryBanner (ConsumerWidget, ausgeblendet bei leer/Später/Entry == Dashboard-Eintrag)

Beenden:  Banner -> Ende-Dialog -> CloseOpenWorkEntry
            (SaveWorkEntry, OvertimeRepository.ensureOvertimeLoaded + saveOvertime)
          -> invalidate(openPastEntriesProvider) + DashboardViewModel.reload (dayChange)
Fortsetzen: Banner -> DashboardViewModel.resumePastEntry(entry) -> _load(pinned) -> _startTimerIfNeeded
```

## (3) Web

Gleiches Problem bestätigt. `DashboardService._initInner` lädt nur `workSvc.getTodayEntry(pid)`; Reload nach Mitternacht
zeigt leeren heutigen Tag, der Vortag bleibt offen. `TodayService` löst nur Reinit bei Tageswechsel aus und lässt laufende
Einträge in Ruhe (analog Mobile). Verhalten nach Reload daher identisch.

Paritäts-PR (getrennt, nach Mobile):
- Suche: `WorkEntryService.getEntriesForMonth(year, month)` existiert, hat aber **kein** `profileId`-Argument (nur `combineLatest(auth.user$, activeProfileId$)`); für #380-konforme Reads (Profil explizit, kein Replay-Lag) braucht es ein optionales `profileId` wie bei `getTodayEntry(profileId?)`/`saveEntry(entry, profileId?)`. Lokal: `_localGetMonth`. Lesen per `firstValueFrom` (onSnapshot-Abo wird beendet, keine Dauer-Subscription).
- Zustand: Signal `openPastEntry` im `DashboardService`, geladen am Ende von `_initInner` (nach Generationsprüfung `gen !== this._initGen`), zurückgesetzt bei Profilwechsel.
- UI: neue Komponente analog `shared/components/holiday-banner`, in `dashboard.html` neben `app-holiday-banner`; Ende-Wahl als Dialog (Material, `time-input`-Komponente vorhanden; Datum+Zeit nötig, bestehendes `setManualEndTime(timeStr)` kennt nur Zeit am Starttag und braucht eine Variante mit Datum).
- Fortsetzen über Pinning in `_initInner` (heute `_isCurrentDay()` lässt laufende Einträge bereits durch).
- Web-spezifisch: Mehrere Tabs/Geräte (onSnapshot) können denselben Eintrag laufen lassen: Eintrag, der in **diesem** Dashboard läuft, nie als Banner anbieten; Race "anderes Gerät beendet ihn gerade" -> vor dem Write erneut lesen (Optimistic Check), sonst Banner verwerfen.
- Backend: keine Änderung nötig (`GET /work-entries/{y}/{m}` und `PUT` genügen). `ReportCalculator` zählt offene Einträge als 0 (nur Hinweis, nicht Teil).
- Verweis `.claude/agents/cross-platform-coordinator.md` nur falls ein gemeinsamer Vertrag (z. B. ein serverseitiger "offene Einträge"-Endpunkt) gewünscht wird; für die Empfehlung unnötig.

## (4) Texte, Dark Mode, Barrierefreiheit

Neue ARB-Keys (de = Referenz, `@key`-Beschreibung, en parallel; Du-Form):

| Key | de | en |
|---|---|---|
| `openEntryBannerTitle` (`{date}`, `{time}`) | "Dein Eintrag vom {date} läuft noch seit {time} Uhr" | "Your entry from {date} is still running since {time}" |
| `openEntryBannerMore` (`{count}`) | "Noch {count} weitere offene Einträge" | "{count} more open entries" |
| `openEntryContinue` | "Fortsetzen" | "Continue" |
| `openEntryEnd` | "Beenden" | "End" |
| `openEntryLater` | "Später" | "Later" |
| `openEntryEndDialogTitle` | "Ende des Eintrags festlegen" | "Set the end of the entry" |
| `openEntryEndDialogBody` (`{date}`) | "Wann hast du am {date} aufgehört?" | "When did you stop on {date}?" |
| `openEntryEndSuggestionExpected` / `...Now` | "Soll-Ende ({time})" / "Jetzt" | "Target end ({time})" / "Now" |
| `openEntryEndInvalid` | "Das Ende muss nach dem Start und vor jetzt liegen." | "The end must be after the start and before now." |
| `openEntryEndLongWarning` | "Das ergibt mehr als 16 Stunden. Stimmt das?" | "That is more than 16 hours. Is that correct?" |
| `openEntrySaveError` | "Eintrag konnte nicht beendet werden." | "Could not end the entry." |

Datumsformat über `Localizations.localeOf(context)`; Uhrzeit respektiert `use24HourFormat` aus den Settings (Dashboard nutzt es bereits).

Dark Mode: `ColorScheme`-Rollen statt fester Farben (Vorschlag `errorContainer`/`onErrorContainer` oder `secondaryContainer`, da Handlungsbedarf, aber kein Fehler; `tertiaryContainer` ist schon der Feiertag-Banner und sollte sich unterscheiden). Kontrast durch Rollenpaar gesichert.

A11y: `Semantics(container: true, liveRegion: true, label: ...)` wie `HolidayBanner`, Buttons >= 48 dp, Buttons einzeln fokussierbar mit eigenem Label (Datum im Label), Dialog mit Titel und Fokus-Reihenfolge, Fehlertext nicht nur farbig. Auf schmalen Breiten Buttons umbrechen (`Wrap`).

## (5) Testplan, PR-Aufteilung

Grundlagen: `Harness` (`test/support/dashboard_harness.dart`), `FakeClock`, `fake_repositories.dart`. Feste Bezugsdaten wie dort (Fr 2026-10-02, Sa 2026-10-03, So 2026-10-04, Mo 2026-10-05), keine `DateTime.now()`, keine Wochentags-/Zonenannahme. DST-nahe Fälle als Invarianten (Wechsel 2026-10-25 / 2026-03-29). CI läuft `Europe/Berlin`; lokal zusätzlich `TZ=UTC`, `America/Los_Angeles`, `Pacific/Auckland flutter test`. `TestWidgetsFlutterBinding.ensureInitialized()` wegen `todayProvider`; VM-Tests in `fakeAsync`, am Ende dispose + Timer-Zähler prüfen.

1. `GetOpenPastWorkEntries` (Unit): Fr 22:00 offen, jetzt Sa -> 1 Treffer; heute offener Eintrag -> kein Treffer; abgeschlossen/Typ vacation/sick/holiday -> kein Treffer; Monatsgrenze (jetzt `2026-11-01`, offen `2026-10-31`); Vormonat gelesen, Vor-Vormonat nicht; mehrere -> Sortierung; Lesefehler -> leeres Ergebnis + Log, kein Crash.
2. `CloseOpenWorkEntry` (Unit): Ende gesetzt, offene Pause geschlossen, Auto-Pausen nur bei Typ work, Saldo = alt + (netto - Soll(Eintragsdatum)) (Soll am **Starttag**, Wochenende = Zusatztag), `lastUpdated` unverändert, Validierung (Ende <= Start, > jetzt, vor letzter Pause), Fehler beim Saldo-Write -> Eintrag bleibt offen, Reihenfolge der Writes (`writeLog`).
3. Hinweis-Provider: Start mit offenem Vortag, "Später" je Profil/Eintrag, Profilwechsel (`Harness(profiles: true)`, `h.switchProfile`) sucht im neuen Profil, Tageswechsel via `FakeClock.jumpTo`, im Dashboard laufender Eintrag erzeugt keinen Banner.
4. `DashboardViewModel` Fortsetzen: gepinnter Vortag, Basis = gespeicherter Saldo (auch wenn `lastUpdated == heute`), Timer läuft, Soll vom Starttag, Stop -> Reinit auf heute; Fortsetzen nicht verfügbar bei heute vorhandenem Eintrag oder > 24 h; nach Beenden mit heute laufendem Timer bleibt Saldo-Basis korrekt; nach Beenden mit heute abgeschlossenem Eintrag kein Doppelzählen.
5. Widget-Tests Banner/Dialog (Muster `holiday_banner_test.dart`, `dashboard_screen_holiday_test.dart`): Texte de/en, Semantik, schmale Breite, Dark Mode (Golden optional).
6. Regressions: bestehende `dashboard_view_model_day_change_test.dart` und `_profile_test.dart` müssen unverändert grün bleiben.

PRs und Reihenfolge:
1. **PR 1 Mobile** (Branch `claude/week-number-display-bug-x5xq8r` bzw. passender Feature-Branch, gegen `develop`): Suche + Banner + Beenden + Später (+ Fortsetzen, falls Eingriff klein; sonst PR 1b). Checks: `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`; `build_runner` falls `@riverpod`; `flutter gen-l10n`.
2. **PR 2 Web** (Parität, nach PR 1 wegen abgestimmter Texte/UX): `npm test -- --watch=false && npm run build -- --configuration production`.
3. Optional **Folge-Issue**: Reports/Kalender zeigen offenen Eintrag mit `now` (Mobile) bzw. 0 (Backend) uneinheitlich; Kennzeichnung "offen" statt hochlaufender Dauer.
Kein Backend-PR. Keine neuen Firestore-Pfade, daher keine Änderung an `web/firestore.rules`. Doku: Abschnitt in `mobile/CLAUDE.md` ("Offene Einträge vor heute (#385)") und `web/CLAUDE.md`.

## (6) Datenrisiken

| Risiko | Bewertung / Umgang |
|---|---|
| **Mehrere offene Einträge** | Realistisch (Nutzer startet heute, Vortag bleibt offen; oder Wochenende in Folge). Banner zeigt den **neuesten**, "+ n weitere"; Abarbeiten nacheinander (nach Auflösung Re-Check). Fortsetzen nur für den neuesten und nur wenn heute leer |
| **Sehr alter offener Eintrag (Wochen)** | Fortsetzen unterdrücken (> 24 h), "Jetzt" nicht anbieten, Soll-Ende als Vorschlag, Picker für Datum+Zeit, Warnhinweis bei > 16 h Netto. Jenseits des Vormonats nicht gefunden (akzeptierte Grenze) |
| **Saldo-Heuristik `lastUpdated == heute`** | `_load` zieht bei `lastUpdated == heute` den Tagesanteil des **geladenen** Eintrags vom gespeicherten Saldo ab. Würde der Beenden-Pfad `saveLastUpdateDate(now)` setzen, würde ein später gestarteter heutiger Timer nach Neustart fälschlich einen Tagesanteil abziehen. Deshalb: Beenden setzt `lastUpdated` nicht. Der Saldo ist ein laufender Gesamtwert, kein aus Einträgen berechneter: das inkrementelle Delta ist die einzig konsistente Fortschreibung. Gegen Doppelzählen: nur eine Beenden-Aktion je Eintrag (nach Save ist `workEnd` gesetzt, zweiter Aufruf wird abgewiesen) |
| **Saldo-Write schlägt fehl nach Entry-Save** | Reihenfolge Saldo zuerst, dann Eintrag (wie im Stop-Pfad); bei Fehler Banner behalten, Aktion wiederholbar. Rest-Risiko Teilfehler wie schon bei Stop (#402 bekannt) |
| **Profilwechsel** | Beenden-Aktion hält Repos/UseCases am Aktionsbeginn fest (Muster `_ActionCtx`), nie `ref.read` nach `await`. Hinweis pro aktivem Profil. Eingefrorener Eintrag in anderem Profil bleibt bis zur Rückkehr offen (nicht gescannt) |
| **Gleichzeitige Nutzung (anderes Gerät)** | Eintrag kann dort schon beendet/weitergeführt sein: vor dem Schreiben Eintrag frisch lesen und nur bei weiterhin `workEnd == null` schließen. Läuft derselbe Eintrag in der Web-App, überschreibt der Autosave dort das Ende wieder (Last-Write-Wins, bekannt) |
| **Reports zeigen offenen Eintrag** | Mobile `now`-basiert (hohe Dauer), Backend 0. Der Hinweis reduziert das Auftreten; Darstellung separates Issue. Nach Beenden korrekt |
| **Zeitzonen/DST** | Tag-Vergleich über lokale Kalendertage; Dauer-Berechnung mit absoluten `DateTime`-Differenzen; Soll-Ende über Addition von Duration (nicht Kalenderarithmetik); Tests als Invarianten |
| **Fehlermeldung ohne Nutzerdaten** | Logging per `logger.e` (Crashlytics), keine Eintragsinhalte loggen (Konvention aus `_load`) |
| **Nicht vorhandenes `updatedAt`** | "Letzte Aktivität" nicht belegbar -> kein Default daraus; ein Schema-Feld wäre Backend/Web-Vertrag (nicht empfohlen) |

## Offene Fragen (jeweils mit Empfehlung)

1. **Standard-Ende beim Beenden:** Vorschlag Soll-Ende (Start + Tagessoll + Pausen), Schnellwahl "Jetzt" nur bei <= 24 h, immer wählbar per Picker. "Letzte bekannte Aktivität" ist nicht ableitbar (kein `updatedAt`). Einverstanden? Empfehlung: ja.
2. **Fortsetzen: Umfang und Grenze:** nur wenn heute leer und Eintrag <= 24 h alt; sonst nur Beenden. Im selben PR oder als PR 1b? Empfehlung: Beenden/Hinweis zuerst sicher liefern, Fortsetzen im selben PR nur, wenn der Eingriff in `DashboardViewModel` klein bleibt (Plan-Phase entscheidet).
3. **Rückblick:** aktueller + Vormonat (2 Reads), nicht nur gestern. Empfehlung: ja. Soll es eine kürzere Grenze (z. B. 14 Tage) geben, damit ein uraltes Fragment nicht dauerhaft auftaucht? Empfehlung: nein, 2-Monats-Grenze genügt.
4. **"Später":** nur Sitzung (nicht persistent). Empfehlung: ja (Datenmangel soll beim nächsten Start wieder sichtbar sein).
5. **Mehrere offene Einträge:** neuester zuerst, "+ n weitere", sequenziell. Empfehlung: ja; eine Listenansicht ist nicht nötig.
6. **Beenden mit offener Pause:** Pause zum gewählten Ende schließen (statt verwerfen). Empfehlung: ja.
7. **Auto-Pausen beim Nachtragen:** wie beim normalen Stop anwenden (Pflichtpausen, nur Typ work)? Empfehlung: ja, damit Nachtragen und Stop dasselbe Ergebnis liefern; Nutzer kann im Bearbeiten-Dialog der Reports nachkorrigieren.
8. **Gleitzeit beim Beenden:** inkrementelles Delta ohne `lastUpdated`-Änderung (siehe Datenrisiken). Empfehlung: ja. Alternative (`lastUpdated` setzen) wird verworfen.
9. **Profile:** nur aktives Profil prüfen; keine Suche in anderen Profilen. Empfehlung: ja, als dokumentierte Grenze.
10. **Reports-Darstellung offener Einträge (Mobile `now` vs. Backend 0):** separates Folge-Issue anlegen? Empfehlung: ja, nicht in #385.
11. **Web-PR:** nach Mobile, mit gleichem Konzept; `WorkEntryService.getEntriesForMonth` bekommt optionales `profileId`. Empfehlung: ja, getrennter PR, Texte in `de.json`/`en.json`.
12. **Re-Check beim Zurückkehren in die App (`resumed`)?** Der Hinweis entsteht nur bei Kaltstart/Profil-/Auth-Wechsel; ein am anderen Gerät offen gelassener Eintrag würde erst beim nächsten Start erscheinen. Empfehlung: nicht in PR 1 (zusätzliche Reads), ggf. später.

## Entscheidungen zu den offenen Fragen (Hauptsession)

Verbindliche Produktentscheidung des Maintainers: nur Hinweis, kein automatisches Teilen (#381 nicht Teil).

1. Standard-Ende beim Beenden: Soll-Ende (Start + Tagessoll + Pausen); „Jetzt" nur bei höchstens 24 h Abstand, sonst Picker. Der Nutzer wählt Datum + Zeit im Dialog.
2. Aufteilung: PR 1 = Banner mit **Beenden** und **Später** (löst das Datenproblem). **Fortsetzen** (nur wenn heute leer und Eintrag höchstens 24 h alt) kommt als eigener PR 1b danach, weil es das ViewModel stärker anfasst.
3. Suche: aktueller + Vormonat (2 Reads), gefiltert auf `type == work`, `workEnd == null`, Datum vor heute.
4. „Später" nur pro Sitzung, nicht persistent.
5. Mehrere offene Einträge: neuester zuerst, „+ n weitere", nacheinander.
6. Offene Pause beim Beenden zum gewählten Ende schließen.
7. Auto-Pausen beim Nachtragen wie beim Stop anwenden.
8. Saldo beim Beenden inkrementell (alt + Netto − Soll am Eintragsdatum), `lastUpdated` NICHT ändern (Heuristik in `_load`); danach Reload mit `dayChange: true`.
9. Nur das aktive Profil prüfen, dokumentierte Grenze.
10. Folge-Issue Mobile-Reports/offene Einträge: angelegt (#404).
11. Web als getrennter PR nach Mobile mit gleichem Konzept (Parität; `getEntriesForMonth` mit optionalem `profileId`).
12. Kein zusätzlicher Re-Check bei `resumed` in PR 1.
13. Banner nicht-modal neben `HolidayBanner` (kein Dialog beim Start); Premium-Gating nicht nötig. Texte ARB de (duzen) + en; Dark Mode und Semantics prüfen.
