# Web-UI-Designer (Flutter → Angular) — Referenz Phase „UI-Design“

## Rolle
Du portierst das Flutter-UI **1:1 visuell** nach Angular Web — das Look & Feel der App
bleibt identisch zur Flutter-Version. Farben, Typographie, Abstände, Komponenten-Struktur
und Interaktionen werden direkt übernommen. Die einzigen erlaubten Abweichungen sind
technisch notwendige Web-Anpassungen: auf Desktop wird mehr Platz genutzt (Grid-Layout,
Sidebar statt BottomNav), aber der visuelle Stil bleibt derselbe.

**Ziel:** Ein Nutzer, der die Flutter-App kennt, soll sich im Web sofort zuhause fühlen.

> Lies zuerst `web/CLAUDE.md`.

## Voraussetzung
- Research-Datei vorhanden: `web/thoughts/<issue>-research.md`
- Flutter-Screenshots vorhanden (optional, aber empfohlen)

## Vorgehen

Es gibt keine automatische Design-Erzeugung als Standard — das UI wird **manuell** nach der
Flutter-Vorlage gebaut (Flutter-Screen lesen, Werte übernehmen, Angular Material verwenden).
Setzt das Projekt ein Design-Werkzeug ein (z. B. Google Stitch), steht der Aufruf in der
Projektanpassung dieser Datei. Im UI-Report vermerken, wie designt wurde.

1. **Design-Tokens aus dem Flutter-Theme lesen** (`mobile/lib/core/theme/`): Primärfarbe,
   Hintergrund, semantische Farben, Radien, Abstände, Schriftgrößen. Nie Material-Defaults raten.
2. **Flutter-Screen Element für Element nachbauen** (Benennung wie im Flutter-Code).
3. **Statische Werte durch Angular-Bindings ersetzen** (`{{ }}`, `[binding]`, `(event)`).
4. **Responsive Breakpoints** (nur strukturell, kein Redesign):
   - Mobile (<768px): Layout identisch zu Flutter (eine Spalte)
   - Tablet (768–1024px): Flutter-Layout, mehr Padding
   - Desktop (>1024px): Flutter-Layout zentriert (max-width) oder Grid, falls Flutter Karten nutzt
5. **Texte** aus der Flutter-ARB übernehmen, im Web als ngx-translate-Keys (alle Sprachen).

### Werte-Umrechnung
```scss
.container {
  padding: 16px;               // Flutter: EdgeInsets.all(16)
  @media (min-width: 768px)  { max-width: 600px; margin: 0 auto; padding: 24px; }
  @media (min-width: 1024px) { display: grid; grid-template-columns: 1fr 1fr; max-width: 1200px; gap: 24px; }
}
```

### Flutter-Widget → Angular Material
```
AppBar            <mat-toolbar> im Shell-Layout
Column / Row      Flexbox (flex-direction)
ListTile          <mat-list-item>
SwitchListTile    <mat-slide-toggle> in <mat-list>
TextField         <mat-form-field> + <input matInput>
DropdownButton    <mat-select>
Card              <mat-card>
CalendarView      <mat-calendar> oder eigene Grid-Implementierung
```

## Checkliste

### Design-Treue (Flutter-Parität) — PRIORITÄT 1
- [ ] Primärfarbe und alle semantischen Farben identisch zur Flutter-App
- [ ] Schriftgrößen und -gewichte identisch
- [ ] Abstände (padding/margin) identisch zu den Flutter-`EdgeInsets`-Werten
- [ ] Card-Radius und Elevation identisch
- [ ] Icon-Set identisch (Material Icons)
- [ ] Texte inhaltlich aus der Flutter-ARB übernommen, im Web als ngx-translate-Keys
- [ ] Dark Mode: gleiche Farben wie Flutter-Dark-Theme

### Korrektheit
- [ ] Alle Flutter-UI-States abgedeckt (loading/data/empty/error)
- [ ] Gesperrter Zustand (Feature-Gate) visuell identisch zu Flutter

### Responsiveness
- [ ] Mobile / Tablet / Desktop wie oben

### Accessibility
- [ ] Icon-Buttons haben ein (übersetztes) `aria-label`
- [ ] Farbkontrast WCAG AA erfüllt
- [ ] Fokus-Reihenfolge logisch (Tab-Reihenfolge)
- [ ] Keine Informationen nur über Farbe vermittelt

### Angular-spezifisch
- [ ] `OnPush` Change Detection gesetzt, kein explizites `standalone: true`, kein `CommonModule`
- [ ] Keine direkten DOM-Manipulationen
- [ ] `@if` / `@for` statt `*ngIf` / `*ngFor`
- [ ] Template-Variablen nur wo nötig

## Output-Format

1. `web/src/app/features/[feature]/[component]/[component].html` — Template
2. `web/src/app/features/[feature]/[component]/[component].scss` — Styles
3. `web/thoughts/<issue>-ui-report.md` — UI-Review-Bericht
