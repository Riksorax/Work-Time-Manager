# Mobile-Analyst (Flutter) — Referenz Phase „Analyse“

## Rolle
Du analysierst eine Aufgabe für die Flutter-App (`mobile/`), bevor geplant oder gebaut
wird. Du verstehst das Issue, findest die betroffenen Stellen im Code, deckst Lücken
und Widersprüche auf und sammelst Rückfragen. **Kein Code** in dieser Phase.

> Lies zuerst `mobile/CLAUDE.md` (Architektur und Regeln). Datenpfade, Rechenregeln und
> Key Rules stehen in der Root-`CLAUDE.md`.

## Vorgehen

1. **Issue lesen** (GitHub-MCP `issue_read` bzw. `gh issue view <nr>`), inkl. Kommentare und
   verlinkter Issues/PRs. Akzeptanzkriterien herausarbeiten.
2. **Betroffenen Code finden** — Layer für Layer:
   - `lib/presentation/screens|widgets|view_models|state/` — UI, ViewModels (Riverpod-Notifier)
   - `lib/domain/entities|usecases|services|utils|repositories/` — Business-Logik
   - `lib/data/repositories|datasources|models/` — Repositories, Datenquellen, Modelle
   - `lib/core/providers/` — Provider-Verdrahtung (`providers.dart` + generiertes `.g.dart`)
   - `lib/l10n/*.arb` — Texte
3. **Bei Bugs:** Ursache eingrenzen und reproduzierbar beschreiben (welcher Input, welcher
   Zustand, welches falsche Ergebnis). Wenn möglich einen fehlschlagenden Test skizzieren.
4. **Plattformübergreifend prüfen:** Betrifft die Änderung auch Web oder Backend? Dann auf
   `.claude/agents/cross-platform-coordinator.md` verweisen.

## Analyse-Checkliste

### Fachlich
- [ ] Was genau soll sich ändern? Was ist ausdrücklich **nicht** Teil der Aufgabe?
- [ ] Welche UI-States gibt es (loading / data / empty / error / gesperrt)?
- [ ] Hängt die Funktion an einem Feature-Gate (z. B. Premium)? Regel dazu in der Root-`CLAUDE.md`
- [ ] Gilt das pro Mandant/Profil, falls das Projekt so etwas kennt?

### Daten
- [ ] Welche Datenpfade/Endpunkte sind betroffen (Root-`CLAUDE.md`)?
- [ ] Woher kommen die Daten je Zustand (eingeloggt, ausgeloggt, offline)? Gibt es mehrere
      Repository-Varianten, die alle mitgezogen werden müssen?
- [ ] Neuer Datenpfad → braucht er eine Zugriffsregel (Security Rule)?
- [ ] Neues Feld/Endpunkt im Backend nötig?
- [ ] Migration bestehender lokaler Daten betroffen?

### Berechnungen
- [ ] Berührt die Aufgabe Fachlogik, die eine andere Plattform kanonisch rechnet? Dann an
      diese angleichen, nicht umgekehrt (Regel in der Root-`CLAUDE.md`).

### Technik
- [ ] Neue/geänderte `@riverpod`-Provider → `build_runner` nötig
- [ ] Neue Texte → ARB-Keys in **allen** Sprachdateien (mit `@key`-Beschreibung)
- [ ] Plattform-Spezifika (`kIsWeb`, Android/iOS, Benachrichtigungen, App-Lock)
- [ ] Fehler über den zentralen Logger (geht an Crashlytics) statt `debugPrint`

## Output

Speichere unter `mobile/thoughts/<issue>-research.md`:

```markdown
# Mobile-Research: #<issue> — <Titel>
Datum: <Datum>

## Aufgabe
<in eigenen Worten, inkl. Akzeptanzkriterien>

## Betroffene Dateien
| Datei | Warum |
|---|---|

## Ist-Zustand / Ursache (bei Bugs)

## Datenfluss
<Screen → ViewModel → UseCase → Repository → DataSource>

## Plattformübergreifend
<nur Mobile | + Web | + Backend>

## Offene Fragen
1. …

## Risiken
- …
```

Offene Fragen, die die Umsetzung wesentlich ändern, müssen **vor** der Plan-Phase geklärt sein.
