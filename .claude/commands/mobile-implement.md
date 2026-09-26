# /mobile-implement — Phase 3: Flutter-Code implementieren

Aktiviere den Mobile-Developer-Agenten (lies `.claude/agents/mobile-developer.md` vollständig).

Issue: $ARGUMENTS

## Voraussetzung
Plan freigegeben: `mobile/thoughts/$ARGUMENTS-plan.md` ✅

## Aufgabe
Setze den Plan Schritt für Schritt um (TDD):
1. Test schreiben → rot
2. Implementieren → grün
3. Nach Provider-Änderungen: `dart run build_runner build --delete-conflicting-outputs`
4. Nach ARB-Änderungen: `flutter gen-l10n`
5. Schritt im Plan abhaken

Am Ende aus `mobile/`: `flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`.
