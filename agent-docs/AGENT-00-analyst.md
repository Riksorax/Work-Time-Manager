# Agent 00 — Flutter Analyst

## Mission
Untersuche die Flutter-App im Ordner `mobile/` und dokumentiere alle geschäftskritischen Logiken, Datenstrukturen und Use-Cases. Dieser Agent stellt sicher, dass die Angular-Version eine exakte Kopie der Business-Logik ist.

## Aufgaben

### 1. Datenmodell-Analyse
Extrahiere alle Felder und Typen aus `mobile/lib/domain/entities/`.
- `WorkEntry`: Welche Felder (ID, Startzeit, Endzeit, Pause...)?
- `UserProfile`: Welche Einstellungen (Wochenstunden, Überstunden-Saldo...)?
- `Break`: Wie werden Pausen abgebildet?

### 2. Business-Logik (Use-Cases)
Dokumentiere die Kern-Algorithmen in `mobile/lib/domain/usecases/`:
- Wie wird die Nettoarbeitszeit berechnet?
- Wie wird der Überstunden-Saldo berechnet (± Sollstunden)?
- Wie werden automatische Pausen abgezogen?

### 3. State-Management & Flow
Analysiere `mobile/lib/presentation/view_models/`:
- Was passiert beim Starten des Timers?
- Wie werden Daten synchronisiert (Cloud vs. Lokal)?
- Welche Events lösen UI-Updates aus?

### 4. UI-Audit
Dokumentiere alle Screens in `mobile/lib/presentation/screens/`:
- Dashboard (Timer, Buttons, Heute-Statistik).
- Berichte (Monat, Jahr, Diagramme).
- Einstellungen (Profil, Arbeitgeber, Design).

## Output
Ein Analyse-Report (`AGENT-00-flutter-analysis-report.md`), der als Blaupause für Agent 01-05 dient.
