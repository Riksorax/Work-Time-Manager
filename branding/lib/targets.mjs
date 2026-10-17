// Zieltabelle: jede erzeugte Datei mit Quelle, Größe, Format und Verwendung.
// Pfade relativ zur Repo-Wurzel. Die README führt dieselbe Tabelle für Menschen.
//
// kind   png | ico | svg
// src    Datei in branding/src/ oder Liste von Ebenen (erste unten)
// alpha  rgba    PNG mit Transparenz
//        opaque  PNG mit Alpha-Kanal, aber überall deckend (Play-Store-Icon: 32 Bit)
//        rgb     PNG ohne Alpha-Kanal (Color Type 2), Quelle muss deckend sein
//        white   PNG, nur weiß auf transparent (Android-Statusleiste)
// manifest  any | maskable: Eintrag in web/public/manifest.json (PR 2)

const ANDROID_RES = 'mobile/android/app/src/main/res';

// Safe Zone Maskable: Motiv im mittleren 80-%-Kreis. Das adaptive Vordergrundbild (Motiv im
// 66-dp-Kreis des 108-dp-Rasters) wird dafür auf 66/108 -> 80 % vergrößert: Ausschnitt 1024 * 0,7639.
const MASKABLE_VIEWBOX = '120.8 120.8 782.3 782.3';

/** @type {Array<{out:string,kind:'png'|'ico'|'svg',src:string|string[],width?:number,height?:number,sizes?:number[],alpha?:string,viewBox?:string,manifest?:string,use:string}>} */
export const TARGETS = [
  // --- Mobile: Quellen für flutter_launcher_icons und In-App-Logo -------------------------------
  { out: 'mobile/assets/icon/adaptive_background.png', kind: 'png', src: 'logo-background.svg', width: 1024, height: 1024, alpha: 'rgb', use: 'Adaptives Icon, Hintergrund (flutter_launcher_icons)' },
  { out: 'mobile/assets/icon/adaptive_foreground.png', kind: 'png', src: 'logo-foreground.svg', width: 1024, height: 1024, alpha: 'rgba', use: 'Adaptives Icon, Vordergrund in der Safe Zone' },
  { out: 'mobile/assets/icon/adaptive_monochrome.png', kind: 'png', src: 'logo-monochrome.svg', width: 1024, height: 1024, alpha: 'rgba', use: 'Themed Icon (Android 13+), Silhouette' },
  { out: 'mobile/assets/icon/launcher_legacy.png', kind: 'png', src: 'logo.svg', width: 1024, height: 1024, alpha: 'rgba', use: 'Launcher-Icon vor Android 8 (flutter_launcher_icons image_path)' },
  { out: 'mobile/assets/icon/app_logo_256.png', kind: 'png', src: 'logo.svg', width: 256, height: 256, alpha: 'rgba', use: 'In-App-Logo (Login, Info-Seite)' },

  // --- Mobile: Statusleisten-Icon (weiß auf transparent, 24 dp) ----------------------------------
  { out: `${ANDROID_RES}/drawable-mdpi/ic_notification.png`, kind: 'png', src: 'logo-notification.svg', width: 24, height: 24, alpha: 'white', use: 'Benachrichtigungs-Icon mdpi' },
  { out: `${ANDROID_RES}/drawable-hdpi/ic_notification.png`, kind: 'png', src: 'logo-notification.svg', width: 36, height: 36, alpha: 'white', use: 'Benachrichtigungs-Icon hdpi' },
  { out: `${ANDROID_RES}/drawable-xhdpi/ic_notification.png`, kind: 'png', src: 'logo-notification.svg', width: 48, height: 48, alpha: 'white', use: 'Benachrichtigungs-Icon xhdpi' },
  { out: `${ANDROID_RES}/drawable-xxhdpi/ic_notification.png`, kind: 'png', src: 'logo-notification.svg', width: 72, height: 72, alpha: 'white', use: 'Benachrichtigungs-Icon xxhdpi' },
  { out: `${ANDROID_RES}/drawable-xxxhdpi/ic_notification.png`, kind: 'png', src: 'logo-notification.svg', width: 96, height: 96, alpha: 'white', use: 'Benachrichtigungs-Icon xxxhdpi' },

  // --- Web: Favicons ---------------------------------------------------------------------------
  { out: 'web/public/favicon.svg', kind: 'svg', src: 'favicon.svg', use: 'Favicon (SVG, zuerst verlinkt)' },
  { out: 'web/public/favicon.ico', kind: 'ico', src: 'favicon.svg', sizes: [16, 32, 48], use: 'Favicon (ICO, Fallback)' },
  { out: 'web/public/favicon-16x16.png', kind: 'png', src: 'favicon.svg', width: 16, height: 16, alpha: 'rgba', use: 'Favicon PNG' },
  { out: 'web/public/favicon-32x32.png', kind: 'png', src: 'favicon.svg', width: 32, height: 32, alpha: 'rgba', use: 'Favicon PNG' },
  { out: 'web/public/favicon-48x48.png', kind: 'png', src: 'favicon.svg', width: 48, height: 48, alpha: 'rgba', use: 'Favicon PNG' },
  { out: 'web/public/favicon-96x96.png', kind: 'png', src: 'favicon.svg', width: 96, height: 96, alpha: 'rgba', use: 'Favicon PNG (Manifest)' },

  // --- Web: PWA, Apple, Logo, OG -------------------------------------------------------------
  { out: 'web/public/apple-touch-icon.png', kind: 'png', src: 'icon-store.svg', width: 180, height: 180, alpha: 'rgb', use: 'iOS-Home-Bildschirm (deckend, iOS rundet selbst)' },
  { out: 'web/public/icon-192x192.png', kind: 'png', src: 'logo.svg', width: 192, height: 192, alpha: 'rgba', manifest: 'any', use: 'PWA-Icon (purpose any)' },
  { out: 'web/public/icon-512x512.png', kind: 'png', src: 'logo.svg', width: 512, height: 512, alpha: 'rgba', manifest: 'any', use: 'PWA-Icon (purpose any)' },
  { out: 'web/public/icon-maskable-192x192.png', kind: 'png', src: ['logo-background.svg', 'logo-foreground.svg'], viewBox: MASKABLE_VIEWBOX, width: 192, height: 192, alpha: 'rgb', manifest: 'maskable', use: 'PWA-Icon (purpose maskable, Safe Zone 80 %)' },
  { out: 'web/public/icon-maskable-512x512.png', kind: 'png', src: ['logo-background.svg', 'logo-foreground.svg'], viewBox: MASKABLE_VIEWBOX, width: 512, height: 512, alpha: 'rgb', manifest: 'maskable', use: 'PWA-Icon (purpose maskable, Safe Zone 80 %)' },
  { out: 'web/public/logo.svg', kind: 'svg', src: 'logo.svg', use: 'Logo in Sidenav und Login (Web)' },
  { out: 'web/public/og-image.png', kind: 'png', src: 'og-image.svg', width: 1200, height: 630, alpha: 'rgb', use: 'Open-Graph-/Twitter-Vorschaubild' },

  // --- Play Store -------------------------------------------------------------------------------
  { out: 'store/icon-512.png', kind: 'png', src: 'icon-store.svg', width: 512, height: 512, alpha: 'opaque', use: 'Play-Store-Icon (32 Bit, quadratisch, Play maskiert selbst)' },
  { out: 'store/feature-graphic.png', kind: 'png', src: 'feature-graphic.svg', width: 1024, height: 500, alpha: 'rgb', use: 'Play-Store-Feature-Graphic (ohne Alpha)' },
];
