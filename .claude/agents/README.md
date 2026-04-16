# Flutter Claude Code Workflow

Kompletter Workflow für Flutter/Android-Entwicklung mit Claude Code.

## Schnellstart

```bash
# Dateien ins Projekt kopieren
cp -r .claude/ /dein/flutter-projekt/
cp CLAUDE.md /dein/flutter-projekt/
cp -r thoughts/ /dein/flutter-projekt/

# CLAUDE.md anpassen (Projektname, Architektur, etc.)
```

## Der Workflow — 5 Phasen

```
TICKET kommt rein
     │
     ▼
┌─────────────┐
│  Phase 1    │  /analyze TICKET-123
│  Analyst    │  → Aufgabe verstehen, Rückfragen stellen
└──────┬──────┘
       │ Rückfragen beantwortet
       ▼
┌─────────────┐
│  Phase 2    │  /plan TICKET-123
│  Planner    │  → Implementierungsplan (kein Code)
└──────┬──────┘
       │ Plan freigegeben (Ctrl+G)
       ▼
┌─────────────┐
│  Phase 3    │  /implement TICKET-123
│  Developer  │  → TDD: Tests → Code → Tests grün
└──────┬──────┘
       │ Alle Schritte ✅
       ▼
┌─────────────┐
│  Phase 4    │  /validate TICKET-123
│  Tester +   │  → Coverage, flutter analyze, UI-Screenshots
│  UI-Review  │
└──────┬──────┘
       │ Alles grün
       ▼
┌─────────────┐
│  Phase 5    │  /review TICKET-123
│  Reviewer   │  → Code Review + PR
└─────────────┘
```

## Slash Commands

| Command | Agent | Phase |
|---|---|---|
| `/analyze TICKET-123` | Analyst | Aufgabe verstehen |
| `/plan TICKET-123` | Planner | Plan erstellen |
| `/implement TICKET-123` | Developer | Code schreiben |
| `/validate TICKET-123` | Tester + UI-Reviewer | Testen + UI |
| `/review TICKET-123` | Reviewer | Review + PR |

## Dateien-Übersicht

```
.claude/
├── agents/
│   ├── analyst.md       # Phase 1: Aufgabe analysieren
│   ├── planner.md       # Phase 2: Plan erstellen
│   ├── developer.md     # Phase 3: Implementieren (TDD)
│   ├── tester.md        # Phase 4a: Tests + Coverage
│   ├── ui-reviewer.md   # Phase 4b: UI via mcp_flutter
│   └── reviewer.md      # Phase 5: Code Review + PR
└── commands/
    ├── analyze.md        # /analyze
    ├── plan.md           # /plan
    ├── implement.md      # /implement
    ├── validate.md       # /validate
    └── review.md         # /review

thoughts/
├── shared/
│   ├── plans/           # Freigeg. Pläne (alle Phasen)
│   └── prs/             # PR-Beschreibungen
└── personal/
    └── tickets/         # Research + Checkpoints

CLAUDE.md                # Projekt-Kontext (ANPASSEN!)
```

## Goldene Regeln

1. **Niemals Phase überspringen** — auch wenn die Aufgabe klein wirkt
2. **Context unter 60% halten** — `/clear` + Checkpoint-Datei laden
3. **Tests vor Code** — immer TDD
4. **Plan ist heilig** — Abweichungen immer besprechen
5. **mcp_flutter** für echten UI-Check — keine Annahmen

## mcp_flutter Setup

```bash
# Repository klonen
git clone https://github.com/Arenukvern/mcp_flutter ~/Developer/mcp_flutter
cd ~/Developer/mcp_flutter && make install

# App starten
flutter run
# Port aus Output ablesen: "Observatory listening on http://127.0.0.1:[PORT]/..."

# MCP verbinden
claude mcp add flutter-inspector \
  ~/Developer/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp \
  -- --dart-vm-host=localhost --dart-vm-port=[PORT] --images
```
