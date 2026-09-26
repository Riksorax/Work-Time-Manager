# /issue — Einstieg: GitHub-Issue in Arbeit überführen

Issue: $ARGUMENTS

## Aufgabe

1. **Issue lesen:** GitHub-MCP `issue_read` (Cloud-Session) bzw. `gh issue view $ARGUMENTS --comments`
   (lokal) für `Riksorax/Work-Time-Manager`. Verlinkte Issues und PRs ebenfalls lesen.

2. **Einordnen:**
   - Typ: Bug, Feature, Chore oder Doku
   - Plattformen: Backend (`server/`), Web (`web/`), Mobile (`mobile/`), CI/Infra (`.github/`, `server/docker-compose.yml`)
   - Premium-Feature? Arbeitszeit-Profil-bezogen? Neue Texte? Neuer Firestore-Pfad?
   - Unklarheiten, die die Umsetzung wesentlich ändern → dem Nutzer vorlegen, bevor es weitergeht.

3. **Branch anlegen** von aktuellem `develop` (Konvention aus `CONTRIBUTING.md`):
   ```bash
   git fetch origin develop
   git checkout -b <typ>/$ARGUMENTS-<kurzbeschreibung> origin/develop
   ```
   `<typ>` = `feature` oder `fix`. Ist in der Session bereits ein Branch vorgegeben
   (z. B. `claude/...`), diesen verwenden statt einen neuen anzulegen.

4. **Workflow wählen und starten:**

| Ergebnis | Nächster Schritt |
|---|---|
| nur Mobile | `/mobile-analyze $ARGUMENTS` |
| nur Web, Portierung eines Flutter-Features | `/web-analyze <feature>` |
| nur Web, sonst | Web-Developer-Agent (`.claude/agents/web-developer.md`) mit kurzem Plan |
| nur Backend | `/server-implement $ARGUMENTS` |
| mehrere Plattformen | Cross-Platform-Coordinator (`.claude/agents/cross-platform-coordinator.md`) |
| CI/Infra | direkt umsetzen; bei Deploy-Workflows `CONTRIBUTING.md` („Deployment“) beachten |

5. **Kurzbericht an den Nutzer:** Einordnung, Branch-Name, gewählter Workflow, offene Fragen.
