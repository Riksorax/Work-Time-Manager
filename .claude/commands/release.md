# /release — Release vorbereiten (develop → main)

Argumente: $ARGUMENTS  (erwartet: `<Version> <Charakter>`, z. B. `1.4.3 Axel`)

Der vollständige Ablauf steht in `CONTRIBUTING.md` („Release“). Dieser Command führt
die Schritte aus, die im Repo passieren. Schritte in der Play Console oder auf dem Server
nur ansagen, nicht selbst ausführen.

## Vorbedingungen prüfen
1. `develop` ist grün (CI-Lauf des letzten Commits, GitHub-MCP `actions_list`).
2. Version folgt SemVer und ist größer als die aktuelle in `mobile/pubspec.yaml`.
3. Der Charakter steht in `RELEASE_NAMES.md` unter „Noch frei“ (exakte Schreibweise).
   Fehlt er: Nutzer fragen, keinen Namen erfinden.
4. Nutzer daran erinnern: Der geschlossene Test-Track `<Version> <Charakter>` muss in der
   Play Console **vorher** angelegt sein.

## Release-Branch
```bash
git fetch origin develop
git checkout -b release/v<Version>-<Charakter-mit-Bindestrichen> origin/develop
git push -u origin release/v<Version>-<Charakter-mit-Bindestrichen>
```
Der Push startet `version-bump.yml`: Es trägt die Version in `mobile/pubspec.yaml` und den
Charakter in `RELEASE_NAMES.md` ein und committet das. Danach `git pull`.

## Versionshinweise
1. Nutzer-sichtbare Änderungen seit dem letzten Release sammeln:
   `git log --oneline origin/main..origin/develop` plus die zugehörigen Issues.
2. `mobile/whatsnew/de-DE.txt` überschreiben: Deutsch, **max. 500 Zeichen**, nur dieses Release.
   Länge prüfen: `wc -m mobile/whatsnew/de-DE.txt`.
3. Commit: `docs(release): Versionshinweise für <Version> (<Charakter>)`, pushen.

## Pull Request
PR `release/v…` → `main`, Titel `Release <Version> (<Charakter>)`, Beschreibung nach
`.github/pull_request_template.md` mit:
- Liste der enthaltenen Issues/PRs
- manuelle Deploy-Schritte (z. B. `firebase deploy --only firestore:rules` aus `web/`,
  neue Secrets)
Gemergt wird per **Squash**.

## Nach dem Merge (ansagen bzw. mit Freigabe ausführen)
1. Deploy-Workflows beobachten: `flutter-production.yml`, `deploy-api.yml`, `deploy-angular.yml`.
   Die Smoke-Tests am Ende von API- und Web-Deploy müssen grün sein.
2. `main` zurück nach `develop` mergen:
   ```bash
   git fetch origin
   git checkout develop && git merge --no-ff origin/main -m "Merge branch 'main' into develop (Version <Version> zurückmergen)"
   git push origin develop
   ```
3. Release-Branch löschen: `git push origin --delete release/v<Version>-<Charakter>`.
