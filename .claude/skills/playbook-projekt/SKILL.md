---
name: playbook-projekt
description: "Besonderheiten von Work-Time-Manager (Arbeitszeit-App: Flutter, Angular, .NET, Firebase): Hybrid-Repositories, Arbeitszeit-Profile, Premium-Gate, kanonische Rechenlogik im Backend, Konventionen, PR und Hotfix. Wird von den Phasen-Agents zusätzlich zum Stack-Playbook gelesen und geht diesem vor."
---
# Projekt-Playbook: Work-Time-Manager

Projektspezifisch, **nicht** Teil des Agent-Standards. Die Phasen-Agents (`analyst`, `developer`, `reviewer`) lesen dieses Playbook
zusätzlich zu `playbook-<stack>`; bei Widerspruch gilt dieses, danach `CLAUDE.md` der Plattform.

| Thema | Referenz |
|---|---|
| Konventionen, PR-Checkliste, Issue-Einordnung, `/auto-bugfix`-Hotfix | [references/konventionen.md](references/konventionen.md) |
| Datenpfade, Hybrid-Layer, Arbeitszeit-Profile, Rechenlogik, Premium | [references/daten.md](references/daten.md) |
| Flutter (`mobile/`), je Phase | [references/flutter.md](references/flutter.md) |
| Angular (`web/`): Architektur, Hybrid-Services, Premium, i18n, Parität | [references/web.md](references/web.md) |
| Angular-UI-Port: Design-System, Screen-Mapping | [references/design.md](references/design.md) |
| Backend (`server/`) | [references/backend.md](references/backend.md) |
| Mehrplattform-Issues | [references/koordination.md](references/koordination.md) |

Nur lesen, was die laufende Phase und Plattform brauchen.
