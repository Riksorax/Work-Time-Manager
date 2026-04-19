# /web-analyze — Phase 1: Flutter-Feature für Web-Port analysieren

Aktiviere den Web-Analyst-Agenten (lies `.claude/agents/web-analyst.md` vollständig).

Feature: $ARGUMENTS

## Aufgabe

1. Lese die relevanten Flutter-Quelldateien:
   - `mobile/lib/presentation/screens/` — Screen für dieses Feature
   - `mobile/lib/presentation/view_models/` — ViewModel
   - `mobile/lib/domain/entities/` — betroffene Entities
   - `mobile/lib/domain/services/` — Domain-Services
   - `mobile/lib/data/repositories/` — Hybrid-Repository

2. Erstelle das vollständige Flutter → Angular Mapping (Konzept-Tabelle)

3. Identifiziere alle UI-States (loading / data / empty / error / premium-locked)

4. Analysiere Web-Spezifika (Responsive, Accessibility, keine RevenueCat-Abhängigkeit)

5. Liste offene Fragen und Risiken

6. Speichere unter: `web/thoughts/$ARGUMENTS-research.md`
