# /web-implement — Phase 4: Angular-Code implementieren

Aktiviere den Web-Developer-Agenten (lies `.claude/agents/web-developer.md` vollständig).

Feature: $ARGUMENTS

## Voraussetzung
Plan muss freigegeben sein: `web/thoughts/$ARGUMENTS-plan.md` ✅

## Aufgabe

Implementiere alle Schritte aus dem Plan (`web/thoughts/$ARGUMENTS-plan.md`).

**Reihenfolge strikt einhalten:**
1. Domain-Models (`web/src/app/domain/models/`)
2. Domain-Services — Test zuerst, dann Impl (`web/src/app/domain/services/`)
3. Data-Services — Test zuerst, dann Impl (`web/src/app/data/services/`)
4. Feature-Component — Test zuerst, dann Impl (`web/src/app/features/$ARGUMENTS/`)
5. HTML-Template aus UI-Designer-Output integrieren
6. SCSS aus UI-Designer-Output integrieren + responsive Anpassungen
7. Route in `web/src/app/app.routes.ts` eintragen (falls neu)
8. `npm test` ausführen — alle grün

**Regeln:**
- `standalone: true` + `ChangeDetectionStrategy.OnPush` bei allen Components
- `inject()` statt Constructor-Parameter
- `@if` / `@for` statt `*ngIf` / `*ngFor`
- `takeUntilDestroyed()` für alle Subscriptions
- Keine `any`-Typen
- Alle Strings auf Deutsch
- Premium-Features hinter `PremiumService.isPremium()`
- Firebase nur über Data-Services, nie direkt in Components
