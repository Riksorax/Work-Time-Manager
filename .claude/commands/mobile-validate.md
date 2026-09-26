# /mobile-validate — Phase 4: Testen und UI prüfen

Issue: $ARGUMENTS

Starte nacheinander zwei Subagents (Agent-Tool):

1. `mobile-tester`:
   > Für Issue #$ARGUMENTS aus `mobile/` `flutter pub get`, `flutter analyze --no-fatal-infos`,
   > `dart run custom_lint` und `flutter test` ausführen, Testlücken nach der Checkliste schließen,
   > Abschnitt „Validierung“ in `mobile/thoughts/$ARGUMENTS-plan.md` ergänzen.
2. `mobile-ui-reviewer`:
   > Für Issue #$ARGUMENTS die UI-Checkliste abarbeiten (Widget-Tests; lokal zusätzlich
   > `flutter run`), Abschnitt „UI-Review“ in `mobile/thoughts/$ARGUMENTS-plan.md` ergänzen.

Blockierende Punkte (🔴) zuerst beheben lassen, bevor `/mobile-review $ARGUMENTS` folgt.
