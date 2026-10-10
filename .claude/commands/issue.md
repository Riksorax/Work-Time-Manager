# /issue — Einstieg: GitHub-Issue in Arbeit überführen

Issue: $ARGUMENTS

> Repo, Integrationsbranch, Plattform-Ordner und Checks stehen in der Root-`CLAUDE.md`.
> Konventionen für Branches, Commits und PRs stehen in `CONTRIBUTING.md` oder — wenn es die nicht
> gibt — im Abschnitt „Arbeitsablauf“ der Root-`CLAUDE.md`.

## Aufgabe

1. **Issue lesen:** GitHub-MCP `issue_read` (Cloud-Session) bzw. `gh issue view $ARGUMENTS --comments`
   (lokal) für das Repo aus der Root-`CLAUDE.md`. Verlinkte Issues und PRs ebenfalls lesen.

2. **Einordnen:**
   - Typ: Bug, Feature, Chore oder Doku
   - Plattformen: die Ordner aus der Root-`CLAUDE.md` („Repository Structure“) plus CI/Infra
   - Projektspezifische Fragen aus den „Key Rules“ der Root-`CLAUDE.md` (z. B. Premium-Feature,
     neue Texte, neue Datenpfade, Rechenlogik)
   - Unklarheiten, die die Umsetzung wesentlich ändern → dem Nutzer vorlegen, bevor es weitergeht.

3. **Branch anlegen** vom aktuellen Integrationsbranch (Konvention aus `CONTRIBUTING.md`):
   ```bash
   git fetch origin <integrationsbranch>
   git checkout -b <typ>/$ARGUMENTS-<kurzbeschreibung> origin/<integrationsbranch>
   ```
   `<typ>` = `feature` oder `fix` (bzw. `feat`/`fix` laut Projektkonvention). Ist in der Session
   bereits ein Branch vorgegeben (z. B. `claude/...`), diesen verwenden statt einen neuen anzulegen.

4. **Workflow wählen und starten:**

| Ergebnis | Nächster Schritt |
|---|---|
| nur Mobile (Flutter) | `/analysieren $ARGUMENTS flutter`, dann `/planen`, `/umsetzen`, `/validieren`, `/reviewen` |
| nur Web, Portierung eines Flutter-Features | `/analysieren $ARGUMENTS angular`, `/entwerfen`, `/planen`, `/umsetzen`, `/reviewen` |
| nur Web, sonst | kurzen Plan mit dem Nutzer abstimmen, dann `/umsetzen $ARGUMENTS angular` (bzw. `react`) |
| nur Backend (.NET) | Vertrag festlegen, dann `/umsetzen $ARGUMENTS dotnet` |
| mehrere Plattformen | Subagent `cross-platform-coordinator`, danach die Workflows in der Reihenfolge, die er zurückgibt |
| CI/Infra | direkt umsetzen; bei Deploy-Workflows `CONTRIBUTING.md` („Deployment“) beachten |

   Gibt es den Workflow-Command im Projekt nicht (Modul nicht installiert), den Plan mit dem
   Nutzer abstimmen und direkt umsetzen.

5. **Kurzbericht an den Nutzer:** Einordnung, Branch-Name, gewählter Workflow, offene Fragen.
