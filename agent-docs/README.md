# Work-Time-Manager — Angular Web Version

> **WICHTIGE VORGABE:** Die Angular Web-App muss 1:1 exakt dieselben Funktionen bieten wie die Flutter App. Das UI soll an das Web (Desktop/Browser) angepasst werden, aber alle Funktionen und Features müssen lückenlos vorhanden sein.

## Agent-Plan Master-Dokument

Dieses Repository enthält den vollständigen Agent-Plan zum Aufbau der Angular Web-Version des Work-Time-Managers. Jeder Agent ist eine eigenständige Aufgabeneinheit.

---

## Agents im Überblick

| # | Agent | Fokus | Status |
|---|---|---|---|
| 00 | [Flutter Analyst](./AGENT-00-analyst.md) | Business-Logik, Entities & UseCases extrahieren | ✅ Abgeschlossen |
| 01 | [Architect](./AGENT-01-architect.md) | Angular Setup, Routing, Core-Services | ✅ Abgeschlossen |
| 02 | [Security](./AGENT-02-security.md) | Firebase Rules, Auth-Guards, Interceptor | ⬜ Geplant |
| 03 | [Feature-Lead Core](./AGENT-03-core.md) | Zeitberechnung & Dashboard | ⬜ Geplant |
| 04 | [Feature-Lead Reports](./AGENT-04-reports.md) | Statistiken & Berichte | ⬜ Geplant |
| 05 | [Feature-Lead Premium](./AGENT-05-premium.md) | RevenueCat-Integration & Profile | ⬜ Geplant |
| 06 | [UI/UX Refinement](./AGENT-04-ui-ux.md) | Responsive Design & Material 3 | ⬜ Geplant |
| 07 | [CI/CD & Deployment](./AGENT-07-cicd.md) | Automatisierung & Hosting | ⬜ Geplant |

---

## Architektur-Vorgaben (Angular Web)

- **Framework:** Angular 18+ (Standalone Components, Signals)
- **UI:** Angular Material 3 & [Stitch Methodology](https://stitch.withgoogle.com/)
- **Backend:** Firebase (identische Datenbank wie Flutter App)
- **Security:** Firebase App Check, Strict Auth Guards, CSP Header

## Arbeitsweise & Git-Guidelines
1. **Agents:** Jeder Agent arbeitet in seiner `.md` Datei.
2. **Commits:** Strukturierte Commits nach jedem Agent-Schritt:
   - `docs: setup agent system for [Agent Name]`
   - `feat: port core business logic (Agent 03)`
   - `ui: implement responsive dashboard via stitch (Agent 04)`
3. **Quell-Ordner:** Flutter Code in `/mobile`, Angular Code in `/web`.
