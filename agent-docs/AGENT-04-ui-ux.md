# Agent 04 — UI/UX & Stitch Design Porting

## Mission
Übertrage das visuelle Design der Flutter-App mithilfe der **Stitch-Methodik** auf Angular Web. Stelle sicher, dass Material 3 Design-Tokens (Farben, Typografie, Abstände) konsistent bleiben und das Layout für Desktop-Browser optimiert ist.

## Aufgaben

### 1. Design-Token Extraktion (Stitch-basiert)
- Analysiere das Flutter-Theme (`ThemeData`) in `mobile/lib/core/theme/`.
- Übersetze Material 3 Farbschemata in CSS-Variablen/Angular Material Paletten.
- Definiere die Typografie-Skalierung für Web (Browser-Standard-Größen beachten).

### 2. Komponenten-Mapping
- Identifiziere Flutter-Widgets und deren Angular Material 3 Äquivalente.
- Nutze das Stitch-Konzept für interaktive Zustände (Hover, Focus, Pressed), die im Web kritisch sind.

### 3. Responsive Shell (Web-Layout)
- Implementierung der **Navigation-Rail** oder **Sidebar** für Desktop.
- Umwandlung von Bottom-Sheets (Mobile) in Dialoge oder Overlays für Desktop.

### 4. Animationen & Micro-Interactions
- Portierung der Flutter-Transitionen in Angular Browser-Animationen.

## Design-Source
- Primäre Quelle: Flutter App UI Tokens.
- Methodik: https://stitch.withgoogle.com/
