# /web-implement — Phase 4: Angular-Code implementieren

Aktiviere den Web-Developer-Agenten (lies `.claude/agents/web-developer.md` vollständig).

Issue: $ARGUMENTS

## Voraussetzung
Plan muss freigegeben sein: `web/thoughts/$ARGUMENTS-plan.md` ✅

## Aufgabe

Implementiere alle Schritte aus dem Plan (`web/thoughts/$ARGUMENTS-plan.md`).

**Reihenfolge strikt einhalten:**
1. Domain-Models (`web/src/app/domain/models/`)
2. Domain-Services — Test zuerst, dann Impl (`web/src/app/domain/services/`)
3. Core-Services — Test zuerst, dann Impl (`web/src/app/core/services/`)
4. Feature-Component — Test zuerst, dann Impl (`web/src/app/features/<feature>/`, Ordner laut Research-Datei)
5. HTML-Template aus UI-Designer-Output integrieren
6. SCSS aus UI-Designer-Output integrieren + responsive Anpassungen
7. Route in `web/src/app/app.routes.ts` eintragen (falls neu)
8. `npm test -- --watch=false` und `npm run build -- --configuration production` — beide grün

**Regeln:**
- KEIN `standalone: true` (Angular v20+ Default) + `ChangeDetectionStrategy.OnPush` bei allen Components
- KEIN `CommonModule` — nur spezifische Imports (`DatePipe`, `AsyncPipe` etc.)
- `inject()` statt Constructor-Parameter
- `@if` / `@for` statt `*ngIf` / `*ngFor`
- `firstValueFrom()` für einmalige Observable-Werte (statt `new Promise + subscribe`)
- Dauerhafte Subscriptions via `takeUntilDestroyed()` absichern
- Öffentliche Signals via `.asReadonly()` exponieren
- Keine `any`-Typen
- Neue Texte über ngx-translate, Keys in `web/public/i18n/de.json` + `en.json`
- Premium-Features hinter `ProfileService.isPremium`
- Firebase nur über die Core-Services, nie direkt in Components; Imports nur aus `@angular/fire/*`
- Neue Firestore-Pfade brauchen eine Security Rule in `web/firestore.rules`
