# /mobile-validate — Phase 4: Testen und UI prüfen

Aktiviere nacheinander:
1. den Mobile-Tester-Agenten (`.claude/agents/mobile-tester.md`)
2. den Mobile-UI-Reviewer-Agenten (`.claude/agents/mobile-ui-reviewer.md`)

Issue: $ARGUMENTS

## Aufgabe
1. Alle vier Checks aus `mobile/` ausführen: `flutter pub get`, `flutter analyze --no-fatal-infos`,
   `dart run custom_lint`, `flutter test`.
2. Testlücken nach der Checkliste des Testers schließen.
3. UI-Checkliste abarbeiten (Widget-Tests; lokal zusätzlich `flutter run`).
4. Ergebnisse als Abschnitte „Validierung“ und „UI-Review“ in `mobile/thoughts/$ARGUMENTS-plan.md`.

Blockierende Punkte (🔴) zuerst beheben, bevor `/mobile-review` folgt.
