# Branding

SVG-Master des Work-Time-Manager-Logos und die Pipeline, die daraus alle Bild-Assets für Android, Web und
Play Store erzeugt (Issue #437). Das Logo zu tauschen heißt: SVGs in `src/` ersetzen, `npm run export`,
Ergebnis committen.

> **Stand: Interim.** Die `logo*.svg` sind ein Nachbau des bisherigen Motivs (Uhr, Zahnrad, Pfeil, Verlauf
> Dunkelblau → Türkis), keine Neugestaltung. Das Aussehen entspricht dem bisherigen Logo
> (früher `mobile/assets/icon/WorkTimeManagerLogo.png`, inzwischen gelöscht; die Quelle ist jetzt `src/`).

## Aufruf

```bash
cd branding
npm ci            # installiert @resvg/resvg-js (exakte Version, siehe Werkzeug)
npm run export    # erzeugt alle Dateien aus src/*.svg nach mobile/, web/public/ und store/
npm run check     # Drift-Check wie in der CI: erzeugt neu und vergleicht mit dem Repo
npm test          # Tests der Pipeline (node --test, keine Zeit-/Zeitzonenabhängigkeit)
```

Die erzeugten Dateien sind eingecheckt. Der CI-Job `branding` (`.github/workflows/ci.yml`) schlägt fehl, wenn eine
Datei nicht zur SVG-Quelle passt. Der Vergleich erfolgt über dekodierte Pixel mit einer Toleranz von 1 je
Farbkanal (resvg kann je Plattform um einen Wert abweichen), SVG-Kopien werden byteweise verglichen.

## Quellen (`src/`)

| Datei | Inhalt |
|---|---|
| `logo.svg` | Komposition: Kreis-Motiv auf transparentem Grund (Favicon-Set, PWA `any`, In-App-Logo, Legacy-Launcher) |
| `favicon.svg` | wie `logo.svg`, eng auf das Motiv zugeschnitten (viewBox), damit es bei 16 px nicht schrumpft |
| `logo-background.svg` | Vollfläche `#1565C0` (adaptiver Hintergrund, Maskable) |
| `logo-foreground.svg` | Motiv, verkleinert in die Safe Zone des adaptiven Icons (66-dp-Kreis des 108-dp-Rasters) |
| `logo-monochrome.svg` | Silhouette des Motivs in gleicher Safe Zone (Themed Icon, Android 13+) |
| `logo-notification.svg` | vereinfachte Statusleisten-Silhouette (Uhr mit Zeiger), weiß |
| `icon-store.svg` | Quadrat `#1565C0` mit Motiv (ca. 10 % Rand): Play-Store-Icon und Apple-Touch |
| `og-image.svg` | 1200 × 630: Logo, Name, Claim "Arbeitszeit erfassen & Überstunden berechnen – kostenlos" |
| `feature-graphic.svg` | 1024 × 500: Logo, Name, Slogan "Deine Arbeitszeit. Dein Überblick." |

Die Motivgeometrie steckt in jeder Datei (Pfade, Verlauf, Masken), nicht in einer gemeinsamen Datei. Beim Logo-Tausch
müssen deshalb alle `logo*.svg`, `favicon.svg` und `icon-store.svg` sowie die Logos in `og-image.svg` und
`feature-graphic.svg` angepasst werden. Texte bleiben `<text>`; die Schrift Open Sans kommt aus
`mobile/assets/fonts/` (Systemschriften sind abgeschaltet, `loadSystemFonts: false`). Das Skript ändert keine
SVG-Quelle.

## Erzeugte Dateien

Quelle der Wahrheit ist `lib/targets.mjs`; ein Test stellt sicher, dass jede Datei hier genannt ist.

| Datei | Größe | Quelle | Verwendung |
|---|---|---|---|
| `mobile/assets/icon/adaptive_background.png` | 1024² | `logo-background.svg` | Adaptives Icon, Hintergrund (`flutter_launcher_icons`) |
| `mobile/assets/icon/adaptive_foreground.png` | 1024² | `logo-foreground.svg` | Adaptives Icon, Vordergrund |
| `mobile/assets/icon/adaptive_monochrome.png` | 1024² | `logo-monochrome.svg` | Themed Icon (Android 13+) |
| `mobile/assets/icon/launcher_legacy.png` | 1024² | `logo.svg` | Launcher-Icon vor Android 8 |
| `mobile/assets/icon/app_logo_256.png` | 256² | `logo.svg` | In-App-Logo (Login, Info-Seite) |
| `mobile/android/app/src/main/res/drawable-mdpi/ic_notification.png` | 24² | `logo-notification.svg` | Statusleiste (weiß auf transparent) |
| `mobile/android/app/src/main/res/drawable-hdpi/ic_notification.png` | 36² | `logo-notification.svg` | Statusleiste |
| `mobile/android/app/src/main/res/drawable-xhdpi/ic_notification.png` | 48² | `logo-notification.svg` | Statusleiste |
| `mobile/android/app/src/main/res/drawable-xxhdpi/ic_notification.png` | 72² | `logo-notification.svg` | Statusleiste |
| `mobile/android/app/src/main/res/drawable-xxxhdpi/ic_notification.png` | 96² | `logo-notification.svg` | Statusleiste |
| `web/public/favicon.svg` | Vektor | `favicon.svg` | Favicon (SVG, zuerst verlinkt) |
| `web/public/favicon.ico` | 16, 32, 48 | `favicon.svg` | Favicon (ICO, Fallback) |
| `web/public/favicon-16x16.png` | 16² | `favicon.svg` | Favicon PNG |
| `web/public/favicon-32x32.png` | 32² | `favicon.svg` | Favicon PNG |
| `web/public/favicon-48x48.png` | 48² | `favicon.svg` | Favicon PNG |
| `web/public/favicon-96x96.png` | 96² | `favicon.svg` | Favicon PNG (Manifest) |
| `web/public/apple-touch-icon.png` | 180², deckend | `icon-store.svg` | iOS-Home-Bildschirm |
| `web/public/icon-192x192.png` | 192² | `logo.svg` | PWA, `purpose: any` |
| `web/public/icon-512x512.png` | 512² | `logo.svg` | PWA, `purpose: any` |
| `web/public/icon-maskable-192x192.png` | 192², deckend | `logo-background.svg` + `logo-foreground.svg` | PWA, `purpose: maskable` |
| `web/public/icon-maskable-512x512.png` | 512², deckend | `logo-background.svg` + `logo-foreground.svg` | PWA, `purpose: maskable` |
| `web/public/logo.svg` | Vektor | `logo.svg` | Logo in Sidenav und Login |
| `web/public/og-image.png` | 1200 × 630, ohne Alpha | `og-image.svg` | Open Graph / Twitter-Karte |
| `store/icon-512.png` | 512², 32 Bit | `icon-store.svg` | Play-Store-Icon (Upload manuell) |
| `store/feature-graphic.png` | 1024 × 500, ohne Alpha | `feature-graphic.svg` | Play-Store-Feature-Graphic (Upload manuell) |

Verdrahtet sind die Assets in Web (Manifest, `index.html`, `nginx.conf`, Sidenav/Login) und Mobile
(`pubspec.yaml`, `notification_service.dart`, `keep.xml`); siehe die Branches `feature/437-web-wiring` und
`feature/437-mobile-wiring`. Die Android-Mipmaps und `mipmap-anydpi-v26/launcher_icon.xml` erzeugt nicht dieses
Skript, sondern `dart run flutter_launcher_icons` aus den `adaptive_*`-Dateien (im Ordner `mobile/`).

**Hinweise beim Logo-Tausch:**

- Die Cache-Version `?v=170` in `web/src/index.html`, `web/public/manifest.json`,
  `branding/test/web-wiring.test.mjs` und `web/e2e/branding.spec.ts` gleichzeitig anheben.
- `dart run flutter_launcher_icons` fügt `<inset>` wieder ein. `mipmap-anydpi-v26/launcher_icon.xml` danach von
  Hand korrigieren (kein `<inset>`).

## Logo-Tausch (Stufe B)

Das aktuelle Logo ist ein Interim-Nachbau. Für die endgültige Gestaltung:

1. Alle Motiv-SVGs in `src/` ersetzen (`logo*.svg`, `favicon.svg`, `icon-store.svg`, Logos in `og-image.svg` und
   `feature-graphic.svg`); die Safe-Zone-Regeln unten einhalten.
2. `cd branding && npm run export`, Ergebnis committen (`npm test && npm run check` müssen grün sein).
3. Bei geänderten Favicon-/OG-Dateien den Cache-Parameter (`?v=...`) in `web/` anheben, siehe Hinweis zur Cache-Version oben und
   `branding/test/web-wiring.test.mjs` und `web/e2e/branding.spec.ts`.
4. `dart run flutter_launcher_icons` nur bei geänderter Konfiguration; danach `launcher_icon.xml` von Hand ohne `<inset>`.
5. Die manuellen Restpunkte unten erneut abarbeiten.

## Manuelle Restpunkte

Diese Schritte erledigt die Pipeline nicht (Konsolen und Dienste außerhalb des Repos):

- [ ] **Play Console:** `store/icon-512.png` als App-Icon und `store/feature-graphic.png` als Feature Graphic hochladen
  (Store-Eintrag), Screenshots mit neuem Icon neu aufnehmen (`store/screenshot-brief.md`).
- [ ] **Firebase Authentication:** Logo bzw. Absender in den E-Mail-Vorlagen (Verifizierung, Passwort-Reset) anpassen.
- [ ] **Google-Cloud-Konsole, OAuth-Zustimmungsbildschirm:** App-Logo (120 × 120 px, `store/icon-512.png` verkleinert) hochladen.
- [ ] **GitHub:** Social Preview (1280 × 640 px) in den Repository-Einstellungen setzen.
- [ ] **Uptime-Kuma:** Logo der Statusseite austauschen.
- [ ] **Sentry und Crashlytics:** Projekt-Icons optional anpassen.
- [ ] **Link-Vorschauen:** Caches von Facebook (Sharing Debugger) und LinkedIn (Post Inspector) neu einlesen, damit `og-image` aktualisiert wird.
- [ ] **Release:** Release-Notes-Vermerk „neues App-Icon“ (`/release`).

## Gestaltungsregeln

- **Farben:** Basisfarbe `#1565C0` (App-Theme, Manifest `theme_color`), dunkler Verlauf `#1565C0 → #0D47A1`
  (OG, Feature Graphic). Motiv: Verlauf `#0E0A7B` (Dunkelblau) → `#52CFBA` (Türkis), Pfeil `#33689D → #3A78A8`.
  Statusleiste: reines Weiß, Android färbt nach Alpha-Kanal.
- **Schutzzone / Safe Zone:** Adaptiv liegt das gesamte Motiv inklusive Pfeilspitze im Kreis mit Durchmesser 66/108
  der Fläche. Maskable liegt im mittleren 80-%-Kreis. Beides prüfen die Tests nach.
- **Mindestgröße:** 16 px (kleinster Favicon-Eintrag). Darunter ist das Zahnrad nicht mehr erkennbar, die Uhr bleibt lesbar.
- **Statusleiste:** vereinfacht (Ring mit Zeiger), weil Zahnrad und Pfeil bei 24 dp nicht lesbar sind.
- **Dark-Variante und Wortmarke:** gibt es bewusst nicht; das Kreis-Logo ist farbfest und steht auf hellem und dunklem Grund.

## Werkzeug

- Node 20 oder neuer, `@resvg/resvg-js` **2.6.2** (exakt gepinnt, `package-lock.json` eingecheckt).
  Ein Versionswechsel kann Antialiasing leicht ändern: danach `npm run export` und die Dateien neu einchecken.
- PNG-Kodierung und ICO-Container sind selbst geschrieben (`lib/png.mjs`, `lib/ico.mjs`), es gibt keine weitere Abhängigkeit.
- ICO: PNG-in-ICO mit 16, 32 und 48 px.
- Die Pipeline braucht nur Zugriff auf `npm ci`; sie läuft in der CI als Drift-Check, nicht als Build-Schritt der Apps.
