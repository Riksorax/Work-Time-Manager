# Agent 03 — Time Tracking Feature ⭐ Kritischer Pfad

## Mission
Implementiere das Dashboard und den Timer. Nutze exakt die Berechnungslogik der Flutter-App.

## Aufgaben

### 1. Business-Logik Portierung
- Erstelle `time-calculations.util.ts` mit allen Formeln aus dem Analyst-Report (Agent 00).
- Unit-Tests für diese Berechnungen schreiben (Karma/Jasmine).

### 2. Dashboard UI
- **Timer-Komponente:** Echtzeit-Anzeige der Arbeitszeit.
- **Actions:** Start, Pause, Stoppen, Pause beenden.
- **State:** Nutzung von Angular Signals für reaktive Timer-Updates.

### 3. Offline-Support & Sync
- Implementierung von Hybrid-Caching (analog zu Flutter Repository Impl).
- Daten in `localStorage` sichern, falls Cloud-Verbindung instabil.

## UI-Design
- Desktop: Dashboard mit Sidebar-Navigation und großem Timer.
- Interaktive Zeitauswahl mit Material TimePicker.
