# UI-Report #279 — Feiertage pro Bundesland (Web)

Design: **manuell** nach Flutter-Vorlage (Stitch-API HTTP 405, nicht genutzt). `npm run build -- --configuration production` und `tsc` (app + spec) laufen grün. Tests nicht ausgeführt/geschrieben (Plan-Phase).

## Umgesetzt (UI)
| Datei | Inhalt |
|---|---|
| `shared/components/holiday-banner/holiday-banner.{ts,html,scss}` | `app-holiday-banner`, `input.required<GermanHoliday>()`, rein darstellend |
| `features/dashboard/dashboard.html/.ts/.scss` | Banner im `dashboard-wrapper` über `.dashboard-content` (`@if (svc.holidayToday(); as holiday)`); Wrapper jetzt `flex-direction: column; align-items: center` |
| `features/settings/settings.html/.ts/.scss` | Sektion „Bundesland" zwischen Urlaub und Gleitzeit, `openEditBundeslandDialog()` |
| `features/settings/components/edit-bundesland-dialog/edit-bundesland-dialog.ts` | Inline-Template, `mat-radio-group` (17 Optionen), kein eigener Fehlerzustand |
| `public/i18n/de.json`, `en.json` | nur neue Keys (Diff: 2 Zeilen je Datei nur wegen angehängtem Komma am Vorgänger-Key, sonst reine Additionen, JSON valide) |

## Stubs, damit der Build grün bleibt (Logik fehlt bewusst)
- `shared/models/index.ts`: `BUNDESLAND_VALUES`, `type Bundesland`, `UserSettings.bundesland: Bundesland | null`, `DEFAULT_SETTINGS.bundesland = null` (Typen/Default, kein `mergeSettings`).
- `shared/utils/german-holidays.util.ts`: nur `GERMAN_HOLIDAY_IDS` + `type GermanHoliday` (17). Berechnung fehlt.
- `DashboardService.holidayToday`: Platzhalter `signal<GermanHoliday | null>(null).asReadonly()` -> **in der Implementierung durch `computed` ersetzen**.
- `SettingsPageService.setBundesland(b)`: Platzhalter `saveSettings({...current, bundesland: b})`; sendet bei `null` **kein** `""` (Abwahl funktioniert backendseitig erst mit `clearBundesland`).

## UI-Vertrag für die Planung
- `DashboardService.holidayToday: Signal<GermanHoliday | null>` (null = kein Banner, kein Platzhalter). Nur Lesen, keine Soll-/Overtime-Auswirkung.
- `SettingsPageService.settings()` liefert `bundesland` (via `mergeSettings` normalisiert, Rohwert ungültig/`""` -> `null`); Template liest `svc.settings().bundesland`.
- `SettingsPageService.setBundesland(value: Bundesland | null): Promise<void>` — wirft bei Fehler (Komponente fängt, zeigt Snackbar `settings.bundesland.saveError`); `null` -> explizit `""` (`clearBundesland`).
- `SettingsComponent.openEditBundeslandDialog(): Promise<void>`: Dialog-Data `{ current: Bundesland | null }`, Result `{ bundesland: Bundesland | null } | undefined` (undefined = Abbrechen, nichts speichern). Erfolg-Snackbar `settings.bundesland.saved`.
- `EditBundeslandDialogComponent`: `control: FormControl<Bundesland | null>`, `submit()` schließt mit Result; Option „Nicht ausgewählt" hat Wert `null`.
- `HolidayBannerComponent`: Input `holiday: GermanHoliday`; Text `dashboard.holidayToday` mit `name = 'holidays.<id>'`.
- i18n-Keys: `holidays.<id>` (17), `dashboard.holidayToday`, `settings.bundesland.{sectionTitle, sectionAria, label, notSelected, hint, notSelectedHint, editAria, dialogTitle, groupAria, saved, saveError, state.<16 Werte>}`. Ländernamen in de/en identisch. `holidays.*` ist ein Top-Level-Block direkt nach `dashboard`.
- Mobile-Texte „Kalender" bewusst weggelassen (Entscheidung Hauptsession).

## Design-Abgleich (Flutter `holiday_banner.dart`)
- Padding 16/12, Radius 12, Icon 12px Abstand zum Text, `tertiaryContainer`/`onTertiaryContainer` -> `--mat-sys-tertiary-container`/`--mat-sys-on-tertiary-container` (Dark Mode automatisch über `.dark-theme`).
- Icon `celebration` (Mobile `celebration_outlined`; Material-Icons-Font hat nur `celebration`, Abweichung minimal).
- Text `titleSmall` (14px/500), `overflow-wrap: anywhere`, kein nowrap. Abstand unten 16px im Banner gekapselt (kein Layoutsprung ohne Feiertag).
- Banner begrenzt auf `max-width: 1200px` (wie Grid), volle Breite; Mobile 12px Wrapper-Padding bleibt.
- Settings-Zeile wie die übrigen: `mat-list-item`, Icon `location_on`, Titel „Bundesland", Zeile = Landesname oder „Nicht ausgewählt", Chevron. Hinweistext als `<p class="bundesland-hint">` unter der Liste (umbrechend, bündig mit Zeilentext), wechselt zwischen `hint` und `notSelectedHint`.

## States
Kein Bundesland / kein Feiertag: nichts gerendert. Feiertag: Banner. Laden: bestehender Spinner (Banner im `@else`). Anonym: identisch (Settings lokal). Lange Namen: Umbruch. Speicherfehler: Snackbar durch SettingsComponent. Premium: n/a.

## Accessibility
`role="status"` (implizit polite live region) am Banner, Icon `aria-hidden`; Zeilen-Button mit `aria-label`; Radiogruppe mit `aria-label`, native Tastatur (Pfeiltasten, Tab, Enter/Dialog-Buttons); Material-Dialog mit Titel/Fokus-Trap; Farben aus M3-Container-Token-Paaren (WCAG-AA-Kontrast vorgesehen, visuell in hell/dunkel und 360px/Desktop noch zu prüfen).

## Offene Punkte
- `cdkFocusInitial` liegt auf „Nicht ausgewählt"; bei gesetztem Bundesland wäre Fokus auf der aktuellen Auswahl besser — mat-radio-group fokussiert ohnehin die gewählte Option per Tab, bei Bedarf in der Implementierung prüfen.
- Sichtprüfung im Browser (hell/dunkel, DE/EN, 360px/768px/Desktop) steht aus.
- Spec-Dateien (Dialog, Banner, Settings-Component) für die TDD-Phase.
