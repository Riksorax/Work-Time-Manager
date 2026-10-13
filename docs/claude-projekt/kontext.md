# Projektkontext: Work-Time-Manager

Projektwissen für ein Claude-Projekt. Stand: 2026-10-13. Quelle der Wahrheit bleiben die
`CLAUDE.md`-Dateien im Repo (Root, `mobile/`, `web/`, `server/`) und `CONTRIBUTING.md`.

## 1. Produkt

Deutsche Arbeitszeit-App: Timer für Arbeitsbeginn/-ende, Pausen (gesetzliche Mindestpausen
automatisch), tägliche und wöchentliche Soll-Stunden, Gleitzeit-/Überstunden-Saldo, Tages-, Wochen-,
Monats- und Jahresberichte, Urlaub/Krank/Feiertag je Bundesland, Wochen-Reflexion (nur Mobile),
mehrere Arbeitszeit-Profile, Premium-Funktionen per In-App-Kauf (RevenueCat). Zwei Sprachen: Deutsch
(Referenz) und Englisch. Ohne Konto arbeitet die App lokal (SharedPreferences bzw. localStorage), mit
Konto über Firebase.

## 2. Monorepo

| Ordner | Inhalt | Details |
|---|---|---|
| `mobile/` | Flutter-App (Android/iOS, primär, produktiv) | `mobile/CLAUDE.md` |
| `web/` | Angular-Port, gleiches Firebase-Backend; Cloud Functions in `web/functions/` | `web/CLAUDE.md` |
| `server/` | .NET-10-Backend-API, Firebase-Auth + Firestore | `server/CLAUDE.md` |
| `.claude/` | Agents, Commands, Playbooks (Claude Code) | `CLAUDE.md` Root |
| `store/`, `fastlane/` | Store-Metadaten, Screenshot-/Grafik-Briefings | – |
| `thoughts/` | Koordinationsnotizen für Mehrplattform-Issues | – |

## 3. Architektur je Plattform

### Mobile (Flutter)

- Clean Architecture: `lib/domain/` (Entities, Repository-Interfaces, Use Cases), `lib/data/`
  (Models, Repository-Impls, Datasources), `lib/presentation/` (Screens, ViewModels, Widgets), `lib/core/`.
- **Riverpod:** Infrastruktur (Datenquellen, Repositories, Use Cases) mit `@riverpod`-Codegen in
  `lib/core/providers/providers.dart`; ViewModels als manuell registrierte `NotifierProvider`s neben
  ihrem Notifier in `lib/presentation/view_models/`.
- **Hybrid-Repositories:** eingeloggt → Firestore, ausgeloggt → SharedPreferences
  (`HybridWorkRepositoryImpl`, `HybridOvertimeRepositoryImpl`). `DataSyncService` migriert lokale Daten beim Login.
- Zentrale „heute"-Quelle: `todayProvider`. Ein laufender Timer läuft über Mitternacht weiter; Soll und
  Überstunden bleiben am Eintragsdatum.
- Navigation: `HomeScreen` mit drei Tabs — Dashboard, Berichte, Einstellungen.
- Premium: `isPremiumProvider`; RevenueCat läuft nicht im Web-Build.
- i18n: ARB-Dateien `lib/l10n/app_de.arb` (Vorlage) und `app_en.arb`, danach `flutter gen-l10n`.

### Web (Angular)

- Vollständiger Port der Flutter-App; Standalone-Komponenten, Signals, OnPush, Vitest, Playwright (E2E),
  ngx-translate (`web/public/i18n/de.json` + `en.json`), Material (Dark Mode über ThemeService).
- Hybrid-Services in `core/services/`: `WorkEntryService`, `OvertimeService`, `SettingsService` —
  eingeloggt **Lesen live per Firestore `onSnapshot`, Schreiben über die .NET-API** (`ApiClient`);
  ausgeloggt localStorage.
- `WorkProfileService` (aktives/zusätzliche Profile), `ProfileService.isPremium`, `TodayService`
  (lokaler Tageswechsel), `LeaveBalanceService`, `DataSyncService`, `WebPremiumService`.
- Zeitzonen-Regressionstests `*.tz.spec.ts` laufen in CI unter `America/Los_Angeles` und `Pacific/Auckland`.

### Backend (.NET)

- Minimal-API unter `/api` (alles authentifiziert, UID nur aus dem Token), `/health` ohne Auth.
- Ordner: `Contracts/` (DTOs), `Firestore/` (POCOs, `FirestoreMappings` als einziger Mapping-Ort,
  Repositories über `ProfileScope`), `Domain/` (`BreakCalculator`, `ReportCalculator`, pure Logik),
  `Endpoints/`.
- Endpunkte: `me`, `work-entries` (Monat/Tag, PUT, DELETE), `overtime` (GET/PUT mit optionalem
  `keepLastUpdated`), `settings` (inkl. `vacationDaysPerYear`, `bundesland`), `profile` (Premium),
  `reports` (daily/weekly/monthly/yearly), `work-profiles` (GET/POST/DELETE).
- Fehler-Tracking mit Sentry (nur wenn DSN konfiguriert).

## 4. Datenmodell (Firestore, Flutter-kanonisch)

| Daten | Pfad |
|---|---|
| Arbeitseintrag | `users/{uid}/work_entries/{yyyy-MM}` mit `days: { "5": { date, workStart, workEnd, breaks, … } }` |
| Pause (eingebettet) | `{ name, start, end }` |
| Gleitzeit | `users/{uid}/overtime/balance` (`minutes`, `lastUpdated`) |
| Einstellungen | `users/{uid}/settings/current` (Flutter nutzt SharedPreferences, Web/API Firestore) |
| Profil/Premium | `users/{uid}` mit `isPremium` |
| Wochen-Reflexion | `users/{uid}/weekly_reflections/{yyyy-Www}` (ISO-Wochenjahr + KW) |
| Zusätzliches Profil | `users/{uid}/profiles/{profileId}`; dessen Daten darunter nach demselben Schema |

Das Standard-Profil bleibt am alten Pfad (keine Migration). days-Map-Schlüssel ohne führende Null,
Zeiten als `Timestamp`. Eintragstypen: `work`, `vacation`, `sick`, `holiday`.

## 5. Fachlogik

- Gesetzliche Pause: 30 Min nach 6 h, 45 Min nach 9 h Arbeitszeit (`BreakCalculator`).
- Gleitzeit = gespeicherter Saldo (Basis aus Vortagen) + Tagesdelta; offene Einträge vor heute werden
  nachträglich beendet, ohne die „lastUpdated ist heute"-Heuristik auszulösen (`keepLastUpdated`).
- Jahresauswertung: Urlaub (Anspruch 0–366, Standard 30) und Krankheitstage; `holiday` zählt nicht.
- Bundesland steuert Feiertage; das Backend kennt keine Feiertagslogik.
- Wochennummern nach ISO 8601 (Jahreswechsel beachten, z. B. Mo 29.12.2025 → `2026-W01`).
- **Bekannte Abweichung:** Flutter rechnet noch anders als Backend/Web (doppelte Pausen-Subtraktion in
  Wochen-/Monatsbericht, ignoriert Urlaub/Krank/Feiertag, Tages-Überstunden = 0, vereinfachte KW,
  Monats-Gesamtüberstunden ohne Gleitzeit-Altsaldo). Ziel: Flutter auf die Backend-Logik ziehen.

## 6. Abwärtskompatibilität

Die Play-Store-Versionen sprechen ältere Vertragsformen. Deshalb: Felder nur hinzufügen; fehlende
optionale Felder erhalten das bisherige Verhalten (Beispiele: `keepLastUpdated`, `vacationDaysPerYear`,
`bundesland`, `profileId`). Deploy-Reihenfolge bei Vertragsänderung: **API vor Clients**.

## 7. Entwicklungsablauf

```
Issue → Branch von develop → PR gegen develop (Squash) → release/v<Version>-<Charakter>
      → PR gegen main (Merge-Commit) → Deploy → main zurück nach develop
```

- Commit-Format und Branch-Namen: siehe Projektanweisung. Conventional Commits, deutscher Titel,
  Issue-Nummer am Ende, letzte Zeile `Closes #<nr>`.
- CI (`ci.yml`, alle Branches außer `main`): Flutter Analyze & Test, Angular Test & Build, Web UI-Tests
  (Playwright je Browser), Cloud Functions Build & Test, .NET Build & Test.
- Deployment bei Push auf `main`: Android AAB → Google Play (Closed Testing Track), Angular → Docker Hub
  → Hetzner, API → Docker Hub → Hetzner (`https://api.work-time-manager.app/health`), GitHub Release.
- Firestore Security Rules (`web/firestore.rules`) werden **manuell** deployt.
- Releases: `<Version> <Charakter>` (Kingdom-Hearts-Figuren). Ab 1.6 ein Charakter pro Minor-Linie,
  Play-Track `<Major>.<Minor> <Charakter>` (z. B. `1.6 Saix`); Patch-Versionen nur Bugfixes.
- Fehler-Monitoring: Crashlytics (Mobile), Sentry (Web, API), Uptime-Kuma. Crashes landen als GitHub-Issue
  mit Label `bug`. Crash-Hotfixes laufen gegen `main`, danach Rückmerge nach `develop`; Mobile-Hotfixes
  brauchen einen Menschen für Versions-Bump und Track.

## 8. Claude-Code-Workflows (im Repo)

Einstieg `/issue <nr>`. Danach je Plattform: Flutter `/analysieren → /planen → /umsetzen → /validieren
→ /reviewen`; Angular-Port `/analysieren → /entwerfen → /planen → /umsetzen → /reviewen`; Backend
`/umsetzen <nr> dotnet`; Release `/release <Version> <Charakter>`; Cron `/auto-bugfix`. Subagents
`analyst`, `developer`, `reviewer`, `cross-platform-coordinator`; Playbooks in `.claude/skills/playbook-*`.

## 9. Glossar

| Begriff | Bedeutung |
|---|---|
| Gleitzeit / Überstunden-Saldo | angesammelte Plus-/Minusminuten, gespeichert in `overtime/balance` |
| Hybrid | Datenzugriff schaltet nach Login-Status zwischen Cloud und lokalem Speicher |
| Arbeitszeit-Profil | getrennter Datensatz (z. B. zweiter Job) je Konto; „default" = Standard |
| Offener Eintrag | Eintrag mit Start, aber ohne Ende an einem Tag vor heute |
| Premium | per RevenueCat freigeschaltete Zusatzfunktionen (`isPremium`) |
| Charakter | Release-Beiname aus Kingdom Hearts |

## 10. Typische Aufgaben für dieses Projekt

- Issue analysieren und auf Plattformen aufteilen; Akzeptanzkriterien und Testfälle formulieren.
- Feature von Flutter nach Angular portieren (UI-Mapping, Signals, i18n, Parität mit Backend-Rechenlogik).
- API-Vertragsänderung abwärtskompatibel entwerfen (DTO, Mapping, Endpunkt-Test, Deploy-Reihenfolge).
- Rechenfehler eingrenzen: gleiche Eingabe in Backend, Web und Flutter gegenüberstellen.
- Release- und Store-Texte (`mobile/whatsnew/de-DE.txt`, `fastlane/metadata`) formulieren.
- Review eines eingefügten Diffs gegen die Regeln aus der Projektanweisung.
