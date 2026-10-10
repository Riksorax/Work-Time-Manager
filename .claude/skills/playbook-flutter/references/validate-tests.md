# Mobile-Tester (Flutter) — Referenz Phase „Validierung: Tests“

> Lies zuerst `mobile/CLAUDE.md`.

## Rolle
Du prüfst nach der Implementierung, ob die Änderung vollständig getestet ist und alle
Checks der CI lokal grün sind. Du schließt Testlücken, änderst aber keine Fachlogik.

## Checks (aus `mobile/`, identisch zur CI plus custom_lint)

```bash
flutter pub get
flutter analyze --no-fatal-infos
dart run custom_lint
flutter test
```

Alle vier müssen grün sein. `flutter analyze` darf keine **neuen** Warnungen gegenüber dem
Integrationsbranch enthalten (Infos sind erlaubt).

## Test-Abdeckung prüfen
- [ ] Jede neue/geänderte öffentliche Funktion in `domain/` hat Unit-Tests inkl. Grenzfällen
      (0, negative Werte, Mitternacht, Monats-/Jahreswechsel, Sommerzeit)
- [ ] Repository-Änderungen: Umschaltung eingeloggt/ausgeloggt (bzw. alle Varianten) getestet
- [ ] Mandanten-/Profil-Bezug: Standardfall **und** Zusatzfall getestet, falls relevant
- [ ] ViewModel: alle State-Übergänge (loading → data/empty/error)
- [ ] Widget-Tests für neue UI-Zustände (inkl. gesperrt/Feature-Gate)
- [ ] Neue ARB-Keys existieren in **allen** Sprachdateien (ein vorhandener l10n-Test läuft mit)
- [ ] Bugfix: ein Test, der ohne den Fix fehlschlägt

## Flaky-Test-Regeln
- Kein `DateTime.now()` ohne Kontrolle über Wochentag/Uhrzeit — feste Daten oder Stubs.
- Keine echten Timer/Delays; `fakeAsync` bzw. `tester.pump(duration)` verwenden.
- Ein Test, der nur an bestimmten Tagen fehlschlägt, ist ein Bug im Test und wird behoben,
  nicht übersprungen.

## Output
Ergänze `mobile/thoughts/<issue>-plan.md` um einen Abschnitt „Validierung“ mit den
Ergebnissen der vier Checks und der Liste neuer Tests.
