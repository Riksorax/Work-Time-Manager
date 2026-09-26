# Arbeitsablauf: vom Issue bis zum Deployment

Dieses Dokument beschreibt den Weg einer Änderung durch das Monorepo.
Architektur und Code-Regeln stehen in `CLAUDE.md` (Root) sowie in `mobile/CLAUDE.md`,
`web/AGENTS.md` und `server/CLAUDE.md`.

## Überblick

```
Issue ──► Branch von develop ──► PR gegen develop (Squash) ──► release/v<Version>-<Charakter>
      ──► PR gegen main (Squash) ──► Deploy (Play Store, API, Web) ──► main zurück nach develop
```

| Branch | Zweck | Ziel des PR | Merge |
|---|---|---|---|
| `develop` | Integrationsbranch, immer lauffähig | – | – |
| `feature/<issue>-<kurz>` | neue Funktion | `develop` | Squash |
| `fix/<issue>-<kurz>` | Fehlerbehebung | `develop` | Squash |
| `claude/<…>` | von Claude-Code-Cloud-Sessions vorgegeben | `develop` | Squash |
| `release/v<Version>-<Charakter>` | Release-Vorbereitung | `main` | Squash |
| `main` | Produktionsstand, jeder Push deployt | – | – |

Nach dem Merge wird der Branch gelöscht (GitHub-Button „Delete branch“ bzw.
`git push origin --delete <branch>`).

## 1. Issue

Neue Arbeit beginnt mit einem Issue (Vorlagen unter `.github/ISSUE_TEMPLATE/`).
Wichtig für die Umsetzung sind:

- betroffene Plattformen (Mobile, Web, Backend)
- Premium ja/nein
- Akzeptanzkriterien

Mit Claude Code: `/issue <nr>` liest das Issue, legt den Branch an und wählt den
passenden Workflow.

## 2. Umsetzung

| Plattform | Workflow |
|---|---|
| Mobile | `/mobile-analyze` → `/mobile-plan` → `/mobile-implement` → `/mobile-validate` → `/mobile-review` |
| Web (Flutter-Port) | `/web-analyze` → `/web-design` → `/web-plan` → `/web-implement` → `/web-review` |
| Backend | `/server-implement` |
| mehrere | Cross-Platform-Coordinator (`.claude/agents/cross-platform-coordinator.md`): Backend zuerst, dann Web, dann Mobile, ein PR pro Plattform |

Lokale Checks entsprechen der CI (`.github/workflows/ci.yml`):

```bash
# mobile/
flutter analyze --no-fatal-infos && dart run custom_lint && flutter test
# web/
npm test -- --watch=false && npm run build -- --configuration production
# server/
dotnet build WorkTimeManager.slnx -c Release && dotnet test WorkTimeManager.slnx -c Release
```

In Claude-Code-Cloud-Sessions installiert `.claude/hooks/session-start.sh` Flutter,
.NET und die npm-Pakete automatisch.

## 3. Commits

Format (Conventional Commits, Titel auf Deutsch, Issue-Nummer am Ende):

```
<typ>(<scope>): <Kurzbeschreibung> (#<issue>)

<Was war das Problem, warum diese Lösung, was ändert sich.>

Schließt #<issue>.
```

| Typ | Verwendung |
|---|---|
| `feat` | neue Funktion |
| `fix` | Fehlerbehebung |
| `refactor` | Umbau ohne Verhaltensänderung |
| `test` | nur Tests |
| `docs` | Dokumentation, Versionshinweise |
| `chore` | Build, Abhängigkeiten, Release-Bump |

Scope:

| Änderung | Scope | Beispiel |
|---|---|---|
| betrifft genau eine Plattform | `mobile`, `web`, `api` | `fix(mobile): … (#267)` |
| betrifft mehrere Plattformen | Feature-Bereich: `reports`, `settings`, `dashboard`, `overtime`, `notifications`, `auth`, `profiles` | `feat(reports): Wochen-Reflexion (#137)` |
| Technik ohne App-Code | `ci`, `infra`, `deps`, `release`, `claude` | `fix(ci): …` |

Keine verschachtelten Scopes wie `web/reports`.

## 4. Pull Request

- Ziel ist `develop` (Ausnahme: Release-Branches → `main`).
- Beschreibung nach `.github/pull_request_template.md`.
- CI muss grün sein: Flutter, Angular und .NET laufen bei jedem PR.
- Rote Tests werden behoben, nicht übersprungen.
- Gemergt wird per **Squash**, der PR-Titel wird zum Commit-Titel.

## 5. Release

Mit Claude Code: `/release <Version> <Charakter>`.

1. **Vorbereiten:** Den geschlossenen Test-Track `<Version> <Charakter>` in der Google Play
   Console anlegen und mit Testern verknüpfen. Die API kann keine Tracks anlegen.
2. **Branch:** `release/v<Version>-<Charakter>` von `develop` abzweigen und pushen,
   z. B. `release/v1.4.3-Axel` oder `release/v1.5.0-Micky-Maus`. Der Charakter muss in
   `RELEASE_NAMES.md` unter „Noch frei“ stehen.
3. **Automatischer Bump:** `version-bump.yml` setzt die Version in `mobile/pubspec.yaml`
   und trägt den Charakter in `RELEASE_NAMES.md` ein. Danach `git pull`.
4. **Versionshinweise:** `mobile/whatsnew/de-DE.txt` überschreiben, höchstens 500 Zeichen,
   Commit `docs(release): Versionshinweise für <Version> (<Charakter>)`.
5. **PR** `release/v…` → `main` mit Titel `Release <Version> (<Charakter>)`, Squash-Merge.
6. **Deploy** startet automatisch (siehe unten).
7. **Zurückmergen:** `main` nach `develop` mergen,
   Commit `Merge branch 'main' into develop (Version <Version> zurückmergen)`.
8. Release-Branch löschen.

**Hotfix:** Dringende Korrekturen laufen genauso, nur zweigt der Release-Branch von `main`
statt von `develop` ab (Patch-Version, neuer Charakter). Danach wie gewohnt zurückmergen.

## 6. Deployment

Jeder Push auf `main` startet:

| Workflow | Ergebnis | Prüfung danach |
|---|---|---|
| `flutter-production.yml` | Android-AAB im geschlossenen Test-Track `<Version> <Charakter>` | Play Console |
| `deploy-api.yml` | Image `riksorax/work-time-manager-api`, Deploy auf Hetzner | Smoke-Test `https://api.work-time-manager.app/health` |
| `deploy-angular.yml` | Image `riksorax/work-time-manager-web`, Deploy auf Hetzner | Smoke-Test `https://work-time-manager.app/` |

Die Smoke-Tests laufen als letzter Schritt der Deploy-Workflows. Schlagen sie fehl,
ist der Workflow rot. Dauerhafte Überwachung übernimmt Uptime-Kuma unter
`https://status.work-time-manager.app`.

Ein manueller Start per `workflow_dispatch` auf einem anderen Branch als `main` baut und
pusht nur das Image. Auf `main` gestartet, deployt er auch.

**Manuelle Schritte** (im Release-PR aufführen):

- **Firestore Security Rules** werden nicht automatisch deployt. Nach einer Änderung an
  `web/firestore.rules` aus `web/` ausführen:
  ```bash
  firebase deploy --only firestore:rules --project worktime-56c7a
  ```
- **Neue Secrets/Variablen** vor dem Merge in den GitHub-Einstellungen anlegen
  (Liste in `CLAUDE.md`, Abschnitt „CI/CD“).

## 7. Rollback

**API oder Web:** Jeder Deploy pusht ein Image mit Zeitstempel-Tag (`YYYYMMDD-HHmmss`).

1. *Schnell:* In GitHub Actions den letzten funktionierenden Lauf von `deploy-api.yml` bzw.
   `deploy-angular.yml` öffnen und nur den Job „Deploy → Hetzner“ erneut ausführen.
   Der Job nutzt die Ausgaben des ursprünglichen Laufs und deployt damit dessen Image-Tag.
2. *Sauber:* Den fehlerhaften Commit auf einem Hotfix-Release-Branch zurücknehmen
   (`git revert`), PR nach `main`, danach zurückmergen. So stimmen Code und Produktion
   wieder überein.

Nach Variante 1 ist `main` weiterhin fehlerhaft. Der nächste Push auf `main` deployt den
Fehler erneut, bis Variante 2 erledigt ist.

**Android-App:** Ein veröffentlichtes AAB lässt sich nicht zurückrollen. In der Play Console
die Einführung stoppen und einen Hotfix mit höherer Version veröffentlichen.

## 8. Claude Code

| Datei | Inhalt |
|---|---|
| `CLAUDE.md` | Architektur, Datenpfade, Regeln für alle Plattformen |
| `mobile/CLAUDE.md`, `web/AGENTS.md`, `server/CLAUDE.md` | Plattformregeln |
| `.claude/agents/` | Rollen: `mobile-*`, `web-*`, `server-developer`, `cross-platform-coordinator` |
| `.claude/commands/` | `/issue`, `/release`, `/mobile-*`, `/web-*`, `/server-implement` |
| `.claude/hooks/session-start.sh` | Installiert die Toolchains in Cloud-Sessions |

In Cloud-Sessions gibt es kein `gh`. PRs und Issues laufen dort über die GitHub-MCP-Tools.
