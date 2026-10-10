---
name: playbook-dotnet
description: "Vorgehen und Checkliste für Änderungen am .NET-Backend (server/): Vertrag zuerst, TDD je Schicht, Build und Tests grün, Doku nachziehen. Verwenden, wenn ein Issue das .NET-Backend betrifft. Nicht für Flutter oder Web."
---
# Playbook: .NET-Backend (server/)

Wird vom Agent `developer` (Modul `core`) geladen. Das Backend hat keine eigenen Analyse- und Plan-Phasen:
der **Vertrag** (DTO, Route, ggf. Mandanten-/Profil-Bezug) ist der Plan. Hängen Web oder Mobile davon ab,
wird zuerst nur der Vertrag zurückgegeben und freigegeben.

| Phase | Referenz |
|---|---|
| Umsetzung (Vertrag, TDD, Checks, Doku) | [references/implement.md](references/implement.md) |

Review: Checkliste „vor dem PR“ am Ende der Referenz, danach gilt die allgemeine Review-Phase des Agents `reviewer`.

## Annahmen über das Projekt
- Backend in `server/` (abweichender Ordner: `--server-dir`), Build-/Test-Befehle in der Root-`CLAUDE.md`
  unter „Checks“, Aufbau und Endpunkt-Tabelle in `server/CLAUDE.md`
- Schichten Domain → Mappings → Repository → Endpoint (Minimal API)
