# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Sie wird in jeder Session geladen — hier nur, was für alle Plattformen gilt. Plattform-Details
stehen in `mobile/CLAUDE.md`, `web/CLAUDE.md` und `server/CLAUDE.md` (werden erst geladen, wenn
Claude in dem Ordner arbeitet).

## Repository Structure

Monorepo einer deutschen Arbeitszeit-App:

- `mobile/` — Flutter-App (primär, produktiv). Clean Architecture, Riverpod, Hybrid-Repositories. → `mobile/CLAUDE.md`
- `web/` — Angular-Port der Flutter-App, gleiches Firebase-Backend. → `web/CLAUDE.md`
- `server/` — .NET-10-Backend-API, Firebase-Auth + Firestore, kanonische Rechenlogik. → `server/CLAUDE.md`

**Arbeitsablauf** (Branches, Commits, PRs, Release, Deployment inkl. Secrets, Rollback): `CONTRIBUTING.md`.
Integrationsbranch ist `develop`; PRs gehen gegen `develop`, nur Release-Branches gegen `main`.

## Checks je Plattform

| Plattform | Aus | Checks (wie CI) |
|---|---|---|
| Mobile | `mobile/` | `dart format --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test` |
| Web | `web/` | `npm test -- --watch=false && npm run build -- --configuration production` |
| Backend | `server/` | `dotnet build WorkTimeManager.slnx -c Release && dotnet test WorkTimeManager.slnx -c Release` |
| Cloud Functions | `web/functions/` | `npm run build && npm test` (Installation: `npm install --legacy-peer-deps` — reines npm ohne den Flag lässt Arborist bei vitest 4 abstürzen) |

## CI/CD

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | PRs und Push auf alle Branches außer `main` | Flutter Analyze & Test, Angular Test & Build, Cloud Functions Build & Test, .NET Build & Test |
| `flutter-production.yml` | Push auf `main` oder `workflow_dispatch` | Android AAB → Google Play (Closed Testing Track `<Version> <Charakter>`, ab 1.6 `<Major>.<Minor> <Charakter>`) |
| `deploy-angular.yml` | Push auf `main` oder `workflow_dispatch` | Angular Build → Docker Hub → Hetzner |
| `deploy-api.yml` | Push auf `main` oder `workflow_dispatch` | .NET Build & Test → Docker Hub → Hetzner |
| `version-bump.yml` | Push auf `release/v*` | Version in `mobile/pubspec.yaml`, Charakter in `RELEASE_NAMES.md` |

Details der Deploy-Workflows, Uptime-Monitoring und benötigte Secrets: `CONTRIBUTING.md`, „Deployment“.

## Firestore-Datenpfade (Flutter-kanonisch, gilt für alle Plattformen)

| Daten | Pfad | Felder |
|---|---|---|
| Arbeitseintrag | `users/{uid}/work_entries/{yyyy-MM}` | `days: { "5": { date, workStart, workEnd, breaks, ... } }` |
| Pause (in Eintrag) | (eingebettet in days-Map) | `{ name, start, end }` — Flutter ignoriert `id`/`isAutomatic` |
| Gleitzeit | `users/{uid}/overtime/balance` | `minutes` (int), `lastUpdated` (Timestamp) |
| Einstellungen | `users/{uid}/settings/current` | nur Web — Flutter nutzt SharedPreferences |
| Profil/Premium | `users/{uid}` | `isPremium` (bool) |
| Wochen-Reflexion | `users/{uid}/weekly_reflections/{yyyy-Www}` | `whatWentWell`, `whatWasHard`, `updatedAt` — nur Mobile, nicht profilgebunden; Schlüssel = ISO-Wochenjahr + KW (Mo 29.12.2025 → `2026-W01`) |
| Zusätzliches Arbeitszeit-Profil | `users/{uid}/profiles/{profileId}` | `name` (string), `createdAt` (Timestamp) — siehe #138/#239 |
| Profil-Daten (Arbeitszeit-Profil) | `users/{uid}/profiles/{profileId}/{work_entries\|overtime\|settings}/...` | wie oben, nur unter dem Profil verschachtelt. Das Standard-Profil bleibt unter dem unveränderten `users/{uid}/...`-Pfad (keine Migration) |

Das Backend schreibt dieses Format ausschließlich über `FirestoreMappings`: days-Map-Schlüssel ohne
führende Null (`"5"`), Zeiten als `Timestamp`. `work-entries`/`overtime`/`settings`/`reports`-Endpunkte
nehmen optional `?profileId=...`; fehlt er oder ist er `"default"`, gilt der unveränderte Pfad.

**Rechenlogik:** Das Backend (`server/.../Domain/`) ist kanonisch, Web rechnet identisch. Flutter
weicht bekannt ab (Details `server/CLAUDE.md`, „Rechenlogik“) — neue Logik immer an das Backend
angleichen, nicht umgekehrt.

## Claude-Code-Workflows

Einstieg für jede Aufgabe: `/issue <nr>` — liest das Issue, bestimmt die Plattformen, legt den
Branch an und wählt den Workflow. Commands in `.claude/commands/`, Subagents in `.claude/agents/`.
Jede Phase läuft als Subagent in eigenem Kontext und übergibt ihr Ergebnis über
`<plattform>/thoughts/<nr>-*.md`; in die Hauptsession kommt nur eine Kurzfassung zurück.

| Command | Zweck |
|---|---|
| `/issue <nr>` | Issue einordnen, Branch anlegen, Workflow wählen |
| `/mobile-analyze` … `/mobile-review <nr>` | Flutter: Analyse → Plan → Implementierung → Validierung → Review |
| `/web-analyze` … `/web-review <nr>` | Web-Port eines Flutter-Features: Analyse → Design → Plan → Implementierung → Review |
| `/server-implement <nr>` | Backend-Änderung |
| `/release <Version> <Charakter>` | Release-Branch, Versionshinweise, Release-PR (ab 1.6 ein Charakter pro Minor-Linie) |
| `/auto-bugfix` | Cron-Routine: offene `bug`-Issues automatisch analysieren, bis zum review-fertigen PR umsetzen — **mergt nicht selbst**, das bleibt ein menschlicher Schritt |

Betrifft ein Issue mehrere Plattformen, plant der Subagent `cross-platform-coordinator` den
gemeinsamen Vertrag und die Reihenfolge Backend → Web → Mobile.

## Fehler-Monitoring (Crashlytics/Sentry/Uptime-Kuma) → Issue → Fix

Crashlytics (Mobile), Sentry (Web über `SENTRY_DSN_WEB`, Backend über `SENTRY_DSN_API` — zwei
getrennte Sentry-Projekte, gleiche Organisation) und Uptime-Kuma (`CONTRIBUTING.md`, „Deployment“)
sind für sich reine Beobachtung — sie legen von sich aus **kein** GitHub-Issue an. Zwei Brücken
schließen die Lücke:

- **Sentry** über seine eigene GitHub-Integration (einmal pro Organisation eingerichtet, gilt für
  alle Sentry-Projekte, je Projekt eine eigene Alert-Regel mit Label `bug`, Konfiguration in
  Sentry, kein Code hier).
- **Crashlytics und Uptime-Kuma** über eigene Firebase Cloud Functions unter `web/functions/`
  (siehe #322, Details in `CONTRIBUTING.md`, „Crashlytics-/Uptime-Kuma-Brücke“) — legen ebenfalls
  ein Issue mit Label `bug` an, dedupliziert über einen Marker-Kommentar im Body.

Sobald ein Issue das Label `bug` trägt (egal ob manuell oder durch Sentry angelegt), greift
`/auto-bugfix`.

**Cloud-Sessions:** `.claude/hooks/session-start.sh` installiert Flutter (Version aus `ci.yml`),
das .NET-10-SDK und die npm-Pakete. `gh` gibt es dort nicht, GitHub läuft über die MCP-Tools.

## Key Rules (Gesamt)

- `*.g.dart` / `*.mocks.dart` nicht editieren — generiert.
- `dart run build_runner build` nach `@Riverpod`-Änderungen.
- **Texte / i18n (#221):** Deutsch ist die Referenzsprache, Englisch wird mitgepflegt. Flutter: ARB (`mobile/lib/l10n/app_de.arb` + `app_en.arb`), nie hart kodiert. Web: ngx-translate (`web/public/i18n/de.json` + `en.json`) für neue Texte; ältere Web-Texte sind teils noch hart kodiert. Rechtstexte (Impressum/Datenschutz/AGB) bleiben nur Deutsch.
- Premium-Features hinter `isPremiumProvider` (Flutter) bzw. `ProfileService.isPremium` (Web).
- Hybrid-Layer nie umgehen — immer über `WorkEntryService` / `OvertimeService`.
- **Firestore Security Rules:** Neue Firestore-Pfade brauchen eine Regel in `web/firestore.rules`. Die Rules werden **nicht** automatisch deployt (`CONTRIBUTING.md`, „Deployment“).
- **Tests** dürfen nicht von Datum, Wochentag oder Zeitzone abhängen.
- **Branch-Hygiene**: Das Repo löscht Remote-Branches nach dem Merge automatisch (GitHub-Einstellung
  „Automatically delete head branches"). Nur falls das für einen Branch ausbleibt (z. B. bei
  manuell zusammengeführten PRs), manuell nachziehen: GitHub-Button "Delete branch" bzw.
  `git push origin --delete <branch>` — keine bereits gemergten `claude/*`-/`feature/*`-/`release/*`-Branches stehen lassen.
