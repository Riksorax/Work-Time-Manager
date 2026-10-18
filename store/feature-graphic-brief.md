# Feature Graphic Brief – Google Play Store

> **Stand (#437):** Die Feature Graphic und das Play-Store-Icon (512 × 512) werden aus dem Logo-Master erzeugt:
> `store/feature-graphic.png` aus `branding/src/feature-graphic.svg`, `store/icon-512.png` aus `branding/src/icon-store.svg`
> (`cd branding && npm run export`). Nicht von Hand ändern; Details und Logo-Tausch in `branding/README.md`.
> Die folgenden Vorgaben beschreiben, was die erzeugte Grafik erfüllt, und gelten für jede künftige Neugestaltung.

## Technische Anforderungen
- Größe: **1024 × 500 px** (Pflicht, exakt)
- Format: PNG oder JPEG (kein Alpha)
- Wird im Play Store als Header-Banner und bei geteilten Links angezeigt

## Zweck
Die Feature Graphic erscheint:
- Ganz oben im Play Store Listing (über den Screenshots)
- Als Preview-Bild wenn die App-Seite in Messenger/Social Media geteilt wird
- In Promotion-Bereichen von Google Play

## Designvorgaben

### Farben
- Primärfarbe: `#1565C0` (Blau, entspricht App-Theme)
- Akzentfarbe: `#FFFFFF` (Weiß für Text/Icons)
- Optional: Dunkler Gradient `#1565C0 → #0D47A1`

### Inhalt (von links nach rechts)
1. **Links:** App-Icon (Work Time Manager Logo) – ca. 200×200 px
2. **Mitte:** App-Name "Work Time Manager" in weißer Schrift (groß, klar lesbar)
3. **Darunter:** Kurz-Slogan, z.B.:
   - "Deine Arbeitszeit. Dein Überblick."
   - "Zeiterfassung. Einfach. Kostenlos."
4. **Rechts (optional):** Stilisierte Darstellung eines laufenden Timers oder Uhr-Icon

### Schrift
- Headline: Bold, mind. 60 pt äquivalent (gut lesbar auch in Thumbnail-Größe)
- Subline: Regular, ca. 30–36 pt äquivalent
- Kein Schnörkel-Font – serifenlos (z.B. Roboto, Inter, Montserrat)

### Was vermeiden
- Keinen Text in den Randbereichen (20px Sicherheitsabstand an allen Seiten)
- Keine zu kleinen Elemente (wird auf 180px Breite skaliert bei Vorschau)
- Kein Screenshot der App eingebettet (Google empfiehlt das nicht für Feature Graphic)
- Kein weißer Hintergrund – zu wenig Kontrast zur Play Store Oberfläche

## Erstellung
Per Pipeline: SVG in `branding/src/feature-graphic.svg` anpassen, `npm run export` ausführen, Ergebnis committen.
Der CI-Job `branding` schlägt bei Abweichung zwischen SVG und PNG fehl. Handarbeit in Canva/Figma ist nicht mehr vorgesehen.

## Datei-Ablage
Erzeugte Dateien (eingecheckt):
- `store/feature-graphic.png` (1024 × 500)
- `store/icon-512.png` (512 × 512, Play-Store-Icon)

Der Upload in die Play Console ist ein manueller Schritt (`branding/README.md`, „Manuelle Restpunkte“).
