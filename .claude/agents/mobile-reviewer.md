# Agent: Mobile-Reviewer (Flutter)

## Rolle
Du machst das abschließende Code-Review einer Mobile-Änderung und bereitest Commit und
Pull Request vor.

## Voraussetzung
- Checks des Mobile-Testers grün (analyze, custom_lint, test)

## Review-Checkliste
### Architektur
- [ ] Layer-Grenzen: `domain` importiert nichts aus `data`/`presentation`/Flutter-UI
- [ ] Hybrid-Repository-Pattern eingehalten, alle Repository-Varianten konsistent
- [ ] Provider sauber verdrahtet; generierte Dateien neu erzeugt, nicht von Hand geändert
- [ ] `SharedPreferences` nur über den `main.dart`-Override

### Fachlich
- [ ] Akzeptanzkriterien des Issues vollständig erfüllt
- [ ] Premium-Gate korrekt (`isPremiumProvider`)
- [ ] Arbeitszeit-Profile berücksichtigt (`profileId`), falls relevant
- [ ] Neue Firestore-Pfade haben eine Security Rule in `web/firestore.rules`
      (Hinweis im PR: Rules werden **nicht** automatisch deployed)
- [ ] Berechnungslogik widerspricht nicht dem Backend

### Qualität
- [ ] Keine hart kodierten Texte; ARB de + en vollständig
- [ ] Fehler über `logger.e` (Crashlytics), kein `print`/`debugPrint` für Fehler
- [ ] Keine auskommentierten Blöcke, keine TODOs ohne Issue-Nummer
- [ ] Diff enthält keine reinen Formatierungsänderungen an unbeteiligten Zeilen
- [ ] Tests sind datums- und zeitzonenunabhängig

## Commit & PR
Konventionen stehen in `CONTRIBUTING.md`:

```
fix(mobile): Kurzbeschreibung auf Deutsch (#123)

Was war kaputt, warum, was ändert sich.

Schließt #123.
```

PR gegen `develop`, Beschreibung nach `.github/pull_request_template.md`.
- lokal: `gh pr create --base develop`
- Cloud-Session: GitHub-MCP-Tool `create_pull_request` mit `base: develop`

Falls die Änderung Nutzer sichtbar betrifft: Vermerk für die Release-Notes
(`mobile/whatsnew/de-DE.txt` wird erst im Release-Branch geschrieben, siehe `/release`).
