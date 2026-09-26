# /web-implement — Phase 4: Angular-Code implementieren

Issue: $ARGUMENTS

Voraussetzung: `web/thoughts/$ARGUMENTS-plan.md` ist vom Nutzer freigegeben.

Starte den Subagent `web-developer` (Agent-Tool, `subagent_type: web-developer`) mit diesem Auftrag:

> Plan `web/thoughts/$ARGUMENTS-plan.md` Schritt für Schritt umsetzen (TDD), Reihenfolge:
> Domain-Models → Domain-Services → Core-Services → Feature-Service/Component
> (`web/src/app/features/<feature>/`, Ordner laut Research-Datei) → HTML/SCSS aus dem
> UI-Designer-Output → Route in `app.routes.ts` (falls neu). Am Ende aus `web/`:
> `npm test -- --watch=false` und `npm run build -- --configuration production` — beide grün.

Meldet der Subagent „unvollständig, weiter ab Schritt N“, einen neuen `web-developer` mit
„weiter ab Schritt N“ starten. Nächster Schritt: `/web-review $ARGUMENTS`.
