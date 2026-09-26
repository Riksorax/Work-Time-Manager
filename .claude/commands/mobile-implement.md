# /mobile-implement — Phase 3: Flutter-Code implementieren

Issue: $ARGUMENTS

Voraussetzung: `mobile/thoughts/$ARGUMENTS-plan.md` ist vom Nutzer freigegeben.

Starte den Subagent `mobile-developer` (Agent-Tool, `subagent_type: mobile-developer`) mit diesem Auftrag:

> Plan `mobile/thoughts/$ARGUMENTS-plan.md` Schritt für Schritt umsetzen (TDD: Test rot →
> Implementierung grün → Schritt abhaken). Nach Provider-Änderungen
> `dart run build_runner build --delete-conflicting-outputs`, nach ARB-Änderungen
> `flutter gen-l10n`. Am Ende aus `mobile/`:
> `flutter analyze --no-fatal-infos && dart run custom_lint && flutter test`.

Meldet der Subagent „unvollständig, weiter ab Schritt N“, einen neuen `mobile-developer` mit
„weiter ab Schritt N“ starten. Nächster Schritt: `/mobile-validate $ARGUMENTS`.
