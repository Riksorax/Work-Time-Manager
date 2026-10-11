# Mobile-Reviewer (Flutter) — Referenz Phase „Review“

> Lies zuerst `mobile/CLAUDE.md`.

## Rolle
Du machst das abschließende Code-Review einer Mobile-Änderung und bereitest Commit und
Pull Request vor.

## Voraussetzung
- Checks des Mobile-Testers grün (analyze, custom_lint, test)

## Review-Checkliste
### Architektur
- [ ] Layer-Grenzen: `domain` importiert nichts aus `data`/`presentation`/Flutter-UI
- [ ] Repository-Muster des Projekts eingehalten, alle Varianten konsistent
- [ ] Provider sauber verdrahtet; generierte Dateien neu erzeugt, nicht von Hand geändert
- [ ] `SharedPreferences` nur über den `main.dart`-Override

### Fachlich
- [ ] Akzeptanzkriterien des Issues vollständig erfüllt
- [ ] Feature-Gate (z. B. Premium) korrekt
- [ ] Mandanten-/Profil-Bezug berücksichtigt, falls relevant
- [ ] Neue Datenpfade haben eine Zugriffsregel (Security Rule); Hinweis im PR, falls Regeln
      nicht automatisch deployt werden
- [ ] Berechnungslogik widerspricht nicht der kanonischen Plattform (Root-`CLAUDE.md`)

### Qualität
- [ ] Keine hart kodierten Texte; ARB in allen Sprachen vollständig
- [ ] Fehler über den zentralen Logger (Crashlytics), kein `print`/`debugPrint` für Fehler
- [ ] Keine auskommentierten Blöcke, keine TODOs ohne Issue-Nummer
- [ ] Tests sind datums- und zeitzonenunabhängig

## Commit & PR
Konventionen stehen in `CONTRIBUTING.md` bzw. im Abschnitt „Arbeitsablauf“ der Root-`CLAUDE.md`:

```
fix(mobile): Kurzbeschreibung (#123)

Was war kaputt, warum, was ändert sich.

Closes #123
```

Die `Closes #123`-Zeile ist Pflicht — nur das englische Schlüsselwort schließt das Issue
beim Merge automatisch.

PR gegen den Integrationsbranch, Beschreibung nach `.github/pull_request_template.md`, falls es das gibt.
- lokal: `gh pr create --base <integrationsbranch>`
- Cloud-Session: GitHub-MCP-Tool `create_pull_request` mit `base: <integrationsbranch>`

Falls die Änderung für Nutzer sichtbar ist: Vermerk für die Release-Notes im PR.
