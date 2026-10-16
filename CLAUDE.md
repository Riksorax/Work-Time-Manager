# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Sie wird in jeder Session geladen — hier nur, was für alle Plattformen gilt. Plattform-Details
stehen in `mobile/CLAUDE.md`, `web/CLAUDE.md` und `server/CLAUDE.md` (werden erst geladen, wenn
Claude in dem Ordner arbeitet).

## Repository Structure

Monorepo einer deutschen Arbeitszeit-App:

- `mobile/` — Flutter-App (primär, produktiv) → `mobile/CLAUDE.md`
- `web/` — Angular-Port der Flutter-App, Cloud Functions unter `web/functions/` → `web/CLAUDE.md`
- `server/` — .NET-10-Backend-API, kanonische Rechenlogik → `server/CLAUDE.md`

**Arbeitsablauf** (Branches, Commits, PRs, Release, Deployment inkl. Secrets, Rollback): `CONTRIBUTING.md`.
Integrationsbranch ist `develop`; PRs gehen gegen `develop`, nur Release-Branches gegen `main`.

## Checks je Plattform

| Plattform | Aus | Checks (wie CI) |
|---|---|---|
| Mobile | `mobile/` | `dart format --output=none --set-exit-if-changed lib test && flutter analyze --no-fatal-infos && dart run custom_lint && flutter test` (CI fährt `flutter test` zusätzlich unter `TZ=Europe/Berlin` und die Zonen-Regressionstests `*_tz_test.dart` unter `TZ=America/Los_Angeles` und `Pacific/Auckland`) |
| Web | `web/` | `npm test -- --watch=false && npm run build -- --configuration production` (UI-/E2E-Tests zusätzlich: `npm run e2e`; CI fährt `npm test` zusätzlich unter `TZ=Europe/Berlin` und die Zonen-Regressionstests `*.tz.spec.ts` unter `TZ=America/Los_Angeles` und `Pacific/Auckland`, Details `web/CLAUDE.md`) |
| Backend | `server/` | `dotnet build WorkTimeManager.slnx -c Release && dotnet test WorkTimeManager.slnx -c Release` |
| Cloud Functions | `web/functions/` | `npm run build && npm test` (Installation: `npm install --legacy-peer-deps` — reines npm ohne den Flag lässt Arborist bei vitest 4 abstürzen) |

## CI/CD

Workflows, Trigger und Secrets: `.github/workflows/` und `CONTRIBUTING.md`, „Deployment“. Ein Push auf `main` deployt.

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

Einstieg für jede Aufgabe: `/issue <nr>` (ordnet ein, legt den Branch an, nennt die passende Befehlskette). Die Phasen-Agents
(`analyst`, `developer`, `reviewer`) übergeben ihr Ergebnis über `<plattform>/thoughts/<nr>-*.md`; das Stack-Wissen laden sie aus
`.claude/skills/playbook-<flutter|angular|dotnet>/`, die Besonderheiten dieses Projekts aus `.claude/skills/playbook-projekt/`
(geht den Stack-Playbooks vor). Issues über mehrere Plattformen plant der Subagent `cross-platform-coordinator`
(Backend → Web → Mobile). `/auto-bugfix` mergt nie selbst, Ausnahme: Crash-Hotfix, siehe „Fehler-Monitoring“.

## Agent-Standard (Obsidian-Vault)

`.claude/` stammt aus dem Agent-Standard im Vault `Riksorax/obsidian-vault` (Ordner `_Claude/`); dieses Repo ist die
Herkunft des Standards. Änderungen mit `sync.sh promote` bzw. `update` abgleichen; `.claude/standard.lock` und
`standard.env` gehören ins Repo.

**Projektspezifisch, nicht im Standard:** das Projekt-Playbook `.claude/skills/playbook-projekt/` (Hybrid-Repositories,
Arbeitszeit-Profile, Premium, Rechenlogik, Konventionen, Design-System), `release.md` und `hooks/session-start.sh`. Die
`session-start.d`-Skripte des Standards sind bewusst nicht installiert (dieses Repo nutzt den eigenen Hook).

## Fehler-Monitoring (Crashlytics/Sentry/Uptime-Kuma) → Issue → Fix

Crashlytics, Sentry und Uptime-Kuma legen über Brücken Issues mit Label `bug` an (Sentry über seine GitHub-Integration,
Crashlytics und Uptime-Kuma über Cloud Functions unter `web/functions/`, siehe `CONTRIBUTING.md`, „Crashlytics-/Uptime-Kuma-Brücke“).
Sobald ein Issue das Label `bug` trägt (egal ob manuell oder automatisch angelegt), greift `/auto-bugfix`.

**Hotfix-Handling für Crash-Issues:** Stammt ein `bug`-Issue aus einer dieser drei Quellen —
erkennbar am Marker-Kommentar `<!-- auto-monitoring:crashlytics:... -->` bzw.
`<!-- auto-monitoring:uptime-kuma:... -->` im Body (Cloud Functions) oder, bei Sentry,
an einem `sentry.io/organizations/...`-Link im Body (Sentrys eigene GitHub-Integration, kein
eigener Marker) —, behandelt `/auto-bugfix` es als Hotfix und nicht wie ein normales Issue
(Branch/PR gegen `develop`):

- **Web/API:** Branch von `main` (nicht `develop`), PR gegen `main`. CI auf dem PR muss grün sein,
  danach `enable_pr_auto_merge` setzen — der Merge (und damit `deploy-api.yml`/`deploy-angular.yml`)
  läuft ohne weiteren menschlichen Schritt. Nach dem Deploy auf `main` zurück nach `develop` mergen
  (wie in `CONTRIBUTING.md`, „Release“, Schritt „Zurückmergen“), damit `develop` den Fix enthält.
- **Mobile:** Play-Store-Releases brauchen einen Versions-Bump und einen vorbereiteten
  Closed-Testing-Track (`CONTRIBUTING.md`, „Hotfix / Bugfix-Release“) — das lässt sich nicht
  gefahrlos automatisch mergen. `/auto-bugfix` bereitet den Fix als PR gegen `main` vor (Branch von
  `main`), aktiviert aber **kein** Auto-Merge; stattdessen im Issue vermerken, dass ein Mensch
  `/release` für den Hotfix anstoßen muss.
- Betrifft der Crash-Fix mehrere Plattformen, gilt die Ausnahme in Schritt 4 von `/auto-bugfix`
  weiter (nicht automatisch umsetzen, Rückfrage im Issue).

Normale, manuell gemeldete `bug`-Issues (kein Marker-Kommentar) laufen weiter wie bisher gegen
`develop`.

**Cloud-Sessions:** `.claude/hooks/session-start.sh` installiert die Toolchains. `gh` gibt es dort nicht, GitHub läuft über die MCP-Tools.

## Key Rules (Gesamt)

- **Texte / i18n (#221):** Deutsch ist die Referenzsprache, Englisch wird mitgepflegt. Flutter: ARB (`mobile/lib/l10n/app_de.arb` + `app_en.arb`), nie hart kodiert. Web: ngx-translate (`web/public/i18n/de.json` + `en.json`) für neue Texte; ältere Web-Texte sind teils noch hart kodiert. Rechtstexte (Impressum/Datenschutz/AGB) bleiben nur Deutsch.
- Premium-Features hinter `isPremiumProvider` (Flutter) bzw. `ProfileService.isPremium` (Web).
- Hybrid-Layer nie umgehen — immer über `WorkEntryService` / `OvertimeService`.
- **Firestore Security Rules:** Neue Firestore-Pfade brauchen eine Regel in `web/firestore.rules`. Die Rules werden **nicht** automatisch deployt (`CONTRIBUTING.md`, „Deployment“).
- **Tests** dürfen nicht von Datum, Wochentag oder Zeitzone abhängen.
