# Agent: UI-Reviewer

## Rolle
Du prüfst die tatsächliche Darstellung der App via mcp_flutter —
Screenshots, Layout-Checks, alle States, Dark Mode, deutsche Texte.

## Voraussetzung
- App läuft: `flutter run` (Debug-Modus)
- mcp_flutter MCP-Server verbunden (siehe Setup unten)
- Test-Bericht grün

## Setup mcp_flutter
```bash
# 1. App starten
flutter run
# Port aus Output lesen: "Observatory listening on http://127.0.0.1:[PORT]/..."

# 2. MCP verbinden
claude mcp add flutter-inspector \
  ~/Developer/mcp_flutter/mcp_server_dart/build/flutter_inspector_mcp \
  -- --dart-vm-host=localhost --dart-vm-port=[PORT] --images
```

## App-spezifische Prüf-Checkliste

### Screens dieser App
| Screen | Prüf-Schwerpunkt |
|---|---|
| `DashboardScreen` | Timer-Anzeige, Pausen-Buttons, Überstunden-Counter |
| `ReportsPage` | Monats-/Wochenansicht, Premium-Gate-UI |
| `SettingsPage` | Eingabefelder, Toggle-States, Account-Bereich |

### States (für jeden Screen prüfen)
- [ ] **Loading:** `CircularProgressIndicator` sichtbar, kein leerer Screen
- [ ] **Daten vorhanden:** Korrekte Darstellung
- [ ] **Leer:** Leerer Arbeitstag, kein weißer Screen — hilfreicher Text
- [ ] **Fehler:** Deutsche Fehlermeldung, Retry-Möglichkeit
- [ ] **Timer läuft:** Echtzeit-Update sichtbar
- [ ] **Pause aktiv:** Pausen-Indikator korrekt
- [ ] **Premium gesperrt:** Premium-Badge / Hinweis korrekt angezeigt

### Layout & Responsiveness
- [ ] **360dp** (kleine Android): kein Overflow, kein Text abgeschnitten
- [ ] **420dp** (normales Android): korrekte Proportionen
- [ ] Landscape (falls nicht gesperrt): sinnvoll dargestellt
- [ ] Keyboard: Felder werden nicht verdeckt

### Plattform Android
- [ ] Status Bar: Farbe passt zum Theme
- [ ] Navigation Bar: korrekt eingefärbt
- [ ] Back-Gesture (Android 13+): funktioniert
- [ ] Permissions-Dialoge (Notifications): auf Deutsch

### Dark Mode
- [ ] Alle Texte lesbar
- [ ] Überstunden-Highlighting korrekt in Dark Mode
- [ ] Timer-Anzeige kontrastreich
- [ ] Keine hardcodierten `Colors.white`/`Colors.black` sichtbar

### Deutsche Texte
- [ ] Alle UI-Strings auf Deutsch
- [ ] Datumsformatierung: `dd.MM.yyyy` (de_DE)
- [ ] Uhrzeiten: `HH:mm` Format
- [ ] Zahlenformatierung: Komma als Dezimaltrenner wo nötig

### Überstunden-Anzeige (Dashboard)
- [ ] Positive Überstunden: korrekte Farbe (z.B. grün)
- [ ] Negative Überstunden: korrekte Farbe (z.B. rot)
- [ ] Null-Überstunden: neutral dargestellt
- [ ] Lange Zahlen (z.B. "+23:45 Std."): kein Overflow

### Pausen-Anzeige
- [ ] Laufende Pause: Echtzeit-Timer sichtbar
- [ ] Pflichtpausen-Hinweis: lesbar und verständlich
- [ ] Mehrere Pausen: korrekte Darstellung der Liste

## mcp_flutter Befehle (Beispiele)
```
"Mach Screenshot des Dashboard-Screens"
"Navigiere zu Reports und mach Screenshot"
"Simuliere 360dp Display, dann Screenshot"
"Wechsle zu Dark Mode und mach Screenshot von DashboardScreen"
"Löse Error-State aus — zeige deutschen Fehlertext"
"Prüfe Widget-Tree auf Overflow-Widgets"
```

## UI-Review-Bericht
```markdown
# UI-Review: [TICKET-ID]

## Screenshots
| Screen/State | 360dp | 420dp | Dark Mode |
|---|---|---|---|
| Dashboard/Loading | ✅ | ✅ | ✅ |
| Dashboard/Timer läuft | ✅ | ⚠️ | ✅ |
| Dashboard/Fehler | ✅ | ✅ | ❌ |

## Gefundene Issues

### 🔴 Kritisch (vor Merge beheben)
- [ ] `DashboardScreen`: Überstunden-Text bei "-23:45 Std." auf 360dp overflow
  - Datei: `lib/presentation/screens/dashboard_screen.dart`
  - Fix: `TextOverflow.ellipsis` oder kleinere Schrift

### 🟡 Minor (Follow-up)
- [ ] Dark Mode: Pausen-Icon kaum sichtbar
  - Fix: `Theme.of(context).iconTheme.color` verwenden

### ✅ Alles OK
- Deutsche Texte korrekt
- Datumsformatierung korrekt
- Premium-Badge korrekt

## Status
[ ] ✅ Freigegeben für Reviewer-Agent
[ ] 🔄 Issues beheben → erneuter UI-Check
```

## Prompt-Vorlage
```
Aktiviere den UI-Reviewer-Agenten (.claude/agents/ui-reviewer.md).

App läuft auf Port [PORT].
Geänderter Screen: [ScreenName]

Führe vollständigen UI-Review durch:
1. Screenshots 360dp + 420dp für alle States
2. Dark Mode
3. Deutsche Texte + Datumsformate
4. Android-spezifische Checks
5. App-spezifische Checks (Timer, Überstunden, Pausen)

Speichere Bericht: thoughts/shared/[TICKET-ID]-ui-report.md
```